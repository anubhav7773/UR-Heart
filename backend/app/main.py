from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api.v1.api_router import api_router as api_v1_router
from app.core.config import get_settings
from app.core.exceptions import SanctuaryException

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: Shared HTTP client allocated for external services
    app.state.http_client = httpx.AsyncClient(timeout=15.0)
    yield
    # SHUTDOWN: Gracefully close HTTP client
    await app.state.http_client.aclose()


app = FastAPI(
    title=settings.APP_NAME,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json" if settings.DEBUG else None,
    docs_url=f"{settings.API_V1_PREFIX}/docs" if settings.DEBUG else None,
    redoc_url=None,
    lifespan=lifespan
)

# Cross-Origin Isolation for Mobile App
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"],
    allow_headers=["*"],
)


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


# Register Main API v1 Router
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
