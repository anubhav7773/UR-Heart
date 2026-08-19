import math
import uuid
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, Response, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_, func, case
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id, register_conversation_participants
from app.core.rate_limiter import rate_limit
from app.core.config import settings
from app.models.orm import (
    User,
    UserPhoto,
    UserAdCounter,
    Swipe,
    Match,
    ChatMessage,
    BlockedUser,
    UserReport,
    ProfileImpression,
    SwipeActionEnum as ORMSwipeActionEnum,
    GenderEnum as ORMGenderEnum,
    VerificationStatusEnum as ORMVerificationStatusEnum,
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
    VerificationStatusEnum,
    DirectDMRequest,
    DirectDMData,
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


def compute_distance_km(lat1, lon1, lat2, lon2) -> Optional[float]:
    if None in (lat1, lon1, lat2, lon2):
        return None
    try:
        R = 6371.0  # Earth radius in KM
        dlat = math.radians(float(lat2) - float(lat1))
        dlon = math.radians(float(lon2) - float(lon1))
        a = math.sin(dlat / 2)**2 + math.cos(math.radians(float(lat1))) * math.cos(math.radians(float(lat2))) * math.sin(dlon / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return round(R * c, 1)
    except Exception:
        return None


@router.get(
    "",
    response_model=APIResponse[FeedData],
    dependencies=[Depends(rate_limit(max_requests=40, window_seconds=60, by_user=True))]
)
@router.get(
    "/",
    response_model=APIResponse[FeedData],
    dependencies=[Depends(rate_limit(max_requests=40, window_seconds=60, by_user=True))]
)
async def get_feed(
    response: Response,
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
    Uses PostGIS spatial indexing (ST_DWithin, ST_Distance) with sub-5ms performance and GIST index.
    Gracefully falls back to bounding-box/relational scan if PostGIS is not available.
    """
    # Cache header for high-throughput mobile discovery feeds
    response.headers["Cache-Control"] = "private, max-age=5"

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
        # 0. Fetch caller user record and update presence
        self_res = await db.execute(select(User).where(User.id == user_uuid))
        self_user = self_res.scalars().first()
        if self_user:
            self_user.last_seen = datetime.now(timezone.utc)
            self_user.is_online = True
            try:
                await db.commit()
            except Exception:
                pass
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

        now_dt = datetime.now(timezone.utc)

        # 3. PostGIS Spatial Point & Distance Expressions
        current_point = None
        distance_expr = None
        if user_lat is not None and user_lng is not None:
            # WGS 84 Point with SRID 4326 (ST_MakePoint takes longitude, latitude)
            current_point = func.ST_SetSRID(func.ST_MakePoint(user_lng, user_lat), 4326)
            # PostGIS ST_Distance returns meters for geography; divide by 1000.0 for kilometers
            distance_expr = (func.ST_Distance(User.location_geom, current_point) / 1000.0).label("distance_km")

        db_candidates: List[tuple[User, Optional[float]]] = []

        # 4. Primary Spatial Discovery Query (Leveraging PostGIS GIST index)
        if current_point is not None and distance_expr is not None:
            try:
                radius_meters = float(effective_radius) * 1000.0
                stmt = (
                    select(User, distance_expr)
                    .where(User.is_active == True)
                    .where(~User.id.in_(excluded_ids))
                    .where(
                        or_(
                            User.location_geom == None,
                            func.ST_DWithin(User.location_geom, current_point, radius_meters)
                        )
                    )
                    .options(selectinload(User.photos))
                    .order_by(
                        case((User.boosted_until > func.now(), 1), else_=0).desc(),
                        User.created_at.desc()
                    )
                )
                if resolved_gender:
                    stmt = stmt.where(User.gender == resolved_gender)

                result = await db.execute(stmt.limit(limit * 3))
                raw_rows = result.all()
                db_candidates = [(row[0], float(row[1]) if row[1] is not None else None) for row in raw_rows]
            except Exception as spatial_err:
                print(f"[FEED POSTGIS NOTICE] Primary spatial query fallback to standard relational query: {spatial_err}")
                await db.rollback()
                db_candidates = []

        # Standard Relational Fallback Query if PostGIS is not available or returned no rows
        if not db_candidates:
            stmt = (
                select(User)
                .where(User.is_active == True)
                .where(~User.id.in_(excluded_ids))
                .options(selectinload(User.photos))
                .order_by(
                    case((User.boosted_until > func.now(), 1), else_=0).desc(),
                    User.created_at.desc()
                )
            )
            if resolved_gender:
                stmt = stmt.where(User.gender == resolved_gender)

            result = await db.execute(stmt.limit(limit * 3))
            db_candidates = [(u, None) for u in result.scalars().all()]

        for user, postgis_dist_km in db_candidates:
            if user.id in added_user_ids:
                continue

            user_age = calculate_age(user.dob)
            if user_age is not None and (user_age < min_age or user_age > max_age):
                continue

            # Resolve accurate distance either from PostGIS ST_Distance or fallback Haversine
            dist_km = postgis_dist_km
            if dist_km is None and user_lat is not None and user_lng is not None and user.latitude is not None and user.longitude is not None:
                dist_km = compute_distance_km(user_lat, user_lng, float(user.latitude), float(user.longitude))

            if dist_km is not None and dist_km > effective_radius and len(profile_cards) >= limit:
                continue

            if dist_km is not None:
                dist_label = "< 1 km away" if dist_km < 1.0 else f"{round(dist_km, 1)} km away"
            else:
                dist_label = "Nearby"

            photos = [p.photo_url for p in user.photos] if user.photos else []
            first_name = user.full_name.split()[0] if user.full_name else "User"
            full_name = user.full_name if user.full_name else "User"
            
            # Strict verification badge check: approved only
            v_status_val = user.verification_status.value if getattr(user, 'verification_status', None) else "UNVERIFIED"
            is_approved = bool(user.is_verified and getattr(user, 'verification_status', None) == ORMVerificationStatusEnum.APPROVED)
            is_boosted = bool(user.boosted_until and user.boosted_until > now_dt)

            target_active = user.last_seen or user.created_at
            card_is_online = False
            if target_active:
                if target_active.tzinfo is None:
                    target_active = target_active.replace(tzinfo=timezone.utc)
                card_is_online = (now_dt - target_active).total_seconds() < 180

            profile_cards.append(
                ProfileCardData(
                    user_id=str(user.id),
                    first_name=first_name,
                    full_name=full_name,
                    age=user_age,
                    date_of_birth=user.dob,
                    distance_km=dist_km,
                    distance_label=dist_label,
                    bio=user.bio or "Looking for genuine connection on UR Heart.",
                    area_name=user.area_name or "Ayodhya Region",
                    intent=IntentEnum(user.intent.value) if user.intent else IntentEnum.CASUAL,
                    photos=photos,
                    is_verified=is_approved,
                    verification_status=VerificationStatusEnum(v_status_val),
                    is_verified_local=is_approved,
                    is_boosted=is_boosted,
                    boosted_until=user.boosted_until,
                    voice_bio_url=user.voice_bio_url,
                    voice_bio_duration_seconds=user.voice_bio_duration_seconds or 0,
                    is_online=card_is_online,
                    last_seen=target_active,
                    last_active_at=target_active,
                )
            )
            added_user_ids.add(user.id)
            if len(profile_cards) >= limit:
                break

        # 5. Fallback Query: If fewer than limit cards, pull remaining active users
        if len(profile_cards) < limit:
            fallback_candidates: List[tuple[User, Optional[float]]] = []
            if current_point is not None and distance_expr is not None:
                try:
                    fallback_stmt = (
                        select(User, distance_expr)
                        .where(User.is_active == True)
                        .where(~User.id.in_(excluded_ids))
                        .options(selectinload(User.photos))
                        .order_by(
                            case((User.boosted_until > func.now(), 1), else_=0).desc(),
                            User.created_at.desc()
                        )
                        .limit(limit * 2)
                    )
                    fallback_res = await db.execute(fallback_stmt)
                    fallback_candidates = [(row[0], float(row[1]) if row[1] is not None else None) for row in fallback_res.all()]
                except Exception:
                    await db.rollback()
                    fallback_candidates = []

            if not fallback_candidates:
                fallback_stmt = (
                    select(User)
                    .where(User.is_active == True)
                    .where(~User.id.in_(excluded_ids))
                    .options(selectinload(User.photos))
                    .order_by(
                        case((User.boosted_until > func.now(), 1), else_=0).desc(),
                        User.created_at.desc()
                    )
                    .limit(limit * 2)
                )
                fallback_res = await db.execute(fallback_stmt)
                fallback_candidates = [(u, None) for u in fallback_res.scalars().all()]

            for fallback_user, fb_postgis_dist_km in fallback_candidates:
                if fallback_user.id in added_user_ids:
                    continue
                f_age = calculate_age(fallback_user.dob)
                f_photos = [p.photo_url for p in fallback_user.photos] if fallback_user.photos else []
                f_first_name = fallback_user.full_name.split()[0] if fallback_user.full_name else "User"
                f_full_name = fallback_user.full_name if fallback_user.full_name else "User"

                # Calculate fallback distance
                f_dist_km = fb_postgis_dist_km
                if f_dist_km is None and user_lat is not None and user_lng is not None and fallback_user.latitude is not None and fallback_user.longitude is not None:
                    f_dist_km = compute_distance_km(user_lat, user_lng, float(fallback_user.latitude), float(fallback_user.longitude))

                if f_dist_km is not None:
                    f_dist_label = "< 1 km away" if f_dist_km < 1.0 else f"{round(f_dist_km, 1)} km away"
                else:
                    f_dist_label = "Nearby"

                f_status_val = fallback_user.verification_status.value if getattr(fallback_user, 'verification_status', None) else "UNVERIFIED"
                f_is_approved = bool(fallback_user.is_verified and getattr(fallback_user, 'verification_status', None) == ORMVerificationStatusEnum.APPROVED)
                f_is_boosted = bool(fallback_user.boosted_until and fallback_user.boosted_until > now_dt)

                fb_active = fallback_user.last_seen or fallback_user.created_at
                fb_is_online = False
                if fb_active:
                    if fb_active.tzinfo is None:
                        fb_active = fb_active.replace(tzinfo=timezone.utc)
                    fb_is_online = (now_dt - fb_active).total_seconds() < 180

                profile_cards.append(
                    ProfileCardData(
                        user_id=str(fallback_user.id),
                        first_name=f_first_name,
                        full_name=f_full_name,
                        age=f_age,
                        date_of_birth=fallback_user.dob,
                        distance_km=f_dist_km,
                        distance_label=f_dist_label,
                        bio=fallback_user.bio or "Looking for genuine connection on UR Heart.",
                        area_name=fallback_user.area_name or "Ayodhya Region",
                        intent=IntentEnum(fallback_user.intent.value) if fallback_user.intent else IntentEnum.CASUAL,
                        photos=f_photos,
                        is_verified=f_is_approved,
                        verification_status=VerificationStatusEnum(f_status_val),
                        is_verified_local=f_is_approved,
                        is_boosted=f_is_boosted,
                        boosted_until=fallback_user.boosted_until,
                        voice_bio_url=fallback_user.voice_bio_url,
                        voice_bio_duration_seconds=fallback_user.voice_bio_duration_seconds or 0,
                        is_online=fb_is_online,
                        last_seen=fb_active,
                        last_active_at=fb_active,
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
@router.post("/swipe/", response_model=APIResponse[SwipeData])
async def swipe_action(
    payload: SwipeRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Records user swipe action (reject/like/dm) in Supabase PostgreSQL `swipes` table,
    checks for mutual like, and creates a record in `matches` table on match.
    Validates user session and target profile existence to prevent FK constraint failures.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        target_uuid = uuid.UUID(payload.target_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID format.")

    # Verify that authenticated caller exists in DB
    current_user_res = await db.execute(select(User).where(User.id == user_uuid))
    current_user = current_user_res.scalars().first()
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired, please log in again."
        )

    # Verify target profile exists in DB
    target_user_res = await db.execute(select(User).where(User.id == target_uuid))
    target_user_obj = target_user_res.scalars().first()
    if target_user_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target profile not found."
        )

    orm_action = ORMSwipeActionEnum(payload.action.value)

    # 1. Record Swipe in DB safely
    try:
        new_swipe = Swipe(
            swiper_id=user_uuid,
            swiped_id=target_uuid,
            action=orm_action
        )
        db.add(new_swipe)
        await db.commit()

        # Log Profile Impression (Ghost Passer / Visitor) if swiping left (pass)
        if payload.action == SwipeActionEnum.REJECT and user_uuid != target_uuid:
            try:
                imp_res = await db.execute(
                    select(ProfileImpression).where(
                        and_(
                            ProfileImpression.visitor_id == user_uuid,
                            ProfileImpression.target_id == target_uuid,
                        )
                    )
                )
                imp_obj = imp_res.scalars().first()
                if imp_obj:
                    imp_obj.action_type = "pass"
                    imp_obj.created_at = datetime.now(timezone.utc)
                else:
                    db.add(
                        ProfileImpression(
                            visitor_id=user_uuid,
                            target_id=target_uuid,
                            action_type="pass",
                        )
                    )
                await db.commit()
            except Exception:
                await db.rollback()
    except Exception as e:
        await db.rollback()
        print(f"[SWIPE INSERT ERROR] Failed to record swipe: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Swipe action could not be recorded."
        )

    # 2. Check for Mutual Match if action is LIKE or DM
    is_match = False
    match_id_str = ""
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

                swiper_name = current_user.full_name if current_user.full_name else "Someone"
                target_name = target_user_obj.full_name if target_user_obj.full_name else "Someone"

                # Send push notification to Target User (User A)
                target_fcm = getattr(target_user_obj, 'fcm_token', None)
                if target_fcm:
                    await send_push_notification(
                        fcm_token=target_fcm,
                        title="It's a Match! 🎉",
                        body=f"You and {swiper_name} liked each other!",
                        data={"type": "match", "match_id": match_id_str}
                    )

                # Send push notification to Swiper User (User B)
                swiper_fcm = getattr(current_user, 'fcm_token', None)
                if swiper_fcm:
                    await send_push_notification(
                        fcm_token=swiper_fcm,
                        title="It's a Match! 🎉",
                        body=f"You and {target_name} liked each other!",
                        data={"type": "match", "match_id": match_id_str}
                    )
        except Exception as e:
            print(f"[MUTUAL MATCH ERROR] {e}")
            await db.rollback()

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
        match_id=match_id_str if is_match else None,
        persistent_skip_count=_mock_user_skip_counts.get(current_user_id, 0),
        trigger_interstitial_ad=trigger_ad,
        ad_unit_id=ad_unit,
    )

    return APIResponse(success=True, data=swipe_data)


@router.post("/direct-dm", response_model=APIResponse[DirectDMData])
async def send_direct_dm(
    payload: DirectDMRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Direct DM Route:
    - Verifies user has active direct_dm_until pass.
    - If expired or not present: raises 403 HTTP error ("Direct DM pass expired or inactive").
    - Creates or retrieves Match between users.
    - Inserts the initial message into chat_messages.
    - Triggers FCM push notification to target_user_id.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        target_uuid = uuid.UUID(payload.target_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    if user_uuid == target_uuid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot send Direct DM to yourself."
        )

    now_utc = datetime.now(timezone.utc)

    # 1. Fetch current user and verify direct DM pass
    is_pass_valid = False
    current_user = None
    try:
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        current_user = user_res.scalars().first()
        if current_user and current_user.direct_dm_until and current_user.direct_dm_until > now_utc:
            is_pass_valid = True
    except Exception:
        current_user = None

    if not is_pass_valid:
        from app.api.v1.payments import _mock_user_passes
        mock_p = _mock_user_passes.get(current_user_id)
        if mock_p and mock_p.get("direct_dm_until") and mock_p.get("direct_dm_until") > now_utc:
            is_pass_valid = True

    if not is_pass_valid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Direct DM pass expired or inactive. Please unlock the ₹49 Direct DM Pass."
        )

    match_id_str = str(uuid.uuid4())
    register_conversation_participants(match_id_str, current_user_id, payload.target_user_id)
    msg_id = uuid.uuid4()
    sender_name = current_user.full_name if current_user and current_user.full_name else "Someone"

    try:
        target_res = await db.execute(select(User).where(User.id == target_uuid))
        target_user = target_res.scalars().first()

        match_res = await db.execute(
            select(Match).where(
                or_(
                    and_(Match.user1_id == user_uuid, Match.user2_id == target_uuid),
                    and_(Match.user1_id == target_uuid, Match.user2_id == user_uuid)
                )
            )
        )
        match_obj = match_res.scalars().first()
        if not match_obj:
            match_obj = Match(
                user1_id=user_uuid,
                user2_id=target_uuid,
                mutual_message_count=1
            )
            db.add(match_obj)
            await db.flush()
        else:
            match_obj.mutual_message_count = (match_obj.mutual_message_count or 0) + 1

        match_id_str = str(match_obj.id)
        register_conversation_participants(match_id_str, current_user_id, payload.target_user_id)
        chat_msg = ChatMessage(
            id=msg_id,
            match_id=match_obj.id,
            sender_id=user_uuid,
            content=payload.message.strip(),
            media_type="text",
            status="sent",
        )
        db.add(chat_msg)
        await db.commit()
        await db.refresh(chat_msg)

        if target_user:
            target_fcm = getattr(target_user, 'fcm_token', None)
            if target_fcm:
                try:
                    await send_push_notification(
                        fcm_token=target_fcm,
                        title=f"⚡ New Direct Message from {sender_name}",
                        body=payload.message[:100],
                        data={
                            "type": "direct_dm",
                            "match_id": match_id_str,
                            "sender_id": str(user_uuid),
                        }
                    )
                except Exception:
                    pass
    except Exception:
        pass

    return APIResponse(
        success=True,
        data=DirectDMData(
            match_id=match_id_str,
            target_user_id=str(target_uuid),
            message_id=str(msg_id),
            content=payload.message.strip(),
            created_at=now_utc.isoformat(),
            message="Direct DM sent successfully!"
        )
    )
