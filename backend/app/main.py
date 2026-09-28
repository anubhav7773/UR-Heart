import os
import time
from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.v1.api_router import api_router as api_v1_router
from app.api.v1.endpoints.chat_websocket import ws_router
from app.core.config import get_settings
from app.core.exceptions import SanctuaryException

settings = get_settings()

# 1. SlowAPI Gateway Rate Limiter (Default 120 req/min per IP)
limiter = Limiter(key_func=get_remote_address, default_limits=["120/minute"])


# 2. Strict Security Headers Middleware (Checklist Points 18 & 19)
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response: Response = await call_next(request)

        # Force HTTPS / HSTS (Checklist Point 19)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
        # Prevent MIME type sniffing (Checklist Point 18)
        response.headers["X-Content-Type-Options"] = "nosniff"
        # Prevent Clickjacking (Checklist Point 18)
        response.headers["X-Frame-Options"] = "DENY"
        # XSS Protection
        response.headers["X-XSS-Protection"] = "1; mode=block"
        # Restrict Referrer information
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        # Content Security Policy (Zero external eval)
        response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none';"

        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: Shared HTTP client allocated for external services
    app.state.http_client = httpx.AsyncClient(timeout=15.0)
    yield
    # SHUTDOWN: Gracefully close HTTP client
    await app.state.http_client.aclose()


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json" if settings.DEBUG else None,
    docs_url=f"{settings.API_V1_PREFIX}/docs" if settings.DEBUG else None,
    redoc_url=None,
    lifespan=lifespan
)

# Register SlowAPI Rate Limiting State & Error Handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Register Middlewares (Executed in reverse order of registration)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(SlowAPIMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def live_render_request_logger(request: Request, call_next):
    """
    Guarantees every single request, path, method, and client IP is immediately
    logged to Render's live stdout log console with flush=True.
    """
    start = time.time()
    client_ip = request.client.host if request.client else "unknown"
    try:
        response = await call_next(request)
        elapsed_ms = (time.time() - start) * 1000
        print(
            f"[RENDER HTTP] {request.method} {request.url.path} -> "
            f"Status: {response.status_code} | IP: {client_ip} | Took: {elapsed_ms:.1f}ms",
            flush=True
        )
        return response
    except Exception as exc:
        elapsed_ms = (time.time() - start) * 1000
        print(
            f"[RENDER HTTP ERROR] {request.method} {request.url.path} -> "
            f"Exception: {str(exc)} | IP: {client_ip} | Took: {elapsed_ms:.1f}ms",
            flush=True
        )
        raise exc


@app.exception_handler(SanctuaryException)
async def sanctuary_exception_handler(request: Request, exc: SanctuaryException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error_code": exc.error_code,
            "message": exc.detail
        }
    )


# Mount WebSockets router at root
app.include_router(ws_router)

# Mount Main API v1 Router
app.include_router(api_v1_router, prefix=settings.API_V1_PREFIX)


@app.api_route("/", methods=["GET", "HEAD"], tags=["Render Health"])
@app.api_route("/health", methods=["GET", "HEAD"], tags=["Render Health"])
async def root_health_probe(request: Request):
    """Zero-overhead root health probe for Render / UptimeRobot."""
    return JSONResponse(
        content={
            "status": "healthy",
            "service": settings.APP_NAME,
            "version": "1.0.0",
        },
        headers={"X-Sanctuary-Alive": "true", "Cache-Control": "no-cache"}
    )
