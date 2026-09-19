from fastapi import FastAPI, WebSocket, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from typing import Optional

from app.core.config import settings
from app.core.rate_limiter import limiter, custom_rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.api.v1.router import api_router
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.chat import handle_chat_websocket

app = FastAPI(
    title="UR-Heart API",
    description="Backend services for UR-Heart (Urban and Rural Heart) by ASI Verticals",
    version="1.0.0-PROD",
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
)

# Register SlowAPI Rate Limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, custom_rate_limit_exceeded_handler)

# Security Check 18: OWASP Security Headers Middleware
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none';"
    response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    return response

# Transport Security & HTTPS Enforcement in Production
if settings.ENVIRONMENT == "production":
    app.add_middleware(HTTPSRedirectMiddleware)
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["api.asiverticals.com", "*.onrender.com", "localhost"]
    )

# Configure CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins if settings.cors_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi.responses import JSONResponse

@app.api_route("/health", methods=["GET", "HEAD"], tags=["Monitoring"])
async def health_check():
    """
    Zero-database keep-alive endpoint for UptimeRobot pings.
    Returns instantly from memory without allocating database sessions or leaking RAM.
    """
    return JSONResponse(
        content={
            "status": "healthy",
            "service": "ur-heart-api",
            "memory_guard": "512MB_optimized"
        },
        status_code=200
    )

# Mount Health and Keep-Alive router directly at root level for UptimeRobot / Ping monitors
app.include_router(health_router, tags=["Health & Keep-Alive"])

# Mount API v1 router
app.include_router(api_router, prefix="/api/v1")

from app.api.v1.endpoints.location import router as location_router
app.include_router(location_router, prefix="/api/v1/location", tags=["Location"])

from app.api.v1.endpoints.referral import router as referral_router
app.include_router(referral_router, prefix="/api/v1/referral", tags=["Referral"])

from app.api.v1.endpoints.admin_legal import router as admin_legal_router
app.include_router(admin_legal_router, prefix="/api/v1/admin/legal", tags=["Legal Admin"])


from fastapi.responses import PlainTextResponse

APP_ADS_TXT_CONTENT = """# UR-Heart / ASI Verticals Authorized Digital Sellers
google.com, pub-3940256099942544, DIRECT, f08c47fec0942fa0
applovin.com, 0123456789abcdef, DIRECT
"""

@app.get("/app-ads.txt", response_class=PlainTextResponse, tags=["Monetization"])
async def get_app_ads_txt():
    """
    Serves statutory app-ads.txt to prevent ad fraud and preserve 100% fill rates.
    """
    return PlainTextResponse(content=APP_ADS_TXT_CONTENT.strip(), media_type="text/plain")

@app.websocket("/ws/chat")
async def root_websocket_chat(websocket: WebSocket, token: Optional[str] = Query(None)):
    await handle_chat_websocket(websocket, token)

@app.get("/", tags=["Root"])
@app.head("/", tags=["Root"])
@limiter.exempt
async def root(request: Request):
    return {
        "app": "UR-Heart",
        "entity": "ASI Verticals",
        "version": "1.0.0-PROD",
        "status": "online"
    }

