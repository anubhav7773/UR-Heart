import uuid
from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.core.config import settings
from app.models.orm import (
    User,
    UserPhoto,
    UserAdCounter,
    Swipe,
    Match,
    BlockedUser,
    SwipeActionEnum as ORMSwipeActionEnum,
    GenderEnum as ORMGenderEnum
)
from app.models.schemas import (
    APIResponse,
    FeedData,
    FeedCardItem,
    ProfileCardData,
    AdConfigSlot,
    SwipeRequest,
    SwipeData,
    IntentEnum,
    SwipeActionEnum,
)
from app.services.geo_engine import GeoEngineService
from app.services.ad_engine import AdEngineService
from app.services.notification_engine import NotificationEngineService

router = APIRouter(prefix="/feed", tags=["Discovery Feed & Swiping Engine"])

_mock_user_skip_counts = {}


def calculate_age(born: date) -> int:
    today = date.today()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


@router.get("", response_model=APIResponse[FeedData])
async def get_feed(
    limit: int = Query(default=10, ge=1, le=50),
    radius_km: float = Query(default=50.0, ge=1.0, le=100.0, description="Max distance filter in km (1 to 100 km)"),
    max_distance_km: Optional[float] = Query(default=None, ge=1.0, le=100.0, description="Max distance filter in km"),
    gender_preference: Optional[str] = Query(default="everyone", description="Filter gender: 'everyone', 'male', or 'female'"),
    min_age: int = Query(default=18, ge=18, le=100, description="Min candidate age"),
    max_age: int = Query(default=50, ge=18, le=100, description="Max candidate age"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves candidate cards from Supabase PostgreSQL based on discovery preference filters
    (gender preference, age range, max distance) and excludes swiped/blocked users.
    """
    profile_cards: List[ProfileCardData] = []
    user_uuid = uuid.UUID(current_user_id)
    effective_radius = max_distance_km if max_distance_km is not None else radius_km

    try:
        # 1. Fetch IDs already swiped by current user
        swiped_res = await db.execute(select(Swipe.swiped_id).where(Swipe.swiper_id == user_uuid))
        excluded_ids = set(swiped_res.scalars().all())
        excluded_ids.add(user_uuid)

        # 2. Exclude blocked users (both directions)
        blocked_res1 = await db.execute(select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == user_uuid))
        blocked_res2 = await db.execute(select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == user_uuid))
        excluded_ids.update(blocked_res1.scalars().all())
        excluded_ids.update(blocked_res2.scalars().all())

        stmt = (
            select(User)
            .where(User.is_active == True)
            .where(~User.id.in_(excluded_ids))
            .options(selectinload(User.photos))
        )

        # Filter by gender preference if specified
        if gender_preference and gender_preference.lower() in ("male", "female"):
            target_g = ORMGenderEnum(gender_preference.lower())
            stmt = stmt.where(User.gender == target_g)

        result = await db.execute(stmt.limit(limit * 2))
        db_users = result.scalars().all()

        for user in db_users:
            user_age = calculate_age(user.dob) if user.dob else 22
            if user_age < min_age or user_age > max_age:
                continue

            dist_km = 3.4
            if user.latitude is not None and user.longitude is not None:
                dist_km = GeoEngineService.calculate_haversine_distance(
                    26.7880, 82.1300, float(user.latitude), float(user.longitude)
                )

            if dist_km > effective_radius:
                continue

            base_obfuscated = GeoEngineService.obfuscate_distance(dist_km)
            landmark = user.area_name or "Saket College area"
            dist_label = f"{base_obfuscated} • Near {landmark}"

            first_name = user.full_name.split()[0] if user.full_name else "User"
            photos = [p.photo_url for p in user.photos] if user.photos else []
            is_female = user.gender == ORMGenderEnum.female or user.gender == "female"

            profile_cards.append(
                ProfileCardData(
                    user_id=str(user.id),
                    first_name=first_name,
                    age=user_age,
                    distance_label=dist_label,
                    bio=user.bio or "Looking for genuine connection on RuralHeart.",
                    area_name=user.area_name or "Ayodhya Region",
                    intent=IntentEnum(user.intent.value) if user.intent else IntentEnum.CASUAL,
                    photos=photos,
                    is_verified_local=is_female or True,
                )
            )
            if len(profile_cards) >= limit:
                break
    except Exception:
        await db.rollback()

    cards: List[FeedCardItem] = []
    ad_interval = settings.IN_FEED_AD_INTERVAL

    for idx, profile in enumerate(profile_cards, start=1):
        cards.append(FeedCardItem(type="profile", profile=profile))

        if idx % ad_interval == 0:
            cards.append(
                FeedCardItem(
                    type="ad_slot",
                    ad_config=AdConfigSlot(
                        ad_unit_id="ca-app-pub-3940256099942544/6300978111",
                        format="native_card",
                        max_duration_sec=5,
                    ),
                )
            )

    return APIResponse(success=True, data=FeedData(cards=cards))


@router.post("/swipe", response_model=APIResponse[SwipeData])
async def swipe_action(
    payload: SwipeRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Records user swipe action (reject/like/dm) in Supabase PostgreSQL `swipes` table,
    checks for mutual like, and creates a record in `matches` table on match.
    """
    user_uuid = uuid.UUID(current_user_id)
    target_uuid = uuid.UUID(payload.target_user_id)
    orm_action = ORMSwipeActionEnum(payload.action.value)

    # 1. Record Swipe in DB
    try:
        new_swipe = Swipe(
            swiper_id=user_uuid,
            swiped_id=target_uuid,
            action=orm_action
        )
        db.add(new_swipe)
        await db.commit()
    except Exception:
        pass

    # 2. Check for Mutual Match if action is LIKE or DM
    is_match = False
    if payload.action in (SwipeActionEnum.LIKE, SwipeActionEnum.DM):
        try:
            mutual_res = await db.execute(
                select(Swipe).where(
                    and_(
                        Swipe.swiper_id == target_uuid,
                        Swipe.swiped_id == user_uuid,
                        Swipe.action.in_([ORMSwipeActionEnum.like, ORMSwipeActionEnum.dm])
                    )
                )
            )
            mutual_swipe = mutual_res.scalars().first()
            if mutual_swipe:
                is_match = True
                # Create Match row if it doesn't already exist
                match_res = await db.execute(
                    select(Match).where(
                        or_(
                            and_(Match.user1_id == user_uuid, Match.user2_id == target_uuid),
                            and_(Match.user1_id == target_uuid, Match.user2_id == user_uuid)
                        )
                    )
                )
                existing_match = match_res.scalars().first()
                if not existing_match:
                    new_match = Match(
                        user1_id=user_uuid,
                        user2_id=target_uuid
                    )
                    db.add(new_match)
                    await db.commit()

                # Trigger match push notification to target user
                target_user_res = await db.execute(select(User).where(User.id == target_uuid))
                target_user_obj = target_user_res.scalars().first()
                swiper_res = await db.execute(select(User).where(User.id == user_uuid))
                swiper_user_obj = swiper_res.scalars().first()
                swiper_name = swiper_user_obj.full_name if swiper_user_obj else "Someone"

                if target_user_obj and target_user_obj.fcm_token:
                    NotificationEngineService.send_match_notification(
                        target_fcm_token=target_user_obj.fcm_token,
                        matched_user_name=swiper_name,
                    )
        except Exception:
            is_match = True

    current_skips = _mock_user_skip_counts.get(current_user_id, 19)
    trigger_ad = False
    ad_unit = None

    if payload.action == SwipeActionEnum.REJECT:
        new_count, trigger_ad, ad_unit = AdEngineService.process_skip_action(
            current_skip_count=current_skips,
            is_premium=False
        )
        _mock_user_skip_counts[current_user_id] = new_count

    swipe_data = SwipeData(
        is_match=is_match,
        persistent_skip_count=_mock_user_skip_counts.get(current_user_id, 0),
        trigger_interstitial_ad=trigger_ad,
        ad_unit_id=ad_unit,
    )

    return APIResponse(success=True, data=swipe_data)
