import time
import logging
from typing import Optional, Dict, List
from collections import defaultdict
from fastapi import Request, HTTPException, status
from app.core.config import settings
from app.core.security import decode_access_token

logger = logging.getLogger(__name__)


class UnifiedRateLimiter:
    """
    Production-ready Rate Limiter with Redis distributed sliding-window support
    and zero-downtime thread-safe in-memory fallback for container resilience.
    """

    def __init__(self):
        self.redis_client = None
        self._memory_store: Dict[str, List[float]] = defaultdict(list)
        self._last_gc_time = time.time()

        # Attempt optional Redis connection if configured
        redis_url = getattr(settings, "REDIS_URL", None)
        if redis_url:
            try:
                import redis
                self.redis_client = redis.from_url(redis_url, decode_responses=True)
                self.redis_client.ping()
                logger.info("[RateLimiter] Connected to Redis backend successfully.")
            except Exception as e:
                logger.warning(f"[RateLimiter] Redis not available ({e}). Using in-memory fallback store.")
                self.redis_client = None

    def _clean_memory_key(self, key: str, window_seconds: int, current_time: float):
        cutoff = current_time - window_seconds
        self._memory_store[key] = [t for t in self._memory_store[key] if t > cutoff]
        if not self._memory_store[key]:
            self._memory_store.pop(key, None)

    def _periodic_gc(self, current_time: float):
        """Clean empty and stale keys periodically to prevent memory leaks during long-running containers."""
        if current_time - self._last_gc_time > 300:
            self._last_gc_time = current_time
            keys_to_remove = [k for k, v in self._memory_store.items() if not v]
            for k in keys_to_remove:
                self._memory_store.pop(k, None)

    async def check_rate_limit(
        self,
        identifier: str,
        max_requests: int,
        window_seconds: int
    ) -> bool:
        now = time.time()
        key = f"rate_limit:{identifier}"

        # 1. Redis Pathway (if available)
        if self.redis_client:
            try:
                pipe = self.redis_client.pipeline()
                cutoff = now - window_seconds
                pipe.zremrangebyscore(key, 0, cutoff)
                pipe.zadd(key, {str(now): now})
                pipe.zcard(key)
                pipe.expire(key, window_seconds)
                results = pipe.execute()
                current_count = results[2]
                return current_count <= max_requests
            except Exception as e:
                logger.warning(f"[RateLimiter] Redis error: {e}. Falling back to in-memory store.")
                pass  # Fall back to in-memory on connection drop

        # 2. In-Memory Fallback Pathway
        self._clean_memory_key(key, window_seconds, now)
        self._periodic_gc(now)

        if len(self._memory_store[key]) >= max_requests:
            return False

        self._memory_store[key].append(now)
        return True

    def reset(self):
        """Reset memory store for unit testing."""
        self._memory_store.clear()


limiter = UnifiedRateLimiter()


def rate_limit(max_requests: int, window_seconds: int, by_user: bool = True):
    """
    FastAPI Dependency for Endpoint Rate Limiting.
    - Tracks per authenticated user_id if by_user=True and token/user present
    - Otherwise falls back to client IP
    - Normalizes URL paths across /api/v1 prefixes
    """
    async def dependency(request: Request):
        # Extract Real Client IP from reverse-proxy headers (Render/Cloudflare/Nginx)
        client_ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        if not client_ip:
            client_ip = request.headers.get("x-real-ip", "").strip()
        if not client_ip:
            client_ip = request.client.host if request.client else "127.0.0.1"

        user_id = getattr(request.state, "user_id", None)
        if not user_id and by_user:
            user = getattr(request.state, "user", None)
            if user:
                user_id = str(getattr(user, "id", user))
            else:
                auth_header = request.headers.get("Authorization", "")
                if auth_header.startswith("Bearer "):
                    token = auth_header.split(" ", 1)[1].strip()
                    user_id = decode_access_token(token)

        # Fall back to device-id header if available for unauthenticated clients
        device_id = request.headers.get("x-device-id")
        client_identifier = user_id or device_id or client_ip

        # Normalize path so /api/v1/feed and /feed share same bucket
        path = request.url.path
        if path.startswith(settings.API_V1_STR):
            path = path[len(settings.API_V1_STR):]
        normalized_path = path or "/"

        identifier = f"{client_identifier}:{normalized_path}"

        is_allowed = await limiter.check_rate_limit(
            identifier=identifier,
            max_requests=max_requests,
            window_seconds=window_seconds
        )

        if not is_allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please slow down and try again later.",
                headers={"Retry-After": str(window_seconds)}
            )

    return dependency
