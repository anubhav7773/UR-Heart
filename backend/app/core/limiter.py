from fastapi import Request
from slowapi import Limiter


def get_real_client_ip(request: Request) -> str:
    """Extracts genuine client IP from proxy headers (Cloudflare, Render, AWS)."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    return request.client.host if request.client else "127.0.0.1"


limiter = Limiter(key_func=get_real_client_ip, default_limits=["120/minute"])
