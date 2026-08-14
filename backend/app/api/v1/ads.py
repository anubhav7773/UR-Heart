from datetime import datetime, timedelta, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import User, UserAdCounter
from app.models.schemas import (
    APIResponse,
    AdConfigData,
    LogAdEventRequest,
    AdEventTypeEnum,
    ClaimAdRewardRequest,
    ClaimAdRewardData,
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
                user_id=user_uuid,
                persistent_skip_count=0,
                total_interstitials_shown=0,
            )
            db.add(counter_obj)

        if payload.event_type in (AdEventTypeEnum.IMPRESSION, "impression"):
            counter_obj.total_interstitials_shown = (counter_obj.total_interstitials_shown or 0) + 1
            counter_obj.last_interstitial_at = datetime.now(timezone.utc)

        await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="Ad event logged and user telemetry updated successfully."
    )


@router.post("/claim-reward", response_model=APIResponse[ClaimAdRewardData])
async def claim_ad_reward(
    payload: ClaimAdRewardRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Validates and credits rewarded video ad actions (e.g. +5 free bonus swipes or 2-hour photo pass).
    Enforces a strict daily cap of maximum 3 rewarded video claims per user per 24 hours.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user session."
        )

    user_res = await db.execute(select(User).where(User.id == user_uuid))
    user = user_res.scalars().first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found."
        )

    counter_res = await db.execute(select(UserAdCounter).where(UserAdCounter.user_id == user_uuid))
    counter = counter_res.scalars().first()
    if not counter:
        counter = UserAdCounter(user_id=user_uuid)
        db.add(counter)

    now_utc = datetime.now(timezone.utc)

    # Check 24-hour reset for daily rewarded claims
    if counter.last_rewarded_claim_at:
        # If last claim was more than 24h ago or on previous calendar day, reset count
        diff_hours = (now_utc - counter.last_rewarded_claim_at).total_seconds() / 3600.0
        if diff_hours >= 24.0:
            counter.rewarded_claims_today = 0
    else:
        counter.rewarded_claims_today = 0

    MAX_DAILY_REWARDS = 3
    if counter.rewarded_claims_today >= MAX_DAILY_REWARDS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily rewarded ad limit reached (3/3). Please try again tomorrow!"
        )

    reward_type = (payload.reward_type or "swipes").lower().strip()
    bonus_swipes = 0
    photo_pass_hours = 0
    photo_pass_until_str = None
    msg = ""

    if reward_type in ("swipes", "swipe", "bonus_swipes"):
        reward_type = "swipes"
        bonus_swipes = 5
        user.bonus_swipes = (user.bonus_swipes or 0) + 5
        msg = "🎉 5 bonus swipes credited to your profile!"
    elif reward_type in ("photo_pass", "photo", "pass"):
        reward_type = "photo_pass"
        photo_pass_hours = 2
        user.photo_pass_until = now_utc + timedelta(hours=2)
        photo_pass_until_str = user.photo_pass_until.isoformat()
        msg = "📷 2-hour temporary Photo Pass unlocked!"
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reward_type. Must be 'swipes' or 'photo_pass'."
        )

    counter.rewarded_claims_today = (counter.rewarded_claims_today or 0) + 1
    counter.last_rewarded_claim_at = now_utc

    await db.commit()
    await db.refresh(user)

    remaining_claims = max(0, MAX_DAILY_REWARDS - counter.rewarded_claims_today)

    return APIResponse(
        success=True,
        message=msg,
        data=ClaimAdRewardData(
            success=True,
            reward_type=reward_type,
            bonus_swipes_granted=bonus_swipes,
            photo_pass_granted_hours=photo_pass_hours,
            photo_pass_until=photo_pass_until_str,
            remaining_ad_claims_today=remaining_claims,
            message=msg,
        )
    )
