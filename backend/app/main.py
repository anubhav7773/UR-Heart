from fastapi import FastAPI, WebSocket, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from typing import Optional

from app.core.config import settings
from app.core.rate_limiter import limiter, custom_rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.api.v1.router import api_router
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

# Mount API v1 router
app.include_router(api_router, prefix="/api/v1")

@app.websocket("/ws/chat")
async def root_websocket_chat(websocket: WebSocket, token: Optional[str] = Query(None)):
    await handle_chat_websocket(websocket, token)

@app.get("/", tags=["Root"])
async def root():
    return {
        "app": "UR-Heart",
        "entity": "ASI Verticals",
        "version": "1.0.0-PROD",
        "status": "online"
    }
