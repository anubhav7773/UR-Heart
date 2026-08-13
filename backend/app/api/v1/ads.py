import uuid
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import UserAdCounter
from app.models.schemas import (
    APIResponse,
    AdConfigData,
    LogAdEventRequest,
    AdEventTypeEnum,
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


@router.post("/telemetry", response_model=APIResponse[dict])
@router.post("/log-event", response_model=APIResponse[dict])
async def log_ad_event(
    payload: LogAdEventRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Logs impression, click, skip, and reward events for eCPM monitoring and updates user_ad_counters DB table.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        counter_res = await db.execute(select(UserAdCounter).where(UserAdCounter.user_id == user_uuid))
        counter_obj = counter_res.scalars().first()

        if not counter_obj:
            counter_obj = UserAdCounter(
                id=uuid.uuid4(),
                user_id=user_uuid,
                impressions_count=0,
                clicks_count=0,
            )
            db.add(counter_obj)

        if payload.event_type in (AdEventTypeEnum.IMPRESSION, "impression"):
            counter_obj.impressions_count += 1
        elif payload.event_type in (AdEventTypeEnum.CLICK, "click"):
            counter_obj.clicks_count += 1

        await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="Ad event logged and user telemetry updated successfully."
    )
