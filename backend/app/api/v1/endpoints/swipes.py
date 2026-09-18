from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from uuid import UUID
from typing import List, Optional

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.user_photo import UserPhoto
from app.models.domain.match import Match
from app.models.domain.message import Message
from app.models.domain.second_chance import SecondChanceUnlock, SecondChanceDm
from app.services.chat_sanitizer import sanitize_chat_message

router = APIRouter()

# 1. Fetch Missed Connections (Profiles swiped 'pass' within last 14 days)
@router.get("/missed", status_code=status.HTTP_200_OK)
async def get_missed_connections(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    fourteen_days_ago = datetime.now(timezone.utc) - timedelta(days=14)

    # Subquery: Active 24h view unlocks
    unlock_subq = (
        select(SecondChanceUnlock.target_id)
        .where(
            and_(
                SecondChanceUnlock.viewer_id == current_user.id,
                SecondChanceUnlock.expires_at > datetime.now(timezone.utc)
            )
        )
    )

    # Main query joining swipes with target user
    stmt = (
        select(
            User.id,
            User.full_name,
            User.city,
            User.detected_locality,
            User.bio,
            User.streak_count,
            Swipe.created_at.label("passed_at")
        )
        .join(Swipe, Swipe.target_id == User.id)
        .where(
            and_(
                Swipe.actor_id == current_user.id,
                Swipe.swipe_type == "pass",
                Swipe.created_at >= fourteen_days_ago,
                User.deleted_at.is_(None),
                User.is_banned.is_(False)
            )
        )
        .order_by(Swipe.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    rows = result.all()

    # Get active unlocks set
    unlock_res = await db.execute(unlock_subq)
    unlocked_target_ids = set(unlock_res.scalars().all())

    missed_profiles = []
    for r in rows:
        target_id = r.id
        is_unlocked = target_id in unlocked_target_ids

        # Fetch primary photo
        photo_stmt = select(UserPhoto).where(
            and_(UserPhoto.user_id == target_id, UserPhoto.slot_index == 1)
        )
        photo_res = await db.execute(photo_stmt)
        primary_photo = photo_res.scalar_one_or_none()

        missed_profiles.append({
            "user_id": str(target_id),
            "full_name": r.full_name,
            "city": r.city,
            "locality": r.detected_locality or r.city,
            "photo_url": primary_photo.photo_storage_path if primary_photo else None,
            "blur_hash": primary_photo.blur_hash if primary_photo and primary_photo.blur_hash else "LEHLh[WB2yk8pyoJadR*.7kCMdnj",
            "bio": r.bio if is_unlocked else None,  # Obscure bio if locked
            "is_unlocked_for_view": is_unlocked,
            "passed_at": r.passed_at.isoformat()
        })

    return missed_profiles

# 2. Unlock Full Profile View (Triggered after 5-10s Interstitial Ad)
@router.post("/missed/{target_user_id}/unlock-view", status_code=status.HTTP_200_OK)
async def unlock_missed_profile_view(
    target_user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

    # Upsert 24-hour unlock
    existing_stmt = select(SecondChanceUnlock).where(
        and_(
            SecondChanceUnlock.viewer_id == current_user.id,
            SecondChanceUnlock.target_id == target_user_id
        )
    )
    res = await db.execute(existing_stmt)
    existing_unlock = res.scalar_one_or_none()

    if existing_unlock:
        existing_unlock.expires_at = expires_at
        existing_unlock.unlocked_at = datetime.now(timezone.utc)
    else:
        new_unlock = SecondChanceUnlock(
            viewer_id=current_user.id,
            target_id=target_user_id,
            unlocked_at=datetime.now(timezone.utc),
            expires_at=expires_at
        )
        db.add(new_unlock)

    await db.commit()

    # Return target user's full bio
    user_stmt = select(User.bio).where(User.id == target_user_id)
    res = await db.execute(user_stmt)
    bio = res.scalar_one_or_none()

    return {"status": "unlocked", "expires_at": expires_at.isoformat(), "bio": bio or ""}

# 3. Send Direct DM to Missed Profile (Triggered after 30s Rewarded Video Ad)
@router.post("/missed/{target_user_id}/send-dm", status_code=status.HTTP_200_OK)
async def send_missed_connection_dm(
    target_user_id: UUID,
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    message_text = payload.get("message", "").strip()
    if not message_text:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty.")

    # Anti-Leak NLP Guard
    if not sanitize_chat_message(message_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Sharing phone numbers, social media handles (@, IG, WA), or links is strictly prohibited."
        )

    # Daily Limit Guard: Max 3 Second-Chance DMs per 24 hours
    twenty_four_hours_ago = datetime.now(timezone.utc) - timedelta(hours=24)
    daily_count_stmt = select(func.count(SecondChanceDm.id)).where(
        and_(
            SecondChanceDm.sender_id == current_user.id,
            SecondChanceDm.created_at >= twenty_four_hours_ago
        )
    )
    count_res = await db.execute(daily_count_stmt)
    if (count_res.scalar_one() or 0) >= 3:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily limit reached: Maximum 3 Second-Chance Direct DMs per day."
        )

    # Execute atomic insertion of DM into second_chance_dms ledger
    dm_log = SecondChanceDm(
        sender_id=current_user.id,
        recipient_id=target_user_id,
        created_at=datetime.now(timezone.utc)
    )
    db.add(dm_log)

    # Ensure Match exists and append Message
    match_stmt = select(Match).where(
        or_(
            and_(Match.user1_id == current_user.id, Match.user2_id == target_user_id),
            and_(Match.user1_id == target_user_id, Match.user2_id == current_user.id)
        )
    )
    match_res = await db.execute(match_stmt)
    existing_match = match_res.scalar_one_or_none()

    if not existing_match:
        from uuid import uuid4
        existing_match = Match(
            id=uuid4(),
            user1_id=current_user.id,
            user2_id=target_user_id,
            created_at=datetime.now(timezone.utc)
        )
        db.add(existing_match)
        await db.flush()

    new_msg = Message(
        match_id=existing_match.id,
        sender_id=current_user.id,
        encrypted_text=message_text,
        status="sent",
        created_at=datetime.now(timezone.utc)
    )
    db.add(new_msg)

    # Update or insert swipe as direct_dm
    swipe_stmt = select(Swipe).where(
        and_(Swipe.actor_id == current_user.id, Swipe.target_id == target_user_id)
    )
    swipe_res = await db.execute(swipe_stmt)
    existing_swipe = swipe_res.scalar_one_or_none()
    if existing_swipe:
        existing_swipe.swipe_type = "direct_dm"
        existing_swipe.created_at = datetime.now(timezone.utc)
    else:
        new_swipe = Swipe(
            actor_id=current_user.id,
            target_id=target_user_id,
            swipe_type="direct_dm",
            created_at=datetime.now(timezone.utc)
        )
        db.add(new_swipe)

    await db.commit()

    return {"status": "sent", "recipient_id": str(target_user_id)}
