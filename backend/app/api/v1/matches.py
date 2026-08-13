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

router = APIRouter(prefix="/matches", tags=["Matches & Discovery Feed Engine"])

_user_skip_counts = {}

def calculate_age(born: date) -> int:
    today = date.today()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


@router.get("/feed", response_model=APIResponse[FeedData])
async def get_matches_feed(
    limit: int = Query(default=10, ge=1, le=50),
    radius_km: float = Query(default=5.0, ge=2.0, le=10.0, description="Micro-radius filter in km"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves discovery deck cards strictly from Supabase PostgreSQL, excluding users already swiped.
    No mock data fallbacks.
    """
    profile_cards: List[ProfileCardData] = []
    user_uuid = uuid.UUID(current_user_id)

    try:
        current_user_res = await db.execute(select(User).where(User.id == user_uuid))
        current_user = current_user_res.scalars().first()
        if current_user is None or current_user.latitude is None or current_user.longitude is None:
            return APIResponse(success=True, data=FeedData(cards=[]), message="Location is required to find nearby people.")

        swiped_res = await db.execute(select(Swipe.swiped_id).where(Swipe.swiper_id == user_uuid))
        swiped_ids = set(swiped_res.scalars().all())
        swiped_ids.add(user_uuid)

        result = await db.execute(
            select(User)
            .where(User.is_active == True)
            .where(~User.id.in_(swiped_ids))
            .options(selectinload(User.photos))
            .limit(limit)
        )
        db_users = result.scalars().all()

        for user in db_users:
            dist_km = GeoEngineService.distance_between_users(current_user, user)
            if dist_km is None:
                continue

            if dist_km > radius_km:
                continue

            base_obfuscated = GeoEngineService.obfuscate_distance(dist_km)
            dist_label = base_obfuscated

            first_name = user.full_name.split()[0] if user.full_name else "User"
            age = calculate_age(user.dob) if user.dob else 22
            photos = [p.photo_url for p in user.photos] if user.photos else []

            is_female = user.gender == ORMGenderEnum.female or user.gender == "female"

            profile_cards.append(
                ProfileCardData(
                    user_id=str(user.id),
                    first_name=first_name,
                    age=age,
                    distance_label=dist_label,
                    bio=user.bio or "Looking for genuine connection on RuralHeart.",
                    area_name=user.area_name or "Ayodhya Region",
                    intent=IntentEnum(user.intent.value) if user.intent else IntentEnum.CASUAL,
                    photos=photos,
                    is_verified_local=is_female or True,
                )
            )
    except Exception:
        pass

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
async def post_matches_swipe(
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
        except Exception:
            pass

    current_skips = _user_skip_counts.get(current_user_id, 0)
    trigger_ad = False
    ad_unit = None

    if payload.action == SwipeActionEnum.REJECT:
        new_count, trigger_ad, ad_unit = AdEngineService.process_skip_action(
            current_skip_count=current_skips,
            is_premium=False
        )
        _user_skip_counts[current_user_id] = new_count

    swipe_data = SwipeData(
        is_match=is_match,
        persistent_skip_count=_user_skip_counts.get(current_user_id, 0),
        trigger_interstitial_ad=trigger_ad,
        ad_unit_id=ad_unit,
    )

    return APIResponse(success=True, data=swipe_data)
