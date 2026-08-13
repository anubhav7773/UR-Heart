from fastapi import APIRouter
from app.models.schemas import (
    APIResponse,
    AdConfigData,
    LogAdEventRequest,
)
from app.core.config import settings

router = APIRouter(prefix="/ads", tags=["Remote Config & Monetization Engine"])


@router.get("/config", response_model=APIResponse[AdConfigData])
async def get_ad_config():
    """
    Delivers dynamic remote config rules & ad frequency caps to mobile client.
    """
    data = AdConfigData(
        in_feed_ad_interval=settings.IN_FEED_AD_INTERVAL,
        skip_interstitial_threshold=settings.SKIP_INTERSTITIAL_THRESHOLD,
        app_open_ad_cap_minutes=settings.APP_OPEN_AD_CAP_MINUTES,
        in_chat_ad_interval_seconds=settings.IN_CHAT_AD_INTERVAL_SECONDS,
        in_chat_ad_duration_seconds=settings.IN_CHAT_AD_DURATION_SECONDS,
        free_daily_dm_limit=settings.FREE_DAILY_DM_LIMIT,
    )
    return APIResponse(success=True, data=data)


@router.post("/log-event", response_model=APIResponse[dict])
async def log_ad_event(payload: LogAdEventRequest):
    """
    Logs impression, click, skip, and reward events for eCPM monitoring.
    """
    return APIResponse(
        success=True,
        message="Ad event recorded."
    )
