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

api_v1_prefix = settings.API_V1_STR
app.include_router(auth_router, prefix=api_v1_prefix)
app.include_router(profile_router, prefix=api_v1_prefix)
app.include_router(users_router, prefix=api_v1_prefix)
app.include_router(feed_router, prefix=api_v1_prefix)
app.include_router(matches_router, prefix=api_v1_prefix)
app.include_router(chat_router, prefix=api_v1_prefix)
app.include_router(intent_router, prefix=api_v1_prefix)
app.include_router(ads_router, prefix=api_v1_prefix)
app.include_router(payments_router, prefix=api_v1_prefix)
app.include_router(safety_router, prefix=api_v1_prefix)


@app.get("/", status_code=200, tags=["Root"])
@app.head("/", status_code=200, tags=["Root"])
@app.get("/health", status_code=200, tags=["Health Check"])
@app.head("/health", status_code=200, tags=["Health Check"])
@app.get(f"{settings.API_V1_STR}/health", status_code=200, tags=["Health Check"])
@app.head(f"{settings.API_V1_STR}/health", status_code=200, tags=["Health Check"])
async def health_check():
    """Fast, lightweight health check endpoint supporting both GET and HEAD for UptimeRobot monitoring."""
    return {
        "status": "online",
        "message": "UR-Heart Backend Active",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
