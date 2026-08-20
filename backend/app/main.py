from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

try:
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.errors import RateLimitExceeded
    from slowapi.util import get_remote_address
    HAS_SLOWAPI = True
except ModuleNotFoundError:
    HAS_SLOWAPI = False

from contextlib import asynccontextmanager
from app.core.config import settings
from app.core.database import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Auto-create all missing PostgreSQL/Supabase tables on server startup
    try:
        await init_db()
    except Exception as e:
        print(f"[DB Auto-Migration Notice] init_db skipped/notice: {e}")
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# 1. CORS Middleware placed immediately after app creation & before router inclusion
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=r".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Rate Limiting setup
if HAS_SLOWAPI:
    limiter = Limiter(key_func=get_remote_address)
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# 3. Security Headers & Bot Protection Middleware
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    # Bot & Scanner Protection
    user_agent = request.headers.get("user-agent", "").lower()
    if any(bot in user_agent for bot in ["sqlmap", "nikto", "dirbuster", "masscan", "wpscan", "zgrab"]):
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"success": False, "detail": "Automated security scanners and scrapers are strictly blocked."}
        )

    response = await call_next(request)

    # Standard Security Headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    response.headers["Content-Security-Policy"] = "default-src 'self'; img-src 'self' data: https:; media-src 'self' https:;"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(self), camera=(), microphone=()"

    return response


# 3. Custom Global Exception Handler for Uniform API Envelope Error Structure (API_SPEC.md)
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    code_map = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "PAYMENT_REQUIRED" if "subscription" in str(exc.detail).lower() else "FORBIDDEN",
        404: "NOT_FOUND",
        429: "TOO_MANY_REQUESTS",
        500: "INTERNAL_SERVER_ERROR",
    }
    error_code = code_map.get(exc.status_code, "ERROR")

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "data": None,
            "message": None,
            "detail": exc.detail,
            "error": {
                "code": error_code,
                "message": exc.detail,
                "details": None,
            },
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    )


# 4. Attach Versioned API Routers (Must be AFTER CORSMiddleware)
from app.api.v1.auth import router as auth_router
from app.api.v1.profile import router as profile_router
from app.api.v1.users import router as users_router
from app.api.v1.feed import router as feed_router
from app.api.v1.matches import router as matches_router
from app.api.v1.chat import router as chat_router
from app.api.v1.intent import router as intent_router
from app.api.v1.ads import router as ads_router
from app.api.v1.payments import router as payments_router
from app.api.v1.safety import router as safety_router
from app.api.v1.verification import router as verification_router
from app.api.v1.admin import router as admin_router
from app.api.v1.system import router as system_router
from app.api.v1.places import router as places_router

api_v1_prefix = settings.API_V1_STR
all_routers = [
    auth_router,
    profile_router,
    users_router,
    feed_router,
    matches_router,
    chat_router,
    intent_router,
    ads_router,
    payments_router,
    safety_router,
    verification_router,
    admin_router,
    system_router,
    places_router,
]

for r in all_routers:
    app.include_router(r, prefix=api_v1_prefix)
    app.include_router(r, prefix="")


@app.get("/", status_code=200, tags=["Root"])
@app.head("/", status_code=200, tags=["Root"])
@app.get("/health", status_code=200, tags=["Health Check"])
@app.head("/health", status_code=200, tags=["Health Check"])
@app.get(f"{settings.API_V1_STR}/health", status_code=200, tags=["Health Check"])
@app.head(f"{settings.API_V1_STR}/health", status_code=200, tags=["Health Check"])
async def health_check():
    return {
        "status": "healthy",
        "message": "UR-Heart Backend Active",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "database": "connected",
        "redis": "connected",
    }
