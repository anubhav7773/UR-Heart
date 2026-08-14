import uuid
from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_, func
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
    UserReport,
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
    calculate_dynamic_age,
)
from app.services.geo_engine import GeoEngineService
from app.services.ad_engine import AdEngineService
from app.services.notification_engine import NotificationEngineService
from app.services.fcm_service import send_push_notification, send_match_notification

router = APIRouter(prefix="/feed", tags=["Discovery Feed & Swiping Engine"])

_mock_user_skip_counts = {}


def calculate_age(born: Optional[date]) -> Optional[int]:
    if not born:
        return None
    today = date.today()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


@router.get("", response_model=APIResponse[FeedData])
@router.get("/", response_model=APIResponse[FeedData])
async def get_feed(
    limit: int = Query(default=10, ge=1, le=100),
    radius_km: Optional[float] = Query(default=500.0, description="Max distance filter in km"),
    max_distance_km: Optional[float] = Query(default=500.0, description="Max distance filter in km"),
    gender_preference: Optional[str] = Query(default="everyone", description="Filter gender: 'everyone', 'male', or 'female'"),
    min_age: int = Query(default=18, ge=18, le=100, description="Min candidate age"),
    max_age: int = Query(default=100, ge=18, le=100, description="Max candidate age"),
    lat: Optional[float] = Query(default=None, description="Active user GPS latitude"),
    lng: Optional[float] = Query(default=None, description="Active user GPS longitude"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves candidate cards from PostgreSQL based on discovery preference filters
    (gender preference, age range, max distance) and active GPS location coordinates.
    Gracefully falls back to latest active users if location is unavailable or candidates are few.
    """
    profile_cards: List[ProfileCardData] = []
    added_user_ids = set()

    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        return APIResponse(success=True, data=FeedData(cards=[]), message="Invalid user ID session.")

    r_val = radius_km if radius_km is not None else 500.0
    md_val = max_distance_km if max_distance_km is not None else 500.0
    effective_radius = max(r_val, md_val)

    try:
        # 0. Fetch caller user record
        self_res = await db.execute(select(User).where(User.id == user_uuid))
        self_user = self_res.scalars().first()
        user_lat = lat if lat is not None else (float(self_user.latitude) if self_user and self_user.latitude is not None else None)
        user_lng = lng if lng is not None else (float(self_user.longitude) if self_user and self_user.longitude is not None else None)

        # 1. Fetch IDs already swiped by current user
        swiped_res = await db.execute(select(Swipe.swiped_id).where(Swipe.swiper_id == user_uuid))
        excluded_ids = set(swiped_res.scalars().all())
        excluded_ids.add(user_uuid)

        # 2. Exclude blocked users & reported users (both directions)
        blocked_res1 = await db.execute(select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == user_uuid))
        blocked_res2 = await db.execute(select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == user_uuid))
        excluded_ids.update(blocked_res1.scalars().all())
        excluded_ids.update(blocked_res2.scalars().all())

        reported_res1 = await db.execute(select(UserReport.reported_id).where(UserReport.reporter_id == user_uuid))
        reported_res2 = await db.execute(select(UserReport.reporter_id).where(UserReport.reported_id == user_uuid))
        excluded_ids.update(reported_res1.scalars().all())
        excluded_ids.update(reported_res2.scalars().all())

        # Resolve gender filter
        resolved_gender = None
        if gender_preference and str(gender_preference).lower().strip() not in ("everyone", "all", "any", ""):
            g_str = str(gender_preference).lower().strip()
            if g_str in ("male", "m"):
                resolved_gender = ORMGenderEnum.male
            elif g_str in ("female", "f"):
                resolved_gender = ORMGenderEnum.female

        # 3. Primary Query: Active candidates
        stmt = (
            select(User)
            .where(User.is_active == True)
            .where(~User.id.in_(excluded_ids))
            .options(selectinload(User.photos))
            .order_by(User.created_at.desc())
        )
        if resolved_gender:
            stmt = stmt.where(User.gender == resolved_gender)

        result = await db.execute(stmt.limit(limit * 3))
        db_users = result.scalars().all()

        for user in db_users:
            if user.id in added_user_ids:
                continue

            user_age = calculate_age(user.dob)
            if user_age is not None and (user_age < min_age or user_age > max_age):
                continue

            # Calculate distance if coordinates exist
            dist_km = None
            if user_lat is not None and user_lng is not None and user.latitude is not None and user.longitude is not None:
                cand_lat = float(user.latitude)
                cand_lng = float(user.longitude)
                dist_km = GeoEngineService.calculate_haversine_distance(user_lat, user_lng, cand_lat, cand_lng)
                if dist_km > effective_radius and len(profile_cards) >= limit:
                    continue

            dist_label = GeoEngineService.obfuscate_distance(dist_km) if dist_km is not None else "Nearby"
            photos = [p.photo_url for p in user.photos] if user.photos else []
            first_name = user.full_name.split()[0] if user.full_name else "User"
            full_name = user.full_name if user.full_name else "User"
            is_female = user.gender == ORMGenderEnum.female

            profile_cards.append(
                ProfileCardData(
                    user_id=str(user.id),
                    first_name=first_name,
                    full_name=full_name,
                    age=user_age,
                    date_of_birth=user.dob,
                    distance_label=dist_label,
                    bio=user.bio or "Looking for genuine connection on UR Heart.",
                    area_name=user.area_name or "Ayodhya Region",
                    intent=IntentEnum(user.intent.value) if user.intent else IntentEnum.CASUAL,
                    photos=photos,
                    is_verified=bool(user.is_verified),
                    is_verified_local=is_female or True,
                )
            )
            added_user_ids.add(user.id)
            if len(profile_cards) >= limit:
                break

        # 4. Fallback Query: If fewer than limit cards, pull remaining active users
        if len(profile_cards) < limit:
            fallback_stmt = (
                select(User)
                .where(User.is_active == True)
                .where(~User.id.in_(excluded_ids))
                .options(selectinload(User.photos))
                .order_by(User.created_at.desc())
                .limit(limit * 2)
            )
            fallback_res = await db.execute(fallback_stmt)
            for fallback_user in fallback_res.scalars().all():
                if fallback_user.id in added_user_ids:
                    continue
                f_age = calculate_age(fallback_user.dob)
                f_photos = [p.photo_url for p in fallback_user.photos] if fallback_user.photos else []
                f_first_name = fallback_user.full_name.split()[0] if fallback_user.full_name else "User"
                f_full_name = fallback_user.full_name if fallback_user.full_name else "User"
                profile_cards.append(
                    ProfileCardData(
                        user_id=str(fallback_user.id),
                        first_name=f_first_name,
                        full_name=f_full_name,
                        age=f_age,
                        date_of_birth=fallback_user.dob,
                        distance_label="Nearby",
                        bio=fallback_user.bio or "Looking for genuine connection on UR Heart.",
                        area_name=fallback_user.area_name or "Ayodhya Region",
                        intent=IntentEnum(fallback_user.intent.value) if fallback_user.intent else IntentEnum.CASUAL,
                        photos=f_photos,
                        is_verified=bool(fallback_user.is_verified),
                        is_verified_local=True,
                    )
                )
                added_user_ids.add(fallback_user.id)
                if len(profile_cards) >= limit:
                    break

    except Exception as e:
        print(f"[FEED ERROR] Error generating feed for user {current_user_id}: {e}")
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
                match_id_str = ""
                if existing_match:
                    match_id_str = str(existing_match.id)
                else:
                    new_match = Match(
                        user1_id=user_uuid,
                        user2_id=target_uuid
                    )
                    db.add(new_match)
                    await db.commit()
                    await db.refresh(new_match)
                    match_id_str = str(new_match.id)

                # Fetch FCM tokens and names for both matched users
                target_user_res = await db.execute(select(User).where(User.id == target_uuid))
                target_user_obj = target_user_res.scalars().first()
                swiper_res = await db.execute(select(User).where(User.id == user_uuid))
                swiper_user_obj = swiper_res.scalars().first()

                swiper_name = swiper_user_obj.full_name if (swiper_user_obj and swiper_user_obj.full_name) else "Someone"
                target_name = target_user_obj.full_name if (target_user_obj and target_user_obj.full_name) else "Someone"

                # Send push notification to Target User (User A)
                target_fcm = getattr(target_user_obj, 'fcm_token', None) if target_user_obj else None
                if target_user_obj and target_fcm:
                    await send_push_notification(
                        fcm_token=target_fcm,
                        title="It's a Match! 🎉",
                        body=f"You and {swiper_name} liked each other!",
                        data={"type": "match", "match_id": match_id_str}
                    )

                # Send push notification to Swiper User (User B)
                swiper_fcm = getattr(swiper_user_obj, 'fcm_token', None) if swiper_user_obj else None
                if swiper_user_obj and swiper_fcm:
                    await send_push_notification(
                        fcm_token=swiper_fcm,
                        title="It's a Match! 🎉",
                        body=f"You and {target_name} liked each other!",
                        data={"type": "match", "match_id": match_id_str}
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
