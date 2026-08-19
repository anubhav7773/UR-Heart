import time
from collections import defaultdict
from fastapi import HTTPException, Request, status
from typing import Dict, List, Optional
from app.core.security import decode_access_token


class InMemoryRateLimiter:
    def __init__(self):
        # Maps key -> list of timestamps
        self._records: Dict[str, List[float]] = defaultdict(list)

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> bool:
        now = time.time()
        window_start = now - window_seconds

        # Prune older entries
        self._records[key] = [t for t in self._records[key] if t > window_start]

        if len(self._records[key]) >= max_requests:
            return False

        self._records[key].append(now)
        return True

    def reset(self):
        self._records.clear()


limiter = InMemoryRateLimiter()


def rate_limit(max_requests: int, window_seconds: int, by_user: bool = True):
    """
    FastAPI Dependency for Endpoint Rate Limiting.
    - by_user=True: tracks per authenticated user_id (extracts from Bearer token or request state)
    - by_user=False: tracks per client IP
    """
    async def dependency(request: Request):
        key = None
        if by_user:
            user = getattr(request.state, "user", None)
            if user:
                key = f"user:{getattr(user, 'id', user)}"
            else:
                auth_header = request.headers.get("Authorization", "")
                if auth_header.startswith("Bearer "):
                    token = auth_header.split(" ", 1)[1].strip()
                    uid = decode_access_token(token)
                    if uid:
                        key = f"user:{uid}"

        if not key:
            client_host = request.client.host if request.client else "127.0.0.1"
            key = f"ip:{client_host}"

        endpoint_key = f"{key}:{request.url.path}"

        if not limiter.is_allowed(endpoint_key, max_requests, window_seconds):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded: Max {max_requests} requests per {window_seconds}s.",
                headers={"Retry-After": str(window_seconds)}
            )
    return dependency
