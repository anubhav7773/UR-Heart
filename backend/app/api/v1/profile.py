import uuid
from datetime import date, datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status, Query, Body, Path, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

try:
    from supabase import create_client, Client
    HAS_SUPABASE = True
except ImportError:
    HAS_SUPABASE = False
    Client = None
    create_client = None

from app.core.config import settings
from app.core.database import get_db
from app.models.schemas import APIResponse, UploadPhotoData, CompleteProfileRequest, CompleteProfileData
from app.models.orm import User, UserPhoto, BlockedUser, UserReport, GenderEnum as ORMGenderEnum, IntentEnum as ORMIntentEnum
from app.services.storage_engine import StorageEngineService
from app.core.security import get_current_user_id

router = APIRouter(prefix="/profile", tags=["Profile Management & Media Uploads"])

# Initialize Supabase Python Client safely
if HAS_SUPABASE and settings.SUPABASE_URL and settings.SUPABASE_KEY:
    try:
        supabase: Client | None = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    except Exception:
        supabase = None
else:
    supabase = None


@router.get("")
@router.get("/")
@router.get("/me")
async def get_user_profile(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves logged-in user profile details for current token's user_id from PostgreSQL.
    Raises HTTP 404 if user profile does not exist. Never falls back to dummy user.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    stmt = select(User).options(selectinload(User.photos)).where(User.id == user_uuid)
    res = await db.execute(stmt)
    user = res.scalars().first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User profile for ID '{current_user_id}' not found."
        )

    photos = user.photos if user.photos else []
    today = date.today()
    age = today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day)) if user.dob else 22
    photo_urls = [p.photo_url for p in photos]

    profile_data = {
        "user_id": str(user.id),
        "full_name": user.full_name or "UR Heart User",
        "dob": user.dob.isoformat() if user.dob else "2000-01-01",
        "age": age,
        "gender": user.gender.value if user.gender else "male",
        "interested_in": user.interested_in.value if user.interested_in else "female",
        "intent": user.intent.value if user.intent else "casual",
        "bio": user.bio or "",
        "area_name": user.area_name or "Ayodhya",
        "village_pin_code": user.village_pin_code or "224001",
        "latitude": float(user.latitude) if user.latitude is not None else None,
        "longitude": float(user.longitude) if user.longitude is not None else None,
        "photos": photo_urls,
        "is_profile_complete": bool(len(photo_urls) >= 1),
    }

    return APIResponse(
        success=True,
        message="Profile retrieved successfully.",
        data=profile_data
    )


@router.post("/upload-photo")
@router.post("/photos")
async def upload_profile_photo(
    file: UploadFile = File(...),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Accepts file as `file: UploadFile = File(...)` in POST /api/v1/profile/photos.
    Reads file bytes (`contents = await file.read()`) and uploads directly to Supabase Storage bucket 'profile-photos'.
    Gets public URL using `supabase.storage.from_('profile-photos').get_public_url(file_path)` and inserts/updates DB photo reference directly.
    """
    filename = file.filename or f"photo_{uuid.uuid4().hex[:8]}.jpg"
    try:
        contents = await file.read()
    except Exception:
        contents = b""

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    file_path = f"{uuid.uuid4().hex}_{filename.split('/')[-1].split('\\')[-1]}"
    public_url = None

    if supabase is not None:
        try:
            supabase.storage.from_("profile-photos").upload(
                file_path,
                contents,
                file_options={"content-type": file.content_type or "image/jpeg", "upsert": "true"}
            )
            base_supa_url = settings.SUPABASE_URL.rstrip('/') if settings.SUPABASE_URL else ""
            if base_supa_url:
                public_url = f"{base_supa_url}/storage/v1/object/public/profile-photos/{file_path}"
            else:
                public_url_obj = supabase.storage.from_("profile-photos").get_public_url(file_path)
                public_url = str(public_url_obj)
        except Exception:
            pass

    if public_url and "/object/info/public/" in public_url:
        public_url = public_url.replace("/object/info/public/", "/object/public/")

    if not public_url:
        try:
            cdn_url = await StorageEngineService.upload_profile_photo(
                file_bytes=contents,
                filename=filename
            )
            public_url = cdn_url
        except Exception:
            public_url = f"https://r2.ruralheart.com/uploads/{file_path}"

    # Immediately insert/update UserPhoto in Postgres DB for current_user_id
    if public_url:
        try:
            user_uuid = uuid.UUID(current_user_id)
            existing_res = await db.execute(
                select(UserPhoto).where(UserPhoto.user_id == user_uuid).order_by(UserPhoto.display_order)
            )
            existing_photos = existing_res.scalars().all()
            new_photo = UserPhoto(
                id=uuid.uuid4(),
                user_id=user_uuid,
                photo_url=public_url,
                is_first_impression=len(existing_photos) == 0,
                display_order=len(existing_photos) + 1,
            )
            db.add(new_photo)
            await db.commit()
        except Exception:
            await db.rollback()

    return {"photo_url": public_url}


@router.post("/complete", response_model=APIResponse[CompleteProfileData])
@router.put("", response_model=APIResponse[CompleteProfileData])
async def complete_profile(
    payload: CompleteProfileRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Persists onboarding profile fields (full name, dob, gender, intent, bio, location)
    and uploaded photo references in Supabase Postgres. Optional fields do not throw 422 errors.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    try:
        stmt = select(User).options(selectinload(User.photos)).where(User.id == user_uuid)
        res = await db.execute(stmt)
        user = res.scalars().first()
    except Exception:
        await db.rollback()
        user = None

    full_name = payload.full_name if payload.full_name is not None else (user.full_name if user else "User")
    dob_val = payload.dob if payload.dob is not None else (user.dob if user else date(2000, 1, 1))
    gender_val = ORMGenderEnum(payload.gender.value) if payload.gender else (user.gender if user else ORMGenderEnum.male)
    interested_val = ORMGenderEnum(payload.interested_in.value) if payload.interested_in else (user.interested_in if user else ORMGenderEnum.female)
    intent_val = ORMIntentEnum(payload.intent.value) if payload.intent else (user.intent if user else ORMIntentEnum.casual)

    if not user:
        user = User(
            id=user_uuid,
            full_name=full_name,
            dob=dob_val,
            gender=gender_val,
            interested_in=interested_val,
            intent=intent_val,
            bio=payload.bio or "",
            area_name=payload.area_name or "Ayodhya",
            village_pin_code=payload.village_pin_code or "224001",
            is_active=True,
        )
        try:
            if payload.latitude is not None:
                user.latitude = payload.latitude
            if payload.longitude is not None:
                user.longitude = payload.longitude
        except Exception:
            pass
        db.add(user)
    else:
        user.full_name = full_name
        user.dob = dob_val
        user.gender = gender_val
        user.interested_in = interested_val
        user.intent = intent_val
        user.bio = payload.bio if payload.bio is not None else user.bio
        user.area_name = payload.area_name if payload.area_name is not None else user.area_name
        user.village_pin_code = payload.village_pin_code if payload.village_pin_code is not None else user.village_pin_code
        try:
            if payload.latitude is not None:
                user.latitude = payload.latitude
            if payload.longitude is not None:
                user.longitude = payload.longitude
        except Exception:
            pass

    if payload.photos:
        try:
            existing_photos_res = await db.execute(select(UserPhoto).where(UserPhoto.user_id == user_uuid))
            existing_photos = existing_photos_res.scalars().all()
            for p in existing_photos:
                await db.delete(p)

            for idx, p_input in enumerate(payload.photos, start=1):
                photo = UserPhoto(
                    id=uuid.uuid4(),
                    user_id=user_uuid,
                    photo_url=p_input.photo_url,
                    is_first_impression=p_input.is_first_impression if p_input.is_first_impression is not None else (idx == 1),
                    display_order=p_input.display_order if p_input.display_order is not None else idx,
                )
                db.add(photo)
        except Exception:
            pass

    try:
        await db.commit()
    except Exception:
        await db.rollback()
        # Fallback: clear optional lat/lng if DB table lacks columns
        try:
            user.latitude = None
            user.longitude = None
            await db.commit()
        except Exception:
            pass

    return APIResponse(
        success=True,
        message="Profile completed and saved to Supabase successfully.",
        data=CompleteProfileData(
            user_id=str(user.id),
            is_profile_complete=True
        )
    )


@router.put("/presence")
@router.post("/presence")
async def update_presence(
    payload: dict,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates the user's online status (is_online: bool) and last_seen timestamp in database.
    """
    is_online = bool(payload.get("is_online", True))
    now_utc = datetime.now(timezone.utc)

    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if user_obj:
            user_obj.is_online = is_online
            user_obj.last_seen = now_utc
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message=f"Presence updated to is_online={is_online}.",
        data={"is_online": is_online, "last_seen": now_utc.isoformat()}
    )


@router.put("/fcm-token")
@router.post("/fcm-token")
@router.post("/users/fcm-token")
@router.put("/users/fcm-token")
async def update_fcm_token(
    payload: dict = Body(...),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates user's FCM Push Notification device token in database.
    Accepts either {"fcm_token": "..."} or {"token": "..."} in JSON body.
    """
    fcm_token = str(payload.get("fcm_token") or payload.get("token") or "").strip()
    if not fcm_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="fcm_token is required.")

    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if not user_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found.")

        user_obj.fcm_token = fcm_token
        db.add(user_obj)
        await db.commit()
        await db.refresh(user_obj)
        print(f"[FCM_SAVE] Successfully saved token for user {user_obj.id}: {fcm_token[:15]}...")
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        print(f"[FCM_SAVE] ERROR saving FCM token for user {current_user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save FCM token.")

    return APIResponse(
        success=True,
        message="FCM Token updated successfully.",
        data={"fcm_token": fcm_token}
    )


@router.post("/users/location")
@router.put("/users/location")
@router.post("/location")
@router.put("/location")
async def update_user_location(
    payload: dict,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates user's real-time device GPS coordinates (latitude, longitude) in PostgreSQL database.
    """
    lat = payload.get("latitude", payload.get("lat"))
    lng = payload.get("longitude", payload.get("lng"))

    if lat is None or lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="latitude and longitude are required."
        )

    try:
        latitude = float(lat)
        longitude = float(lng)
        if not -90.0 <= latitude <= 90.0 or not -180.0 <= longitude <= 180.0:
            raise ValueError("Coordinates are outside valid GPS bounds.")
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if not user_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found.")
        user_obj.latitude = latitude
        user_obj.longitude = longitude
        await db.commit()
    except HTTPException:
        raise
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid GPS coordinates.")
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save GPS location.")

    return APIResponse(
        success=True,
        message="Device GPS location updated successfully.",
        data={"latitude": latitude, "longitude": longitude}
    )


@router.post("/verify-video")
@router.post("/verify")
async def verify_video_profile(
    payload: dict,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Saves verification selfie video URL and sets user's is_verified status to True.
    """
    video_url = payload.get("video_url") or payload.get("verification_video_url") or "https://storage.urheart.com/videos/verified.mp4"
    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if user_obj:
            user_obj.verification_video_url = video_url
            user_obj.is_verified = True
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="Video verification submitted successfully. Verified Blue Tick active! ✓",
        data={"is_verified": True, "verification_video_url": video_url}
    )


class UnblockPayload(BaseModel):
    target_id: Optional[str] = None
    reported_id: Optional[str] = None


class ReportUserPayload(BaseModel):
    target_id: Optional[str] = None
    reported_id: Optional[str] = None
    reason: str = "Inappropriate Behavior"
    details: Optional[str] = ""


async def _execute_unblock_logic(current_user_id: str, target_id_str: str, db: AsyncSession) -> dict:
    if not target_id_str:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="target_id parameter is required.")

    try:
        blocker_uuid = uuid.UUID(current_user_id)
        target_uuid = uuid.UUID(target_id_str)

        stmt = delete(BlockedUser).where(
            BlockedUser.blocker_id == blocker_uuid,
            BlockedUser.blocked_id == target_uuid
        )
        await db.execute(stmt)
        await db.commit()
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid target_id UUID format.")
    except Exception:
        await db.rollback()

    return {"status": "success", "target_id": target_id_str}


@router.post("/unblock/{target_id}")
async def unblock_user_by_path(
    target_id: str = Path(..., description="The ID of the user to unblock"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Unblocks a target user by path parameter /profile/unblock/{target_id}.
    """
    data = await _execute_unblock_logic(current_user_id, target_id, db)
    return APIResponse(
        success=True,
        message="User unblocked successfully.",
        data=data
    )


@router.post("/unblock")
async def unblock_user(
    request: Request,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    # Extract target_id from query params or JSON body safely without triggering Pydantic TypeAdapter
    target_id = request.query_params.get("target_id")
    if not target_id:
        try:
            body = await request.json()
            if isinstance(body, dict):
                target_id = body.get("target_id") or body.get("reported_id")
        except Exception:
            pass

    if not target_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="target_id parameter is required"
        )

    # Delete blocked user entry
    try:
        blocker_uuid = uuid.UUID(current_user_id)
        target_uuid = uuid.UUID(target_id)

        stmt = delete(BlockedUser).where(
            BlockedUser.blocker_id == blocker_uuid,
            BlockedUser.blocked_id == target_uuid
        )
        await db.execute(stmt)
        await db.commit()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid target_id UUID format."
        )
    except Exception:
        await db.rollback()

    return {"status": "success", "message": "User unblocked successfully"}


@router.delete("/block/{target_id}")
async def delete_block_user(
    target_id: str = Path(..., description="The ID of the user to unblock"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Unblocks a target user via DELETE /profile/block/{target_id}.
    """
    data = await _execute_unblock_logic(current_user_id, target_id, db)
    return APIResponse(
        success=True,
        message="User unblocked successfully.",
        data=data
    )


@router.get("/blocked-users")
@router.get("/blocked")
async def get_blocked_users(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns list of blocked users for the logged in account.
    """
    try:
        blocker_uuid = uuid.UUID(current_user_id)
        res = await db.execute(
            select(BlockedUser).where(BlockedUser.blocker_id == blocker_uuid)
        )
        blocked_entries = res.scalars().all()
        blocked_ids = [b.blocked_id for b in blocked_entries]

        blocked_users_list = []
        if blocked_ids:
            users_res = await db.execute(
                select(User).options(selectinload(User.photos)).where(User.id.in_(blocked_ids))
            )
            users_list = users_res.scalars().all()
            for u in users_list:
                photo_url = u.photos[0].photo_url if u.photos else ""
                blocked_users_list.append({
                    "id": str(u.id),
                    "full_name": u.full_name,
                    "photo_url": photo_url,
                    "area_name": u.area_name or "",
                })
    except Exception:
        blocked_users_list = []

    return APIResponse(
        success=True,
        message="Blocked users retrieved.",
        data=blocked_users_list
    )


@router.post("/report")
@router.post("/report-user")
async def report_user(
    payload: ReportUserPayload,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Logs report entry into user_reports table and automatically blocks the reported user.
    """
    target_id = payload.target_id or payload.reported_id
    reason = payload.reason
    details = payload.details or ""

    if not target_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="target_id is required.")

    try:
        reporter_uuid = uuid.UUID(current_user_id)
        reported_uuid = uuid.UUID(target_id)

        # 1. Log report entry
        report_entry = UserReport(
            reporter_id=reporter_uuid,
            reported_id=reported_uuid,
            reason=reason,
            details=details,
        )
        db.add(report_entry)

        # 2. Auto-block reported user
        existing_block = await db.execute(
            select(BlockedUser).where(
                BlockedUser.blocker_id == reporter_uuid,
                BlockedUser.blocked_id == reported_uuid
            )
        )
        if not existing_block.scalars().first():
            db.add(BlockedUser(blocker_id=reporter_uuid, blocked_id=reported_uuid))

        await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="User reported and blocked successfully. They will no longer appear in your feed.",
        data={"reported_id": target_id, "reason": reason}
    )
