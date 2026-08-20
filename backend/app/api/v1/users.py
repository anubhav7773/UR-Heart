import uuid
import httpx

from fastapi import APIRouter, Body, Depends, HTTPException, status
from sqlalchemy import select, delete, text, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_current_user_id
from app.core.rate_limiter import rate_limit
from app.models.orm import (
    User,
    UserPhoto,
    Match,
    ChatMessage,
    Swipe,
    ProfileImpression,
    BlockedUser,
    UserReport,
    ChaiInvite,
    ChaiStatus,
    UserAdCounter,
    SachetTransaction,
)
from app.models.schemas import APIResponse

router = APIRouter(prefix="/users", tags=["User Location & Account Management"])


@router.delete("/me", response_model=APIResponse[dict])
@router.delete("/me/", response_model=APIResponse[dict])
async def delete_current_user_account(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Production-ready cascade account deletion:
    1. Removes all user uploaded assets from Supabase Storage bucket 'profile-photos' using SUPABASE_SERVICE_ROLE_KEY.
    2. Deletes or cascade removes all related DB records:
       - user_photos
       - matches (where user is user1 or user2)
       - chat_messages (sender or match messages)
       - swipes (swiper or swiped)
       - profile_impressions (visitor or target)
       - blocked_users & user_reports
       - chai_invites & chai_status
       - user_ad_counters & sachet_transactions
       - public.users row
    3. Deletes user from Supabase Auth & Firebase Auth.
    4. Returns success confirmation.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID format.")

    # 1. Fetch user & associated photos to delete from storage
    user_stmt = select(User).where(User.id == user_uuid)
    user_res = await db.execute(user_stmt)
    user = user_res.scalars().first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    photos_stmt = select(UserPhoto).where(UserPhoto.user_id == user_uuid)
    photos_res = await db.execute(photos_stmt)
    user_photos = photos_res.scalars().all()

    photo_paths = []
    for p in user_photos:
        if p.photo_url:
            if "profile-photos/" in p.photo_url:
                photo_paths.append(p.photo_url.split("profile-photos/")[-1].split("?")[0])
            else:
                photo_paths.append(p.photo_url.split("/")[-1].split("?")[0])

    if getattr(user, "photo_url", None) and user.photo_url:
        if "profile-photos/" in user.photo_url:
            photo_paths.append(user.photo_url.split("profile-photos/")[-1].split("?")[0])
        else:
            photo_paths.append(user.photo_url.split("/")[-1].split("?")[0])

    if getattr(user, "verification_video_url", None) and user.verification_video_url:
        if "profile-photos/" in user.verification_video_url:
            photo_paths.append(user.verification_video_url.split("profile-photos/")[-1].split("?")[0])

    photo_paths = list(set(filter(None, photo_paths)))

    # 2. Delete all uploaded assets from Supabase Storage
    try:
        supa_url = (settings.SUPABASE_URL or "").rstrip("/")
        supa_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY
        if supa_url and supa_key and photo_paths:
            try:
                from supabase import create_client
                supa_client = create_client(supa_url, supa_key)
                supa_client.storage.from_("profile-photos").remove(photo_paths)
            except Exception:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.request(
                        "DELETE",
                        f"{supa_url}/storage/v1/object/profile-photos",
                        headers={"Authorization": f"Bearer {supa_key}", "apikey": supa_key, "Content-Type": "application/json"},
                        json={"prefixes": photo_paths}
                    )
    except Exception as e:
        print(f"[ACCOUNT_DELETE STORAGE NOTICE] {e}")

    # 3. Database Cascade Cleanup
    try:
        # Chat messages
        matches_subquery = select(Match.id).where(or_(Match.user1_id == user_uuid, Match.user2_id == user_uuid))
        await db.execute(delete(ChatMessage).where(or_(ChatMessage.sender_id == user_uuid, ChatMessage.match_id.in_(matches_subquery))))

        # Matches
        await db.execute(delete(Match).where(or_(Match.user1_id == user_uuid, Match.user2_id == user_uuid)))

        # Swipes & Profile Impressions
        await db.execute(delete(Swipe).where(or_(Swipe.swiper_id == user_uuid, Swipe.swiped_id == user_uuid)))
        await db.execute(delete(ProfileImpression).where(or_(ProfileImpression.visitor_id == user_uuid, ProfileImpression.target_id == user_uuid)))

        # Safety & Reports
        await db.execute(delete(BlockedUser).where(or_(BlockedUser.blocker_id == user_uuid, BlockedUser.blocked_id == user_uuid)))
        await db.execute(delete(UserReport).where(or_(UserReport.reporter_id == user_uuid, UserReport.reported_id == user_uuid)))

        # Chai invites & status
        await db.execute(delete(ChaiInvite).where(or_(ChaiInvite.sender_id == user_uuid, ChaiInvite.receiver_id == user_uuid)))
        await db.execute(delete(ChaiStatus).where(ChaiStatus.user_id == user_uuid))

        # Ad counters & transactions
        await db.execute(delete(UserAdCounter).where(UserAdCounter.user_id == user_uuid))
        await db.execute(delete(SachetTransaction).where(SachetTransaction.user_id == user_uuid))

        # User photos
        await db.execute(delete(UserPhoto).where(UserPhoto.user_id == user_uuid))

        # User master record
        await db.execute(delete(User).where(User.id == user_uuid))

        await db.commit()
    except Exception as e:
        await db.rollback()
        print(f"[ACCOUNT_DELETE DB ERROR] {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to cascade delete user records.")

    # 4. Supabase Auth & Firebase Auth Cleanup
    try:
        if settings.SUPABASE_URL and (settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY):
            from supabase import create_client
            supa_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY
            supa_admin = create_client(settings.SUPABASE_URL, supa_key)
            supa_admin.auth.admin.delete_user(str(user_uuid))
    except Exception as e:
        print(f"[ACCOUNT_DELETE SUPABASE AUTH NOTICE] {e}")

    try:
        import firebase_admin.auth as fb_auth
        fb_auth.delete_user(str(user_uuid))
    except Exception:
        pass

    return APIResponse(
        success=True,
        message="Account successfully deleted",
        data={"deleted_user_id": str(user_uuid)}
    )



@router.post("/fcm-token")
@router.post("/fcm-token/")
@router.put("/fcm-token")
@router.put("/fcm-token/")
async def update_fcm_token(
    payload: dict = Body(...),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    token = payload.get("fcm_token") or payload.get("token")
    if not token or not isinstance(token, str) or len(token.strip()) < 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid FCM token payload.")

    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID.")

    try:
        stmt = select(User).where(User.id == user_uuid)
        res = await db.execute(stmt)
        user = res.scalars().first()
        if user:
            user.fcm_token = token.strip()
            await db.commit()
    except Exception as e:
        await db.rollback()
        print(f"[FCM_SAVE] ERROR saving FCM token for user {current_user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save FCM token.")

    return APIResponse(success=True, message="FCM token updated successfully.", data={"fcm_token": token})


@router.post(
    "/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.post(
    "/location/",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.put(
    "/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.put(
    "/location/",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
async def update_user_location(
    payload: dict,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Persist the authenticated device's latest live GPS coordinates."""
    lat = payload.get("latitude", payload.get("lat"))
    lng = payload.get("longitude", payload.get("lng"))
    if lat is None or lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="latitude and longitude are required.",
        )

    try:
        latitude, longitude = float(lat), float(lng)
        if not -90.0 <= latitude <= 90.0 or not -180.0 <= longitude <= 180.0:
            raise ValueError("Coordinates are outside valid GPS bounds.")
        user_id = uuid.UUID(current_user_id)
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalars().first()
        if user is None:
            from app.models.orm import GenderEnum as ORMGenderEnum, IntentEnum as ORMIntentEnum
            user = User(
                id=user_id,
                full_name="User",
                dob=date(2000, 1, 1),
                gender=ORMGenderEnum.male,
                interested_in=ORMGenderEnum.female,
                intent=ORMIntentEnum.casual,
                latitude=latitude,
                longitude=longitude,
                is_active=True,
            )
            db.add(user)
            await db.flush()
        else:
            user.latitude = latitude
            user.longitude = longitude
        try:
            await db.execute(
                text("UPDATE users SET location_geom = ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) WHERE id = :uid"),
                {"lng": longitude, "lat": latitude, "uid": user_id}
            )
        except Exception:
            pass
        await db.commit()
    except HTTPException:
        raise
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid GPS coordinates.")
    except Exception as e:
        await db.rollback()
        print(f"[LOCATION UPDATE ERROR] {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save GPS location.")

    return APIResponse(
        success=True,
        message="Device GPS location updated successfully.",
        data={"latitude": latitude, "longitude": longitude},
    )


def _serialize_user_profile(user: User) -> dict:
    from datetime import date
    today = date.today()
    age = today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day)) if user.dob else None
    photos = [p.photo_url for p in user.photos] if user.photos else ([user.photo_url] if getattr(user, 'photo_url', None) else [])
    is_approved = bool(user.is_verified and getattr(user, 'verification_status', None) and user.verification_status.value == "APPROVED")
    return {
        "id": str(user.id),
        "user_id": str(user.id),
        "full_name": user.full_name or "UR Heart User",
        "first_name": (user.full_name or "User").split()[0],
        "age": age,
        "bio": user.bio or "",
        "area_name": user.area_name or "Ayodhya",
        "gender": user.gender.value if user.gender else "male",
        "intent": user.intent.value if user.intent else "casual",
        "photos": photos,
        "photo_url": photos[0] if photos else None,
        "is_verified": is_approved,
        "is_admin": bool(getattr(user, "is_admin", False)),
    }


@router.get("/activity")
@router.get("/activity/")
async def get_user_activity(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns authenticated user's activity breakdown:
    - Matches (mutual likes/matches)
    - Liked (right swiped users awaiting response)
    - Disliked (left swiped users)
    """
    from sqlalchemy import or_, and_
    from sqlalchemy.orm import selectinload
    from app.models.orm import Match, Swipe, SwipeActionEnum

    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID format.")

    # 1. Fetch Mutual Matches
    match_stmt = (
        select(Match)
        .where(or_(Match.user1_id == user_uuid, Match.user2_id == user_uuid))
        .order_by(Match.created_at.desc())
    )
    match_res = await db.execute(match_stmt)
    matches_list = match_res.scalars().all()

    matched_user_ids = set()
    matches_data = []

    for m in matches_list:
        other_id = m.user2_id if m.user1_id == user_uuid else m.user1_id
        matched_user_ids.add(other_id)

        other_user_res = await db.execute(
            select(User).options(selectinload(User.photos)).where(User.id == other_id)
        )
        other_user = other_user_res.scalars().first()
        if other_user:
            matches_data.append({
                "match_id": str(m.id),
                "user": _serialize_user_profile(other_user),
                "created_at": m.created_at.isoformat() if m.created_at else "",
            })

    # 2. Fetch Swipes (Liked & Disliked)
    swipe_stmt = (
        select(Swipe)
        .where(Swipe.swiper_id == user_uuid)
        .order_by(Swipe.created_at.desc())
    )
    swipe_res = await db.execute(swipe_stmt)
    swipes_list = swipe_res.scalars().all()

    liked_data = []
    disliked_data = []

    for s in swipes_list:
        target_res = await db.execute(
            select(User).options(selectinload(User.photos)).where(User.id == s.swiped_id)
        )
        target_user = target_res.scalars().first()
        if not target_user:
            continue

        serialized = _serialize_user_profile(target_user)
        created_str = s.created_at.isoformat() if s.created_at else ""

        if s.action in (SwipeActionEnum.like, SwipeActionEnum.dm):
            # If already in mutual match, skip or mark
            if s.swiped_id not in matched_user_ids:
                liked_data.append({
                    "user": serialized,
                    "created_at": created_str,
                })
        elif s.action == SwipeActionEnum.reject:
            disliked_data.append({
                "user": serialized,
                "created_at": created_str,
            })

    return APIResponse(
        success=True,
        message="User activity retrieved successfully.",
        data={
            "matches": matches_data,
            "liked": liked_data,
            "disliked": disliked_data,
        }
    )

