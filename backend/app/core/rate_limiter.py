import logging
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request, Response
from starlette.responses import JSONResponse

logger = logging.getLogger("urheart.rate_limiter")

# Initialize SlowAPI rate limiter with remote address keying and default 120/min limit
limiter = Limiter(key_func=get_remote_address, default_limits=["120/minute"])

async def custom_rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> Response:
    """
    Custom handler for RateLimitExceeded exceptions:
    - Logs statutory rate limit violation to legal audit logs without storing plain-text PII.
    - Emits HTTP 429 Too Many Requests response with standard retry headers.
    """
    client_ip = request.client.host if request.client else "unknown"
    logger.warning(
        f"Rate limit exceeded on endpoint={request.url.path} from client_ip={client_ip}: {exc.detail}"
    )

    try:
        from app.core.database import async_session_factory
        from app.core.legal_audit import record_legal_audit_event
        async with async_session_factory() as db:
            await record_legal_audit_event(
                request=request,
                action_type="RATE_LIMIT_EXCEEDED",
                user_id=None,
                db=db
            )
    except Exception as e:
        # Non-blocking fallback if db session cannot be created
        logger.error(f"Failed to record rate limit audit event: {e}")

    return JSONResponse(
        status_code=429,
        content={
            "detail": f"Rate limit exceeded: {exc.detail}",
            "error": "rate_limit_exceeded"
        },
        headers={"Retry-After": "60"}
    )
