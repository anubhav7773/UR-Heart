import os
import time
from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.v1.api_router import api_router as api_v1_router
from app.api.v1.endpoints.chat_websocket import ws_router
from typing import List
from app.core.config import get_settings, validate_production_env
from app.core.exceptions import SanctuaryException
from app.core.limiter import limiter

settings = get_settings()


def get_allowed_cors_origins() -> List[str]:
    canonical_origins = [
        "https://urheart.app",
        "https://vault.urheart.app",
        "https://urheart.asiverticals.me",
        "https://urheart.in",
        "https://www.urheart.in",
    ]
    env = (getattr(settings, "ENVIRONMENT", "") or os.getenv("ENVIRONMENT", "production")).lower()
    if env != "production":
        canonical_origins.extend([
            "http://localhost:3000",
            "http://localhost:8000",
            "http://127.0.0.1:3000",
            "http://127.0.0.1:8000",
        ])
    return canonical_origins


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
        # Content Security Policy (Zero external eval, allows safe sanctuary fonts and styles)
        response.headers["Content-Security-Policy"] = (
            "default-src 'self' 'unsafe-inline' https:; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "font-src 'self' https://fonts.gstatic.com data:; "
            "img-src 'self' data: https:; "
            "frame-ancestors 'none';"
        )

        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: Fail-fast secret validation in production
    validate_production_env(settings)
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
    allow_origins=get_allowed_cors_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "X-Installation-UUID",
        "Accept",
        "Origin",
        "X-Requested-With",
    ],
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

# Mount Notifications router directly at root to guarantee 100% immunity against 404
from app.api.v1.endpoints.notifications import router as notifications_direct_router
app.include_router(notifications_direct_router)

# Mount direct magic link verification routes at root for 100% tap compatibility
from app.api.v1.endpoints.auth import handle_browser_magic_link_tap
from fastapi.responses import HTMLResponse
app.add_api_route("/verify", handle_browser_magic_link_tap, methods=["GET"], response_class=HTMLResponse, tags=["Magic Link Direct"])
app.add_api_route("/auth/callback", handle_browser_magic_link_tap, methods=["GET"], response_class=HTMLResponse, tags=["Magic Link Direct"])

# Mount Web Sanctuary Store router directly at root for https://urheart.asiverticals.me/store
from app.api.v1.endpoints.web_store import router as web_store_direct_router
app.include_router(web_store_direct_router)

# Mount Statutory Legal & Google Play Compliance Portals (/privacy, /terms, /delete-account)
from app.api.v1.endpoints.statutory_pages import router as statutory_direct_router
app.include_router(statutory_direct_router)
app.include_router(statutory_direct_router, prefix="/statutory")
app.include_router(statutory_direct_router, prefix=f"{settings.API_V1_PREFIX}/statutory")



# Mount Main API v1 Router
app.include_router(api_v1_router, prefix=settings.API_V1_PREFIX)


@app.api_route("/", methods=["GET", "HEAD"], tags=["Render Health"])
@app.api_route("/health", methods=["GET", "HEAD"], tags=["Render Health"])
@limiter.limit("120/minute")
async def root_health_probe(request: Request):
    """
    Root endpoint:
    - If accessed by a web browser (accept: text/html) on '/', renders the responsive dark-sanctuary web landing page.
    - If accessed via API / probe / HEAD / '/health', returns high-speed JSON health status.
    """
    accept_header = request.headers.get("accept", "")
    if request.method == "GET" and request.url.path == "/" and "text/html" in accept_header:
        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UR-Heart Sanctuary | An Asiverticals Platform</title>
  <meta name="description" content="UR-Heart: A Soul-Aligned, Sovereign Social Sanctuary. Zero-surveillance social kinship by Asiverticals.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@500;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {{
      --bg: #0A0F0D;
      --card-bg: rgba(22, 33, 29, 0.75);
      --card-border: rgba(43, 61, 53, 0.8);
      --pine: #2E6F5E;
      --pine-glow: #3E8E79;
      --coral: #E06D53;
      --gold: #D4AF37;
      --text-head: #FFFFFF;
      --text-body: #C5D6CE;
      --text-muted: #829A90;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: radial-gradient(circle at 50% 10%, #162420 0%, #0A0F0D 65%, #050807 100%);
      color: var(--text-body);
      font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      overflow-x: hidden;
      padding: 32px 20px;
    }}
    .glow-sphere {{
      position: fixed;
      top: -120px;
      left: 50%;
      transform: translateX(-50%);
      width: 500px;
      height: 350px;
      background: radial-gradient(ellipse, rgba(46, 111, 94, 0.28), transparent 70%);
      pointer-events: none;
      z-index: 0;
    }}
    .container {{
      max-width: 720px;
      width: 100%;
      position: relative;
      z-index: 1;
      text-align: center;
      margin: auto;
    }}
    .badge {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 16px;
      background: rgba(46, 111, 94, 0.2);
      border: 1px solid rgba(62, 142, 121, 0.4);
      border-radius: 999px;
      font-size: 12px;
      font-weight: 600;
      color: #A3E4D1;
      margin-bottom: 24px;
      backdrop-filter: blur(8px);
    }}
    .badge .dot {{
      width: 8px;
      height: 8px;
      background: #4E9F76;
      border-radius: 50%;
      box-shadow: 0 0 10px #4E9F76;
      animation: pulse 2s infinite;
    }}
    @keyframes pulse {{
      0%, 100% {{ transform: scale(1); opacity: 1; }}
      50% {{ transform: scale(1.3); opacity: 0.6; }}
    }}
    h1 {{
      font-family: 'Cinzel', serif;
      font-size: clamp(34px, 6vw, 54px);
      font-weight: 700;
      color: var(--text-head);
      letter-spacing: -0.5px;
      line-height: 1.15;
      margin-bottom: 16px;
    }}
    .tagline {{
      font-size: clamp(15px, 2.5vw, 18px);
      line-height: 1.6;
      color: var(--text-muted);
      max-width: 580px;
      margin: 0 auto 36px;
    }}
    .card {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 24px;
      padding: 32px 28px;
      backdrop-filter: blur(16px);
      box-shadow: 0 20px 50px rgba(0,0,0,0.5);
      margin-bottom: 32px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin: 28px 0;
      text-align: left;
    }}
    .pillar {{
      background: rgba(10, 15, 13, 0.5);
      border: 1px solid rgba(43, 61, 53, 0.6);
      border-radius: 14px;
      padding: 16px;
    }}
    .pillar h3 {{
      font-size: 13px;
      font-weight: 700;
      color: var(--gold);
      margin-bottom: 4px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }}
    .pillar p {{
      font-size: 12px;
      color: var(--text-muted);
      line-height: 1.4;
    }}
    .actions {{
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      justify-content: center;
    }}
    .btn {{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 14px 28px;
      border-radius: 14px;
      font-size: 14px;
      font-weight: 600;
      text-decoration: none;
      transition: all 0.25s ease;
      cursor: pointer;
    }}
    .btn-primary {{
      background: linear-gradient(135deg, #E06D53 0%, #C94A29 100%);
      color: #FFFFFF;
      box-shadow: 0 8px 24px rgba(201, 74, 41, 0.35);
      border: 1px solid rgba(255,255,255,0.15);
    }}
    .btn-primary:hover {{
      transform: translateY(-2px);
      box-shadow: 0 12px 30px rgba(201, 74, 41, 0.5);
    }}
    .btn-secondary {{
      background: rgba(46, 111, 94, 0.18);
      color: #A3E4D1;
      border: 1px solid rgba(62, 142, 121, 0.4);
    }}
    .btn-secondary:hover {{
      background: rgba(46, 111, 94, 0.3);
      color: #FFFFFF;
      transform: translateY(-2px);
    }}
    footer {{
      font-size: 12px;
      color: var(--text-muted);
      text-align: center;
      padding-top: 24px;
      position: relative;
      z-index: 1;
    }}
    footer a {{
      color: var(--gold);
      text-decoration: none;
      font-weight: 600;
    }}
    footer a:hover {{
      text-decoration: underline;
    }}
  </style>
</head>
<body>
  <div class="glow-sphere"></div>
  <div class="container">
    <div class="badge">
      <div class="dot"></div>
      <span>urheart.asiverticals.me • Sovereign Node Online</span>
    </div>
    <h1>UR-Heart Sanctuary</h1>
    <p class="tagline">A Mindful, Zero-Surveillance Kinship Network by Asiverticals. Cryptographically protected, soul-aligned discovery, and Eva AI companionship.</p>

    <div class="card">
      <div class="grid">
        <div class="pillar">
          <h3>E2E Shielded</h3>
          <p>Zero unencrypted metadata. Ephemeral contact bridges and strict user sovereign control.</p>
        </div>
        <div class="pillar">
          <h3>Eva Companion</h3>
          <p>Multi-language contextual confidante supporting English and Hinglish seamlessly.</p>
        </div>
        <div class="pillar">
          <h3>Legal Vault</h3>
          <p>Full GDPR, DPDP, and California privacy compliance with one-tap irrevocable erasure.</p>
        </div>
      </div>

      <div class="actions">
        <a class="btn btn-primary" href="urheart://open">Open UR-Heart App</a>
        <a class="btn btn-secondary" href="/store">Sanctuary Web Store (10% Bonus) 🛒</a>
        <a class="btn btn-secondary" href="https://asiverticals.me" target="_blank" rel="noopener">Visit Asiverticals ↗</a>
      </div>
    </div>
  </div>

  <footer>
    <p>© 2026 Asiverticals. All rights reserved. • <a href="https://urheart.asiverticals.me">urheart.asiverticals.me</a> • <a href="/health">System Status</a></p>
  </footer>
</body>
</html>"""
        return HTMLResponse(content=html, status_code=200)

    # High-speed API / Probe response
    return JSONResponse(
        content={
            "status": "healthy",
            "service": settings.APP_NAME,
            "domain": "urheart.asiverticals.me",
            "parent_entity": "asiverticals.me",
            "version": "1.0.0",
        },
        headers={"X-Sanctuary-Alive": "true", "Cache-Control": "no-cache"}
    )
