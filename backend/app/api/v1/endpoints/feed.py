import os
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, select, delete, and_, or_

from app.core.config import settings
from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match
from app.models.schemas.feed import (
    SwipeRequest,
    SwipeResponse,
)
from app.services.notification_service import send_push_notification
from app.services.feed_cache import feed_cache

router = APIRouter()

SUPABASE_URL = (os.getenv("SUPABASE_URL") or getattr(settings, "SUPABASE_URL", "") or "https://pzrsyxvjbmzqlzlehuxg.supabase.co").rstrip("/")
STORAGE_BASE_URL = f"{SUPABASE_URL}/storage/v1/object/public/user-photos"

def resolve_photo_url(path_or_url: str) -> str:
    if not path_or_url:
        return ""
    if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
        return path_or_url
    clean_path = path_or_url.lstrip("/")
    return f"{STORAGE_BASE_URL}/{clean_path}"

@router.get("", status_code=status.HTTP_200_OK)
async def get_discovery_feed_endpoint(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    lat: Optional[float] = Query(None, ge=-90.0, le=90.0, description="Caller's current GPS Latitude"),
    lon: Optional[float] = Query(None, ge=-180.0, le=180.0, description="Caller's current GPS Longitude"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns verified candidate profiles for the Discovery Swipe Feed using
    in-memory TTL caching layer to shield database under high concurrency.
    """
    # 1. Attempt cached fetch to shield DB on concurrent swipes
    cached_candidates = feed_cache.get(current_user.city, limit, offset)
    if cached_candidates:
        # Filter out current user ID from cached segment
        return [c for c in cached_candidates if c["user_id"] != str(current_user.id)]

    caller_lat = lat if lat is not None else (float(current_user.latitude) if current_user.latitude is not None else None)
    caller_lon = lon if lon is not None else (float(current_user.longitude) if current_user.longitude is not None else None)

    query = text("""
        SELECT * FROM public.get_discovery_feed(
            :user_id,
            :lat,
            :lon,
            :limit,
            :offset
        );
    """)
    result = await db.execute(query, {
        "user_id": current_user.id,
        "lat": caller_lat,
        "lon": caller_lon,
        "limit": limit,
        "offset": offset,
    })
    rows = result.mappings().all()

    feed_candidates = []
    for row in rows:
        raw_photos = row.get("photos") or []
        normalized_photos = []

        for p in raw_photos:
            raw_url = p.get("photo_url") or p.get("photo_storage_path") or ""
            normalized_url = resolve_photo_url(raw_url)
            normalized_photos.append({
                "slot_index": p.get("slot_index", 1),
                "photo_url": normalized_url,
                "photo_storage_path": normalized_url,
                "blur_hash": p.get("blur_hash") or "LEHLh[WB2yk8pyoJadR*.7kCMdnj",
            })

        if not normalized_photos:
            default_url = f"{STORAGE_BASE_URL}/default_avatar.png"
            normalized_photos.append({
                "slot_index": 1,
                "photo_url": default_url,
                "photo_storage_path": default_url,
                "blur_hash": "LEHLh[WB2yk8pyoJadR*.7kCMdnj",
            })

        feed_candidates.append({
            "id": str(row["user_id"]),
            "user_id": str(row["user_id"]),
            "full_name": row["full_name"],
            "city": row["city"],
            "detected_locality": row.get("detected_locality"),
            "distance_km": row.get("distance_km"),
            "gender": row["gender"],
            "bio": row.get("bio") or "",
            "streak_count": row.get("streak_count") or 0,
            "is_verified": bool(row.get("is_verified", False)),
            "photos": normalized_photos,
        })

    # 3. Store in cache for subsequent concurrent requests
    feed_cache.set(current_user.city, limit, offset, feed_candidates)

    return feed_candidates



@router.post("/swipe", response_model=SwipeResponse, status_code=status.HTTP_200_OK)
async def record_swipe(
    payload: SwipeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Records like, pass, or direct_dm action.
    - If reciprocal like/direct_dm is detected, creates a Match in public.matches.
    - Prevents self-swiping.
    - Returns match status and match_id.
    """
    if payload.target_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot swipe on yourself."
        )

    # 1. Verify target user exists and is not banned
    target_res = await db.execute(
        select(User).where(User.id == payload.target_user_id, User.is_banned == False)
    )
    target_user = target_res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Candidate profile not found or unavailable."
        )

    # 2. Record or update swipe
    existing_swipe_res = await db.execute(
        select(Swipe).where(
            Swipe.actor_id == current_user.id,
            Swipe.target_id == payload.target_user_id,
        )
    )
    existing_swipe = existing_swipe_res.scalar_one_or_none()

    if existing_swipe:
        existing_swipe.swipe_type = payload.swipe_type
        existing_swipe.created_at = datetime.now(timezone.utc)
    else:
        new_swipe = Swipe(
            actor_id=current_user.id,
            target_id=payload.target_user_id,
            swipe_type=payload.swipe_type,
            created_at=datetime.now(timezone.utc),
        )
        db.add(new_swipe)

    remaining_tokens = current_user.reward_balance
    if payload.swipe_type == "direct_dm" and current_user.reward_balance > 0:
        current_user.reward_balance -= 1
        remaining_tokens = current_user.reward_balance
        db.add(current_user)

    await db.commit()

    # 3. Check for Mutual Match on like / direct_dm
    if payload.swipe_type in ("like", "direct_dm"):
        reciprocal_res = await db.execute(
            select(Swipe).where(
                Swipe.actor_id == payload.target_user_id,
                Swipe.target_id == current_user.id,
                Swipe.swipe_type.in_(("like", "direct_dm")),
            )
        )
        reciprocal_swipe = reciprocal_res.scalar_one_or_none()

        if reciprocal_swipe:
            # Check if match already exists
            match_res = await db.execute(
                select(Match).where(
                    or_(
                        and_(Match.user1_id == current_user.id, Match.user2_id == payload.target_user_id),
                        and_(Match.user1_id == payload.target_user_id, Match.user2_id == current_user.id),
                    )
                )
            )
            existing_match = match_res.scalar_one_or_none()

            if not existing_match:
                new_match = Match(
                    user1_id=current_user.id,
                    user2_id=payload.target_user_id,
                    is_active=True,
                    created_at=datetime.now(timezone.utc),
                )
                db.add(new_match)
                await db.commit()
                try:
                    await db.refresh(new_match)
                except Exception:
                    pass

                # Dispatch FCM Push Notifications to both users on mutual match
                try:
                    users_stmt = select(User).where(User.id.in_([current_user.id, payload.target_user_id]))
                    users_res = await db.execute(users_stmt)
                    matched_users = {str(u.id): u for u in users_res.scalars().all()}

                    actor = matched_users.get(str(current_user.id))
                    target = matched_users.get(str(payload.target_user_id))

                    if target and getattr(target, "fcm_token", None):
                        await send_push_notification(
                            fcm_token=target.fcm_token,
                            title="🎉 New Mutual Resonance!",
                            body=f"{actor.full_name if actor else 'Someone'} liked you back! Start chatting now.",
                            data={"type": "mutual_match", "match_id": str(new_match.id)}
                        )

                    if actor and getattr(actor, "fcm_token", None):
                        await send_push_notification(
                            fcm_token=actor.fcm_token,
                            title="🎉 New Mutual Resonance!",
                            body=f"You and {target.full_name if target else 'a new member'} liked each other!",
                            data={"type": "mutual_match", "match_id": str(new_match.id)}
                        )
                except Exception as e:
                    pass

                return SwipeResponse(
                    status="success",
                    is_match=True,
                    match_id=new_match.id,
                    message="Congratulations! It's a mutual match!",
                    whatsapp_unlocked=False,
                    remaining_dm_tokens=remaining_tokens,
                )
            else:
                return SwipeResponse(
                    status="success",
                    is_match=True,
                    match_id=existing_match.id,
                    message="Already matched!",
                    whatsapp_unlocked=False,
                    remaining_dm_tokens=remaining_tokens,
                )

    return SwipeResponse(
        status="success",
        is_match=False,
        match_id=None,
        message="Swipe recorded successfully.",
        whatsapp_unlocked=False,
        remaining_dm_tokens=remaining_tokens,
    )


@router.post("/reset-my-swipes", status_code=status.HTTP_200_OK)
async def reset_my_swipes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Developer & Testing utility: Wipes out previous swipes made by the caller
    so the Discovery Feed immediately refills with all candidates.
    """
    stmt = delete(Swipe).where(Swipe.actor_id == current_user.id)
    result = await db.execute(stmt)
    await db.commit()

    return {
        "status": "success",
        "message": f"Successfully reset {result.rowcount} swipes. Discovery Feed refilled.",
        "actor_id": str(current_user.id)
    }

