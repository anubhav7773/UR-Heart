import time
from fastapi import APIRouter, Request, Response, status
from app.core.config import get_settings
from app.core.limiter import limiter

router = APIRouter(prefix="/health", tags=["Health & Sentinel"])
settings = get_settings()
START_TIME = time.time()


@router.api_route("", methods=["GET", "HEAD"], status_code=status.HTTP_200_OK)
@limiter.limit("120/minute")
async def health_check(request: Request, response: Response):

    """
    Handles UptimeRobot 5-minute HEAD ping.
    Returns zero body on HEAD to save bandwidth while preventing Render spin-down.
    Sets X-Sanctuary-Alive: true header.
    """
    response.headers["X-Sanctuary-Alive"] = "true"
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"

    if request.method == "HEAD":
        return Response(
            status_code=status.HTTP_200_OK,
            headers={
                "X-Sanctuary-Alive": "true",
                "Cache-Control": "no-cache, no-store, must-revalidate",
            },
            media_type="text/plain"
        )

    return {
        "status": "active",
        "service": "UR-Heart Core Engine",
        "engine": "FastAPI-Async-Sleepless",
        "uptime_seconds": round(time.time() - START_TIME, 2),
        "environment": settings.ENVIRONMENT,
    }
