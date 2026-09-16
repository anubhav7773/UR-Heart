from datetime import date, datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, not_, or_

from app.core.config import settings
from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match
from app.models.schemas.feed import (
    CandidateProfile,
    CandidatePhoto,
    FeedResponse,
    SwipeRequest,
    SwipeResponse,
)

router = APIRouter()

DEFAULT_INTERESTS_MAP = {
    "lucknow": ["Chai Lover", "Bollywood", "Urdu Poetry", "Foodie"],
    "gorakhpur": ["Bhojpuri Music", "Cricket", "Travel", "Street Food"],
    "patna": ["Civil Services", "Reading", "Badminton", "Litti Chokha"],
    "indore": ["Poha Jalebi", "Startups", "Night Bazaars", "Music"],
    "delhi": ["Cafes", "Art Galleries", "Fitness", "Shopping"],
}

@router.get("", response_model=FeedResponse, status_code=status.HTTP_200_OK)
async def get_discovery_feed(
    limit: int = Query(20, ge=1, le=50),
    city: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns verified candidate profiles for the Discovery Swipe Feed:
    - Filters out the current user.
    - Excludes users already swiped on by current_user.
    - Excludes banned or soft-deleted accounts.
    - Matches location / gender dynamics.
    - Populates candidate photos and interests.
    """
    # 1. Query IDs of users current user has already swiped
    swiped_subquery = select(Swipe.target_id).where(Swipe.actor_id == current_user.id)

    # 2. Build candidate query
    query = (
        select(User)
        .where(
            User.id != current_user.id,
            User.is_banned == False,
            User.deleted_at.is_(None),
            not_(User.id.in_(swiped_subquery)),
        )
    )

    # Filter opposite gender if binary, else show all
    if current_user.gender == "male":
        query = query.where(User.gender == "female")
    elif current_user.gender == "female":
        query = query.where(User.gender == "male")

    if city:
        query = query.where(User.city.ilike(f"%{city}%"))

    query = query.order_by(User.created_at.desc()).limit(limit)
    res = await db.execute(query)
    candidate_users = res.scalars().all()

    candidates: List[CandidateProfile] = []
    today = date.today()

    for user in candidate_users:
        # Calculate Age
        age = (today - user.dob).days // 365 if user.dob else 22

        # Fetch Photos for Candidate
        photos_query = (
            select(UserPhoto)
            .where(UserPhoto.user_id == user.id)
            .order_by(UserPhoto.slot_index.asc())
        )
        photos_res = await db.execute(photos_query)
        user_photos = photos_res.scalars().all()

        photo_list: List[CandidatePhoto] = []
        for p in user_photos:
            path = p.photo_storage_path
            if not path.startswith("http"):
                url = f"{settings.SUPABASE_URL}/storage/v1/object/public/user-photos/{path}"
            else:
                url = path
            photo_list.append(
                CandidatePhoto(
                    slot_index=p.slot_index,
                    photo_url=url,
                    blur_hash=p.blur_hash or "",
                )
            )

        # Fallback profile photo if none uploaded yet
        if not photo_list:
            gender_seed = "girl" if user.gender == "female" else "boy"
            fallback_url = f"https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80" if user.gender == "female" else "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80"
            photo_list.append(
                CandidatePhoto(
                    slot_index=1,
                    photo_url=fallback_url,
                    blur_hash="LEHV6nWB2yk8pyo0adR*.7kCMdnj",
                )
            )

        # Determine interest chips
        city_key = (user.city or "").lower()
        interests = DEFAULT_INTERESTS_MAP.get(city_key, ["Music", "Travel", "Chai", "Photography"])

        candidates.append(
            CandidateProfile(
                id=user.id,
                full_name=user.full_name,
                age=max(18, age),
                city=user.city or "Lucknow",
                bio=user.bio or "Here to connect authentically on UR-Heart.",
                gender=user.gender,
                streak_count=user.streak_count or 0,
                kyc_status=user.kyc_status,
                interests=interests,
                photos=photo_list,
            )
        )

    return FeedResponse(candidates=candidates, total=len(candidates))


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
                await db.refresh(new_match)
                return SwipeResponse(
                    status="success",
                    is_match=True,
                    match_id=new_match.id,
                    message="Congratulations! It's a mutual match!"
                )
            else:
                return SwipeResponse(
                    status="success",
                    is_match=True,
                    match_id=existing_match.id,
                    message="Already matched!"
                )

    return SwipeResponse(
        status="success",
        is_match=False,
        match_id=None,
        message="Swipe recorded successfully."
    )
