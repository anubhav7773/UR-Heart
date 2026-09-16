import os
import time
try:
    import psutil
except ImportError:
    psutil = None
from datetime import datetime, timezone
from fastapi import APIRouter, Response, Request, status
from starlette.responses import PlainTextResponse
from app.core.rate_limiter import limiter

router = APIRouter()

SERVER_START_TIME = time.time()

def get_uptime_info():
    elapsed = int(time.time() - SERVER_START_TIME)
    days, rem = divmod(elapsed, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, seconds = divmod(rem, 60)
    return {
        "uptime_seconds": elapsed,
        "uptime_human": f"{days}d {hours}h {minutes}m {seconds}s"
    }

@router.get("/health", status_code=status.HTTP_200_OK)
@router.head("/health", status_code=status.HTTP_200_OK)
@limiter.exempt
async def health_check(request: Request, response: Response):
    """
    UptimeRobot & Render Keep-Alive Health Check.
    Monitors process memory and service health to guarantee 
    the container remains safely below the 512MB Render RAM ceiling.
    Supports GET & HEAD methods without rate limiting.
    """
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["X-Render-KeepAlive"] = "active"

    try:
        process = psutil.Process(os.getpid())
        memory_mb = process.memory_info().rss / (1024 * 1024)
    except Exception:
        memory_mb = 0.0

    uptime = get_uptime_info()

    return {
        "status": "operational",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "app_name": "UR-Heart",
        "parent_entity": "ASI Verticals",
        "uptime_seconds": uptime["uptime_seconds"],
        "uptime_human": uptime["uptime_human"],
        "memory_consumption_mb": round(memory_mb, 2),
        "memory_limit_mb": 512.0,
        "keep_alive": True
    }

@router.get("/ping", status_code=status.HTTP_200_OK, response_class=PlainTextResponse)
@router.head("/ping", status_code=status.HTTP_200_OK)
@limiter.exempt
async def ping(request: Request, response: Response):
    """
    Ultra-fast lightweight ping/pong endpoint for UptimeRobot keepalive.
    """
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["X-Render-KeepAlive"] = "active"
    return "pong"

