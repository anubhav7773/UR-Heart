import os
import sys
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
import time
from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI, Request, Response, status, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse, PlainTextResponse
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
from app.templates.admin_portal import get_admin_portal_html

settings = get_settings()


def get_allowed_cors_origins() -> List[str]:
    canonical_origins = [
        "https://urheart.app",
        "https://vault.urheart.app",
        "https://urheart.asiverticals.me",
        "https://app.urheart.asiverticals.me",
        "https://ur-heart-dist-bpsc.vercel.app",
        "https://ur-heart.vercel.app",
        "https://urheart.in",
        "https://www.urheart.in",
    ]
    env = (getattr(settings, "ENVIRONMENT", "") or os.getenv("ENVIRONMENT", "production")).lower()
    if env != "production":
        canonical_origins.extend([
            "http://localhost:3000",
            "http://localhost:8000",
            "http://localhost:7357",
            "http://127.0.0.1:3000",
            "http://127.0.0.1:8000",
            "http://127.0.0.1:7357",
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
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|(.*\.?)asiverticals\.me|(.*\.?)vercel\.app|(.*\.?)urheart\.(app|in))(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
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


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    print(f"[UNHANDLED EXCEPTION] {request.method} {request.url.path} -> {exc}", flush=True)
    msg = str(exc) if getattr(settings, "DEBUG", False) else "An unexpected error occurred in the Sanctuary. Please try again later."
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": msg
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


@app.get("/app-ads.txt", response_class=PlainTextResponse, tags=["IAB Authorized Sellers"])
async def get_app_ads_txt():
    """
    IAB Tech Lab app-ads.txt Specification:
    Authorized Digital Sellers for Google AdMob, Meta, Unity, Chartboost, Liftoff.
    Direct crawler verification endpoint for Google Play Store & AdMob verification.
    """
    pub_id = getattr(settings, "ADMOB_PUBLISHER_ID", "pub-XXXXXXXXXXXXXXXX") or "pub-XXXXXXXXXXXXXXXX"
    content = f"""# UR-Heart Sanctuary - Authorized Digital Sellers (app-ads.txt)
# Official IAB Tech Lab Specification: https://iabtechlab.com/ads-txt/
# Developer Domain: https://urheart.asiverticals.me

# 1. Google AdMob (Google LLC)
google.com, {pub_id}, DIRECT, f08c47fec0942fa0

# 2. Meta Audience Network (Facebook, Inc.)
facebook.com, 0000000000000000, DIRECT

# 3. Unity Ads (Unity Technologies)
unityads.com, 0000000, DIRECT

# 4. Chartboost (Chartboost, Inc.)
chartboost.com, 000000000000000000000000, DIRECT

# 5. Liftoff / Vungle (Liftoff Mobile, Inc.)
vungle.com, 000000000000000000000000, DIRECT
"""
    return PlainTextResponse(content=content, media_type="text/plain; charset=utf-8")



def get_sanctuary_overview_html() -> str:
    """Generates the responsive dark-sanctuary platform overview & 9 subsystems HTML."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UR-Heart Sanctuary | The Mindful Slow-Dating Kinship Network</title>
  <meta name="description" content="UR-Heart Sanctuary by Asiverticals: The slow-dating antidote to swipe fatigue. 10 daily intentional swipes, Eva Live 3s biometric KYC, Sacred Graduated Bridge, and DPDP Act 2023 zero-surveillance.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800&family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {{
      --bg: #070B09;
      --card-bg: rgba(18, 28, 24, 0.88);
      --card-border: rgba(43, 61, 53, 0.85);
      --pine: #2E6F5E;
      --pine-glow: #3E8E79;
      --emerald: #4E9F76;
      --gold: #D4AF37;
      --gold-glow: #F3E5AB;
      --coral: #E06D53;
      --coral-dark: #C94A29;
      --text-head: #FFFFFF;
      --text-body: #C8DCD4;
      --text-muted: #829A90;
      --card-sub: rgba(10, 16, 14, 0.7);
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: radial-gradient(circle at 50% 0%, #152821 0%, #070B09 55%, #040605 100%);
      color: var(--text-body);
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      min-height: 100vh;
      line-height: 1.65;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }}
    .glow-sphere {{
      position: fixed;
      top: -160px;
      left: 50%;
      transform: translateX(-50%);
      width: 700px;
      height: 450px;
      background: radial-gradient(ellipse, rgba(46, 111, 94, 0.28), transparent 70%);
      pointer-events: none;
      z-index: 0;
    }}
    .container {{
      max-width: 1040px;
      margin: 0 auto;
      padding: 24px 20px 60px;
      position: relative;
      z-index: 1;
    }}
    /* Top Header */
    header.sanctuary-nav {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-bottom: 24px;
      border-bottom: 1px solid rgba(43, 61, 53, 0.5);
      margin-bottom: 40px;
      flex-wrap: wrap;
      gap: 16px;
    }}
    .brand {{
      display: flex;
      align-items: center;
      gap: 12px;
      text-decoration: none;
    }}
    .brand-logo {{
      width: 44px;
      height: 44px;
      background: linear-gradient(135deg, var(--coral), var(--pine));
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      box-shadow: 0 4px 18px rgba(224, 109, 83, 0.35);
    }}
    .brand-title {{
      font-family: 'Cinzel', Georgia, serif;
      font-size: 22px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: 0.5px;
    }}
    .nav-links {{
      display: flex;
      align-items: center;
      gap: 20px;
      flex-wrap: wrap;
    }}
    .nav-links a {{
      color: var(--text-muted);
      text-decoration: none;
      font-size: 13.5px;
      font-weight: 600;
      transition: color 0.2s;
    }}
    .nav-links a:hover {{
      color: var(--gold);
    }}
    .nav-cta {{
      background: rgba(212, 175, 55, 0.12);
      border: 1px solid rgba(212, 175, 55, 0.35);
      color: var(--gold) !important;
      padding: 6px 14px;
      border-radius: 8px;
    }}
    .nav-cta:hover {{
      background: rgba(212, 175, 55, 0.22);
    }}

    /* Hero Section */
    .hero {{
      text-align: center;
      margin-bottom: 56px;
    }}
    .badge {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 18px;
      background: rgba(46, 111, 94, 0.22);
      border: 1px solid rgba(62, 142, 121, 0.45);
      border-radius: 999px;
      font-size: 12.5px;
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
    h1.hero-title {{
      font-family: 'Cinzel', Georgia, serif;
      font-size: clamp(34px, 6vw, 56px);
      font-weight: 800;
      color: var(--text-head);
      letter-spacing: -0.5px;
      line-height: 1.15;
      margin-bottom: 18px;
    }}
    h1.hero-title span {{
      background: linear-gradient(135deg, var(--gold), #FFF, var(--gold));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }}
    p.tagline {{
      font-size: clamp(16px, 2.5vw, 19px);
      line-height: 1.65;
      color: var(--text-body);
      max-width: 760px;
      margin: 0 auto 36px;
    }}
    .hero-actions {{
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      justify-content: center;
      margin-bottom: 40px;
    }}
    .btn {{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 14px 28px;
      border-radius: 14px;
      font-size: 14px;
      font-weight: 700;
      text-decoration: none;
      transition: all 0.25s ease;
      cursor: pointer;
      border: 1px solid transparent;
    }}
    .btn-primary {{
      background: linear-gradient(135deg, var(--coral), var(--coral-dark));
      color: #FFFFFF;
      box-shadow: 0 8px 24px rgba(224, 109, 83, 0.35);
    }}
    .btn-primary:hover {{
      transform: translateY(-2px);
      box-shadow: 0 12px 32px rgba(224, 109, 83, 0.5);
    }}
    .btn-gold {{
      background: linear-gradient(135deg, var(--gold), #B5902B);
      color: #070B09;
      box-shadow: 0 8px 24px rgba(212, 175, 55, 0.3);
    }}
    .btn-gold:hover {{
      transform: translateY(-2px);
      box-shadow: 0 12px 32px rgba(212, 175, 55, 0.45);
    }}
    .btn-secondary {{
      background: rgba(46, 111, 94, 0.22);
      color: #A3E4D1;
      border: 1px solid rgba(62, 142, 121, 0.45);
    }}
    .btn-secondary:hover {{
      background: rgba(46, 111, 94, 0.38);
      color: #FFFFFF;
      transform: translateY(-2px);
    }}

    /* Stat Banner */
    .stat-banner {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 56px;
    }}
    .stat-card {{
      background: var(--card-sub);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 20px;
      text-align: center;
    }}
    .stat-num {{
      font-family: 'Cinzel', serif;
      font-size: 26px;
      font-weight: 700;
      color: var(--gold);
      margin-bottom: 4px;
    }}
    .stat-label {{
      font-size: 12.5px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      font-weight: 600;
    }}

    /* Section Styling */
    .section-title {{
      font-family: 'Cinzel', Georgia, serif;
      font-size: clamp(24px, 4vw, 34px);
      color: #FFFFFF;
      text-align: center;
      margin-bottom: 12px;
    }}
    .section-desc {{
      text-align: center;
      font-size: 15px;
      color: var(--text-muted);
      max-width: 640px;
      margin: 0 auto 36px;
    }}

    /* Manifesto Box */
    .manifesto-box {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 36px 30px;
      margin-bottom: 60px;
      position: relative;
      overflow: hidden;
    }}
    .manifesto-box::before {{
      content: "";
      position: absolute;
      top: 0;
      left: 0;
      width: 4px;
      height: 100%;
      background: linear-gradient(180deg, var(--gold), var(--pine));
    }}
    .manifesto-box h3 {{
      font-family: 'Cinzel', serif;
      color: var(--gold);
      font-size: 20px;
      margin-bottom: 14px;
    }}
    .manifesto-box p {{
      font-size: 14.5px;
      color: var(--text-body);
      line-height: 1.7;
      margin-bottom: 14px;
    }}

    /* 9 Features Grid */
    .features-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(310px, 1fr));
      gap: 22px;
      margin-bottom: 64px;
    }}
    .feature-card {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 28px 24px;
      transition: all 0.3s ease;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }}
    .feature-card:hover {{
      border-color: rgba(212, 175, 55, 0.45);
      transform: translateY(-3px);
      box-shadow: 0 14px 34px rgba(0,0,0,0.5);
    }}
    .feature-header {{
      display: flex;
      align-items: center;
      gap: 14px;
      margin-bottom: 14px;
    }}
    .feature-icon {{
      width: 48px;
      height: 48px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      background: rgba(212, 175, 55, 0.12);
      border: 1px solid rgba(212, 175, 55, 0.35);
      flex-shrink: 0;
    }}
    .feature-icon.coral {{
      background: rgba(224, 109, 83, 0.15);
      border-color: rgba(224, 109, 83, 0.4);
    }}
    .feature-icon.emerald {{
      background: rgba(78, 159, 118, 0.15);
      border-color: rgba(78, 159, 118, 0.4);
    }}
    .feature-num {{
      font-size: 11px;
      font-weight: 700;
      color: var(--gold);
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }}
    .feature-title {{
      font-family: 'Cinzel', serif;
      font-size: 17px;
      font-weight: 700;
      color: #FFFFFF;
      margin-top: 2px;
    }}
    .feature-text {{
      font-size: 13.5px;
      color: var(--text-body);
      line-height: 1.6;
      margin-bottom: 16px;
    }}
    .feature-chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }}
    .chip {{
      font-size: 11px;
      font-weight: 600;
      padding: 4px 10px;
      border-radius: 6px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: #A3E4D1;
    }}

    /* Workflow Journey */
    .journey-timeline {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 18px;
      margin-bottom: 64px;
    }}
    .step-card {{
      background: var(--card-sub);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 24px;
      position: relative;
    }}
    .step-badge {{
      display: inline-block;
      font-family: 'Cinzel', serif;
      font-size: 12px;
      font-weight: 700;
      color: var(--gold);
      margin-bottom: 8px;
    }}
    .step-title {{
      font-size: 16px;
      font-weight: 700;
      color: #FFFFFF;
      margin-bottom: 8px;
    }}
    .step-desc {{
      font-size: 13px;
      color: var(--text-muted);
      line-height: 1.55;
    }}

    /* Comparison Table */
    .table-container {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      overflow-x: auto;
      padding: 24px;
      margin-bottom: 64px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13.5px;
    }}
    th {{
      padding: 12px 16px;
      border-bottom: 2px solid rgba(43, 61, 53, 0.8);
      color: var(--gold);
      font-family: 'Cinzel', serif;
      font-size: 14px;
    }}
    td {{
      padding: 14px 16px;
      border-bottom: 1px solid rgba(43, 61, 53, 0.4);
      color: var(--text-body);
    }}
    tr:last-child td {{
      border-bottom: none;
    }}

    /* Grievance & Operator Box */
    .desk-box {{
      background: rgba(10, 15, 13, 0.9);
      border: 1.5px solid rgba(212, 175, 55, 0.4);
      border-radius: 20px;
      padding: 28px;
      margin-bottom: 40px;
    }}
    .desk-header {{
      font-family: 'Cinzel', serif;
      font-size: 18px;
      font-weight: 700;
      color: var(--gold);
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 10px;
    }}
    .desk-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 12px;
      font-size: 13.5px;
    }}
    .desk-item strong {{
      color: #FFFFFF;
      display: block;
      margin-bottom: 2px;
    }}

    /* Footer */
    footer {{
      text-align: center;
      font-size: 13px;
      color: var(--text-muted);
      padding-top: 24px;
      border-top: 1px solid rgba(43, 61, 53, 0.5);
    }}
    footer a {{
      color: var(--gold);
      text-decoration: none;
      margin: 0 8px;
    }}
    footer a:hover {{
      text-decoration: underline;
    }}
    .copy-btn-mini {{
      background: rgba(212, 175, 55, 0.15);
      border: 1px solid rgba(212, 175, 55, 0.4);
      color: var(--gold);
      padding: 2px 8px;
      border-radius: 6px;
      font-size: 11px;
      cursor: pointer;
      margin-left: 8px;
    }}
  </style>
</head>
<body>
  <div class="glow-sphere"></div>
  <div class="container">
    
    <!-- Top Navigation -->
    <header class="sanctuary-nav">
      <a href="/" class="brand">
        <div class="brand-logo">♥</div>
        <div class="brand-title">UR-Heart</div>
      </a>
      <nav class="nav-links">
        <a href="#manifesto">Manifesto</a>
        <a href="#features">9 Subsystems</a>
        <a href="#journey">Seeker Journey</a>
        <a href="#governance">DPDP Legal Desk</a>
        <a href="/store" class="nav-cta">Web Store (10% Bonus) 🛒</a>
      </nav>
    </header>

    <!-- Hero Section -->
    <section class="hero">
      <div class="badge">
        <div class="dot"></div>
        <span>urheart.asiverticals.me • Sovereign Node Online • Ayodhya Operational Desk</span>
      </div>
      <h1 class="hero-title">The Slow Dating <span>Sanctuary</span></h1>
      <p class="tagline">
        More than swipes. Safer · Kinder · Real. A conscious kinship network by <strong>Asiverticals</strong> (Proprietor: Anubhav Singh). Deliberately engineered to eradicate swipe fatigue, commodification, and data surveillance.
      </p>

      <div class="hero-actions">
        <a class="btn btn-primary" href="urheart://open">🚀 Open UR-Heart App</a>
        <a class="btn btn-gold" href="/store">🛒 Sanctuary Web Store (10% Bonus)</a>
        <a class="btn btn-secondary" href="/privacy">🛡️ DPDP Privacy Policy</a>
        <a class="btn btn-secondary" href="/terms">⚖️ Community EULA</a>
      </div>
    </section>

    <!-- Stat Banner -->
    <div class="stat-banner">
      <div class="stat-card">
        <div class="stat-num">10 / Day</div>
        <div class="stat-label">Mindful Swipe Quota</div>
      </div>
      <div class="stat-card">
        <div class="stat-num">100% Verified</div>
        <div class="stat-label">Eva Live 3s KYC Liveness</div>
      </div>
      <div class="stat-card">
        <div class="stat-num">Stage 3</div>
        <div class="stat-label">Graduated Bridge Unlock</div>
      </div>
      <div class="stat-card">
        <div class="stat-num">DPDP 2023</div>
        <div class="stat-label">Zero-Surveillance Shield</div>
      </div>
    </div>

    <!-- Manifesto Section -->
    <section class="manifesto-box" id="manifesto">
      <h3>The Anti-Commodity Manifesto: Why UR-Heart Exists</h3>
      <p>
        Modern dating platforms operate like dopamine casinos. They optimize algorithms for addictive infinite scrolling, superficial micro-second snap judgments, ghosting culture, and surveillance capitalism. When human beings are reduced to endless playing cards, loneliness multiplies.
      </p>
      <p>
        <strong>UR-Heart is the sacred alternative.</strong> We introduce deliberate deceleration: a sacred cap of 10 daily intentional swipes, verified human identities through 3-second biometric KYC liveness challenges, deep soul-aligned resonance matching, poetic direct courtship letters, and graduated contact bridges that shield your private contact handles until genuine bilateral trust is proven.
      </p>
      <p style="margin-bottom:0; color:var(--gold); font-weight:600;">
        "We do not commodify human affection. We cultivate intentional kinship."
      </p>
    </section>

    <!-- 9 Core Subsystems -->
    <h2 class="section-title" id="features">The 9 Core Sanctuary Subsystems</h2>
    <p class="section-desc">An exhaustive breakdown of every architectural pillar and feature built into UR-Heart.</p>

    <div class="features-grid">
      <!-- 1. Discovery Deck & Resonance Engine -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon">🧭</div>
            <div>
              <div class="feature-num">Subsystem 01</div>
              <div class="feature-title">Discovery Deck & Resonance Engine</div>
            </div>
          </div>
          <p class="feature-text">
            A deliberate deck capped at <strong>10 Free Daily Swipes</strong> (resetting daily at midnight IST) to eradicate mindless dopamine loops. Every profile computes a real-time <strong>Resonance Score (%)</strong> derived from mutual values, emotional intentions, and lifestyle prompts. Features <strong>1.1 km Fuzzy Geolocation Shielding</strong> so exact GPS coordinates are never broadcast.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">10 Swipes/Day Cap</span>
          <span class="chip">Resonance Algorithm</span>
          <span class="chip">1.1km Fuzzy Geo</span>
          <span class="chip">6 Curated Photo Slots</span>
        </div>
      </div>

      <!-- 2. Direct Letters -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon coral">💌</div>
            <div>
              <div class="feature-num">Subsystem 02</div>
              <div class="feature-title">Direct Letters (Golden Envelopes)</div>
            </div>
          </div>
          <p class="feature-text">
            Bypass blind matching through the lost art of courtship. Compose a thoughtful, poetic letter directly attached to a seeker's heart. Arrives in a distinct <strong>Sacred Golden Envelope</strong> in the recipient's inbox with opening animations. Protected by token scarcity to eliminate unwanted spam.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">Direct Courtship</span>
          <span class="chip">Golden Envelope Inbox</span>
          <span class="chip">Token-Gated Scarcity</span>
          <span class="chip">Priority Delivery</span>
        </div>
      </div>

      <!-- 3. Reciprocal Matches & 1:1 Encrypted Dialogues -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon emerald">💬</div>
            <div>
              <div class="feature-num">Subsystem 03</div>
              <div class="feature-title">Reciprocal Matches & Encrypted Dialogues</div>
            </div>
          </div>
          <p class="feature-text">
            Dialogues unlock strictly when two souls reciprocally match or accept a Direct Letter. Powered by real-time WebSocket infrastructure. Features an active <strong>Pre-Storage Moderation Shield</strong> that filters slurs, off-platform harassment, and extortion attempts before messages ever touch persistent storage.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">Mutual Match Only</span>
          <span class="chip">WebSocket Real-Time</span>
          <span class="chip">Pre-Storage Moderation</span>
          <span class="chip">Ephemeral Message Purge</span>
        </div>
      </div>

      <!-- 4. The Sacred Bridge -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon">🌉</div>
            <div>
              <div class="feature-num">Subsystem 04</div>
              <div class="feature-title">The Sacred Bridge (Graduated Reveal)</div>
            </div>
          </div>
          <p class="feature-text">
            Eliminates premature off-platform harassment. <strong>Stage 1:</strong> Soulful text dialogue. <strong>Stage 2:</strong> Photo exchange & mutual readiness. <strong>Stage 3:</strong> Graduated Bridge Unlock — verified WhatsApp handle or contact crest is revealed strictly upon mutual bilateral consent (after 50+ exchanged messages or mutual agreement). Stored using AES-256 encryption.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">3-Stage Protocol</span>
          <span class="chip">Bilateral Consent</span>
          <span class="chip">AES-256 Storage</span>
          <span class="chip">Anti-Scraping Shield</span>
        </div>
      </div>

      <!-- 5. Eva AI Companion -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon coral">✨</div>
            <div>
              <div class="feature-num">Subsystem 05</div>
              <div class="feature-title">Eva AI Sanctuary Confidante</div>
            </div>
          </div>
          <p class="feature-text">
            Your 24/7 empathetic wingwoman and conversational confidante. Fluent in English and conversational Hinglish. Offers mindful conversation starters, unpacks dating anxieties, assists in articulating genuine reflections, and reminds users of healthy boundaries. 100% sandboxed—never used for public AI training or ads.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">Bilingual / Hinglish</span>
          <span class="chip">Empathetic Coach</span>
          <span class="chip">Contextual Icebreakers</span>
          <span class="chip">Sandboxed Privacy</span>
        </div>
      </div>

      <!-- 6. Eva Live 3-Second Biometric KYC Liveness -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon emerald">🛡️</div>
            <div>
              <div class="feature-num">Subsystem 06</div>
              <div class="feature-title">Eva Live 3s Biometric KYC Liveness</div>
            </div>
          </div>
          <p class="feature-text">
            A zero-catfish sanctuary. Users undergo an active 3-second biometric liveness challenge with randomized micro-actions (blink, smile, turn head) verified via computer vision anti-spoofing. Confirmed seekers earn the permanent <strong>Sacred Check Crest</strong>. <em>Raw biometric video frames are ephemerally discarded immediately after validation.</em>
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">Active 3s Challenge</span>
          <span class="chip">Anti-Spoofing Vision</span>
          <span class="chip">Sacred Check Crest</span>
          <span class="chip">Ephemeral Frame Purge</span>
        </div>
      </div>

      <!-- 7. Kinship Streaks & Decay Shielding -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon">🔥</div>
            <div>
              <div class="feature-num">Subsystem 07</div>
              <div class="feature-title">Kinship Streaks & Decay Shielding</div>
            </div>
          </div>
          <p class="feature-text">
            Nurtures authentic communication consistency without toxic pressure. Daily consecutive dialogues earn sacred flame streaks and Kinship tokens. Features a <strong>36-Hour Grace Window</strong> and gradual decay rather than harsh punitive resets. Streak freeze charms are earnable through mindful community engagement.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">Sacred Flame Streaks</span>
          <span class="chip">36-Hour Grace Window</span>
          <span class="chip">Streak Freeze Charms</span>
          <span class="chip">Kinship Token Rewards</span>
        </div>
      </div>

      <!-- 8. Sovereign Web Store & Transparent Pricing -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon coral">🛒</div>
            <div>
              <div class="feature-num">Subsystem 08</div>
              <div class="feature-title">Sovereign Web Store & Direct Checkout</div>
            </div>
          </div>
          <p class="feature-text">
            Direct web checkout at <code>urheart.asiverticals.me/store</code> supporting instant UPI (Google Pay, PhonePe, Paytm, BHIM), Indian NetBanking, and Credit/Debit Cards via Razorpay webhooks, alongside Google Play Billing. Features a <strong>10% Sovereign Web Bonus</strong> on all direct purchases. Zero recurring traps or deceptive dark patterns.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">10% Web Bonus</span>
          <span class="chip">UPI / NetBanking / Cards</span>
          <span class="chip">Google Play Billing</span>
          <span class="chip">Zero Dark Patterns</span>
        </div>
      </div>

      <!-- 9. Statutory Legal Vault & DPDP Sovereignty -->
      <div class="feature-card">
        <div>
          <div class="feature-header">
            <div class="feature-icon emerald">⚖️</div>
            <div>
              <div class="feature-num">Subsystem 09</div>
              <div class="feature-title">Statutory Legal Vault & DPDP Sovereignty</div>
            </div>
          </div>
          <p class="feature-text">
            Engineered under India's <strong>DPDP Act 2023</strong> and Section 79 of the IT Act 2000. Features <strong>Section 9 Child Protection</strong> (absolute 18+ adult age gate & quarantine), <strong>Section 11 Data Portability</strong> (JSON archive download), <strong>Section 14 Lawful Nominee</strong> designation, and <strong>Section 12 Account Incinerator</strong> with public deletion at <code>/delete-account</code>.
          </p>
        </div>
        <div class="feature-chips">
          <span class="chip">DPDP Act 2023 Compliant</span>
          <span class="chip">Section 79 Safe Harbor</span>
          <span class="chip">24h SLA Grievance Desk</span>
          <span class="chip">Account Incinerator</span>
        </div>
      </div>
    </div>

    <!-- Step-by-Step Seeker Journey -->
    <h2 class="section-title" id="journey">The Seeker Journey: How It Works</h2>
    <p class="section-desc">A guided, intentional path from initial mindful onboarding to genuine, long-term kinship.</p>

    <div class="journey-timeline">
      <div class="step-card">
        <div class="step-badge">STEP 01</div>
        <div class="step-title">Mindful Consent & Theme</div>
        <div class="step-desc">Select your permanent sanctuary aesthetic (Dark Sanctuary Emerald vs Light Dawn Alabaster) and grant granular, unbundled DPDP statutory affirmations.</div>
      </div>
      <div class="step-card">
        <div class="step-badge">STEP 02</div>
        <div class="step-title">Age Gate & Magic Link Auth</div>
        <div class="step-desc">Confirm 18+ adult eligibility via verified Date of Birth and authenticate frictionlessly through secure Magic Link email verification.</div>
      </div>
      <div class="step-card">
        <div class="step-badge">STEP 03</div>
        <div class="step-title">Eva Live 3s KYC Liveness</div>
        <div class="step-desc">Complete a 3-second anti-spoofing micro-gesture test. Instantly earn the verified Sacred Check Crest on your 6-moment persona card.</div>
      </div>
      <div class="step-card">
        <div class="step-badge">STEP 04</div>
        <div class="step-title">Intentional Daily Discovery</div>
        <div class="step-desc">Review your curated 10 daily profiles with computed Resonance Scores and 1.1km fuzzy distance shields. No endless swiping exhaustion.</div>
      </div>
      <div class="step-card">
        <div class="step-badge">STEP 05</div>
        <div class="step-title">Direct Letter or Mutual Match</div>
        <div class="step-desc">Send a heartfelt Golden Envelope letter or exchange reciprocal likes to initiate a protected 1:1 sanctuary dialogue chamber.</div>
      </div>
      <div class="step-card">
        <div class="step-badge">STEP 06</div>
        <div class="step-title">Graduated Sacred Bridge</div>
        <div class="step-desc">Build genuine trust through shielded text, mutual photo requests, and finally unlock verified WhatsApp contact handles upon bilateral consent.</div>
      </div>
    </div>

    <!-- Comparison Table -->
    <h2 class="section-title">The Philosophy: UR-Heart vs Fast-Dating Apps</h2>
    <p class="section-desc">Why conscious seekers choose UR-Heart over transactional swipe apps.</p>

    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Platform Dimension</th>
            <th>Conventional Fast-Dating Apps</th>
            <th>UR-Heart Sanctuary</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>Daily Swipes</strong></td>
            <td>Unlimited / 100+ (Dopamine casino addiction)</td>
            <td><strong>10 Mindful Swipes / Day</strong> (Conscious deceleration)</td>
          </tr>
          <tr>
            <td><strong>Identity Verification</strong></td>
            <td>Optional or easily faked with static selfies</td>
            <td><strong>Eva Live 3s Active KYC</strong> (Zero-catfish guarantee)</td>
          </tr>
          <tr>
            <td><strong>Contact Sharing</strong></td>
            <td>Unregulated; leads to early off-platform stalking</td>
            <td><strong>Graduated Sacred Bridge</strong> (3-stage bilateral consent)</td>
          </tr>
          <tr>
            <td><strong>Data Surveillance</strong></td>
            <td>Data sold to brokers & programmatic ad networks</td>
            <td><strong>DPDP Act 2023 Zero-Surveillance</strong> (No ad brokers)</td>
          </tr>
          <tr>
            <td><strong>Location Privacy</strong></td>
            <td>Exact GPS coordinates tracked & exposed</td>
            <td><strong>1.1 km Fuzzy Geolocation Shield</strong></td>
          </tr>
          <tr>
            <td><strong>Grievance Mechanism</strong></td>
            <td>Automated bots with weeks of non-response</td>
            <td><strong>Statutory Officer (Anubhav Singh)</strong>: 24h SLA</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Statutory Officer & Grievance Desk -->
    <section class="desk-box" id="governance">
      <div class="desk-header">⚖️ Statutory Operational & Grievance Redressal Desk</div>
      <p style="font-size:13.5px; color:var(--text-body); margin-bottom:16px;">
        In compliance with Rule 3(2) of the Information Technology Rules, 2021 and the Digital Personal Data Protection Act, 2023, the details of our designated Grievance Officer and operational headquarters are published below:
      </p>

      <div class="desk-grid">
        <div class="desk-item">
          <strong>Operating Entity:</strong>
          <span>Asiverticals (Sole Proprietor: Anubhav Singh)</span>
        </div>
        <div class="desk-item">
          <strong>Designated Grievance Officer:</strong>
          <span>Anubhav Singh</span>
        </div>
        <div class="desk-item">
          <strong>Operational & Legal Desk:</strong>
          <span>District Court, Ayodhya, Uttar Pradesh - 224001, India</span>
        </div>
        <div class="desk-item">
          <strong>Statutory Grievance Email:</strong>
          <span>
            <a href="mailto:asiverticals@gmail.com?subject=Statutory%20Inquiry%20UR-Heart" style="color:var(--gold); font-weight:700;">asiverticals@gmail.com</a>
            <button type="button" class="copy-btn-mini" onclick="copyContactEmail('asiverticals@gmail.com', this)">📋 Copy</button>
          </span>
        </div>
        <div class="desk-item">
          <strong>Statutory SLA:</strong>
          <span>Formal acknowledgment within <strong>24 hours</strong>; resolution within <strong>15 days</strong>.</span>
        </div>
        <div class="desk-item">
          <strong>Legal Jurisdiction:</strong>
          <span>Competent Courts in <strong>Ayodhya, Uttar Pradesh, India</strong>.</span>
        </div>
      </div>
    </section>

    <!-- Footer -->
    <footer>
      <p>
        © 2026 Asiverticals (Sole Proprietor: Anubhav Singh). All rights reserved. • 
        <a href="https://urheart.asiverticals.me">urheart.asiverticals.me</a> • 
        <a href="/privacy">Privacy Policy</a> • 
        <a href="/terms">Terms & Community EULA</a> • 
        <a href="/delete-account">Account Deletion</a> • 
        <a href="/store">Sanctuary Store</a> • 
        <a href="/health">System Status</a>
      </p>
      <p style="margin-top:8px; font-size:11.5px; color:#5D756C;">
        Compliant with India's DPDP Act 2023, IT Act 2000 Section 79 Safe Harbor, and IT Rules 2021 Rule 3(2).
      </p>
    </footer>

  </div>

  <script>
    function copyContactEmail(email, btnEl) {{
      if (navigator.clipboard && window.isSecureContext) {{
        navigator.clipboard.writeText(email).then(function() {{
          if (btnEl) {{
            var orig = btnEl.innerText;
            btnEl.innerText = "✓ Copied!";
            setTimeout(function() {{ btnEl.innerText = orig; }}, 2000);
          }}
        }});
      }} else {{
        prompt("Copy email address:", email);
      }}
    }}
  </script>
</body>
</html>"""


@app.get("/appinfo", response_class=HTMLResponse, tags=["Sanctuary Overview"])
@app.get("/overview", response_class=HTMLResponse, tags=["Sanctuary Overview"])
@app.get("/info", response_class=HTMLResponse, tags=["Sanctuary Overview"])
async def sanctuary_appinfo_overview(request: Request):
    """
    Official Web Sanctuary Platform Overview & 9 Subsystems (/appinfo).
    Primary destination for in-app statutory portal links and browser seekers.
    """
    return HTMLResponse(content=get_sanctuary_overview_html(), status_code=200)


@app.get("/admin", response_class=HTMLResponse, tags=["Superadmin Portal"])
@app.get("/admin/portal", response_class=HTMLResponse, tags=["Superadmin Portal"])
async def sanctuary_admin_portal(request: Request):
    """
    Dedicated Zero-Trust Web Admin Portal (SEC-HIGH-01).
    Exclusively authorized for sovereign administrator asiverticals@gmail.com.
    """
    return HTMLResponse(content=get_admin_portal_html(), status_code=200)


@app.api_route("/", methods=["GET", "HEAD"], tags=["Render Health"])
@app.api_route("/health", methods=["GET", "HEAD"], tags=["Render Health"])
@limiter.limit("120/minute")
async def root_health_probe(request: Request):
    """
    Root endpoint:
    - If accessed on '/' with browser accept header, renders responsive dark-sanctuary web landing page.
    - If accessed on '/health' or via API / probe / HEAD, returns high-speed JSON health status.
    """
    accept_header = request.headers.get("accept", "")
    if request.method == "GET" and request.url.path == "/" and ("text/html" in accept_header or accept_header == "*/*" or not accept_header):
        return HTMLResponse(content=get_sanctuary_overview_html(), status_code=200)

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


@app.get("/.well-known/assetlinks.json", summary="Android Digital Asset Links Verification")
async def get_assetlinks():
    """
    Serves official Google Digital Asset Links for seamless Android App Links verification.
    """
    return JSONResponse(
        content=[
            {
                "relation": ["delegate_permission/common.handle_all_urls"],
                "target": {
                    "namespace": "android_app",
                    "package_name": "com.urheart.app",
                    "sha256_cert_fingerprints": [
                        "FB:7F:D1:D6:8E:F6:FA:48:A0:34:EE:B7:09:C0:F2:01:84:4D:C9:D5:2B:37:8F:4A:67:98:62:21:61:4F:90:D6"
                    ]
                }
            }
        ],
        headers={"Content-Type": "application/json", "Cache-Control": "public, max-age=86400"}
    )


@app.get("/favicon.ico", include_in_schema=False)
async def favicon():
    """Return 204 No Content for browser favicon requests to avoid 404 noise."""
    return Response(status_code=status.HTTP_204_NO_CONTENT)
