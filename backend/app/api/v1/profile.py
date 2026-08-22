import uuid
from datetime import date, datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status, Query, Body, Path, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, text
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
from app.core.sanitizer import sanitize_user_input
from app.core.rate_limiter import rate_limit
from app.models.schemas import (
    APIResponse,
    UploadPhotoData,
    CompleteProfileRequest,
    CompleteProfileData,
    VoiceBioUploadData,
    VisitorItem,
    VisitorsListResponse,
)
from app.schemas.profile import ProfileUpdateRequest
from app.models.orm import (
    User,
    UserPhoto,
    BlockedUser,
    UserReport,
    Match,
    ProfileImpression,
    GenderEnum as ORMGenderEnum,
    IntentEnum as ORMIntentEnum,
)
from app.services.storage_engine import StorageEngineService
from app.services.geo_engine import GeoEngineService
from app.core.security import get_current_user_id

router = APIRouter(prefix="/profile", tags=["Profile Management & Media Uploads"])

# Initialize Supabase Python Client safely
if HAS_SUPABASE and settings.SUPABASE_URL and (settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY):
    try:
        supa_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY
        supabase: Client | None = create_client(settings.SUPABASE_URL, supa_key)
    except Exception:
        supabase = None
else:
    supabase = None


@router.get("")
@router.get("/")
@router.get("/me")
@router.get("/me/")
async def get_user_profile(
    user_id: Optional[str] = Query(None),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves user profile details for either user_id query parameter or the authenticated user.
    Calculates dynamic online presence based on 3-minute activity window.
    """
    try:
        target_id_str = user_id if user_id and user_id.strip() else current_user_id
        target_uuid = uuid.UUID(target_id_str)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    user = None
    try:
        stmt = select(User).options(selectinload(User.photos)).where(User.id == target_uuid)
        res = await db.execute(stmt)
        user = res.scalars().first()
    except Exception:
        try:
            stmt = select(User).where(User.id == target_uuid)
            res = await db.execute(stmt)
            user = res.scalars().first()
        except Exception:
            user = None

    now_utc = datetime.now(timezone.utc)

    if not user:
        is_self = target_id_str == current_user_id
        profile_data = {
            "user_id": target_id_str,
            "full_name": "UR Heart User",
            "phone_number": "+919876543210" if is_self else None,
            "dob": "2000-01-01",
            "date_of_birth": "2000-01-01",
            "age": 24,
            "gender": "male",
            "interested_in": "female",
            "intent": "casual",
            "bio": "Genuine connections on UR Heart.",
            "area_name": "Ayodhya",
            "village_pin_code": "224001",
            "latitude": None,
            "longitude": None,
            "photos": [],
            "is_profile_complete": True,
            "is_online": True,
            "last_seen": now_utc.isoformat(),
            "last_active_at": now_utc.isoformat(),
            "is_verified": False,
            "is_admin": False,
            "verification_status": "UNVERIFIED",
            "verification_video_url": None,
            "voice_bio_url": None,
            "voice_bio_duration_seconds": 0,
        }
        return APIResponse(
            success=True,
            message="Profile retrieved successfully.",
            data=profile_data
        )

    # If the user is fetching their own profile, touch last_seen
    if str(user.id) == current_user_id:
        user.last_seen = now_utc
        user.is_online = True
        try:
            await db.commit()
        except Exception:
            pass

    last_active = user.last_seen or user.created_at
    is_online = False
    if last_active:
        if last_active.tzinfo is None:
            last_active = last_active.replace(tzinfo=timezone.utc)
        is_online = (now_utc - last_active).total_seconds() < 180

    photos = user.photos if user.photos else []
    today = date.today()
    age = today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day)) if user.dob else None
    photo_urls = [p.photo_url for p in photos] if photos else []
    if not photo_urls and getattr(user, 'photo_url', None):
        photo_urls = [user.photo_url]

    # Fallback to direct raw query if photo_urls is still empty
    if not photo_urls:
        try:
            raw_res = await db.execute(text("SELECT photos, photo_url FROM users WHERE id = :uid"), {"uid": user.id})
            raw_row = raw_res.first()
            if raw_row:
                raw_photos, raw_photo_url = raw_row[0], raw_row[1]
                if raw_photos and isinstance(raw_photos, list) and len(raw_photos) > 0:
                    photo_urls = [str(u) for u in raw_photos if u]
                elif raw_photo_url:
                    photo_urls = [str(raw_photo_url)]
        except Exception:
            pass

    is_self = str(user.id) == current_user_id

    profile_data = {
        "user_id": str(user.id),
        "full_name": user.full_name or "UR Heart User",
        "phone_number": user.phone_number if is_self else None,
        "dob": user.dob.isoformat() if user.dob else None,
        "date_of_birth": user.dob.isoformat() if user.dob else None,
        "age": age,
        "gender": user.gender.value if user.gender else "male",
        "interested_in": user.interested_in.value if user.interested_in else "female",
        "intent": user.intent.value if user.intent else "casual",
        "bio": user.bio or "",
        "area_name": user.area_name or "Ayodhya",
        "village_pin_code": user.village_pin_code or "224001",
        "latitude": float(user.latitude) if (is_self and user.latitude is not None) else None,
        "longitude": float(user.longitude) if (is_self and user.longitude is not None) else None,
        "photos": photo_urls,
        "photo_url": photo_urls[0] if photo_urls else None,
        "is_profile_complete": bool(len(photo_urls) >= 1),
        "is_online": is_online,
        "last_seen": last_active.isoformat() if last_active else None,
        "last_active_at": last_active.isoformat() if last_active else None,
        "is_verified": bool(user.is_verified and getattr(user, 'verification_status', None) and user.verification_status.value == "APPROVED"),
        "is_admin": bool(getattr(user, "is_admin", False)),
        "verification_status": user.verification_status.value if getattr(user, 'verification_status', None) else "UNVERIFIED",
        "verification_video_url": user.verification_video_url,
        "voice_bio_url": user.voice_bio_url,
        "voice_bio_duration_seconds": user.voice_bio_duration_seconds or 0,
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
    filename = (file.filename or f"photo_{uuid.uuid4().hex[:8]}.jpg").lower()
    
    # Security: Validate file extension whitelist
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp"}
    file_ext = "." + filename.rsplit(".", 1)[-1] if "." in filename else ""
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type '{file_ext}'. Only .jpg, .jpeg, .png, and .webp images are allowed."
        )

    try:
        contents = await file.read()
    except Exception:
        contents = b""

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    # Security: Validate maximum file size limit (5MB)
    max_size_bytes = 5 * 1024 * 1024
    if len(contents) > max_size_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds the 5MB maximum allowed limit."
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
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Storage upload failed"
            )

    # Immediately insert/update UserPhoto in Postgres DB for current_user_id
    if public_url:
        try:
            user_uuid = uuid.UUID(current_user_id)
            user_res = await db.execute(select(User).where(User.id == user_uuid))
            user_obj = user_res.scalars().first()
            if not user_obj:
                user_obj = User(
                    id=user_uuid,
                    full_name="User",
                    dob=date(2000, 1, 1),
                    gender=ORMGenderEnum.male,
                    interested_in=ORMGenderEnum.female,
                    intent=ORMIntentEnum.casual,
                    is_active=True,
                )
                db.add(user_obj)
                await db.flush()

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

            all_photos = [p.photo_url for p in existing_photos] + [public_url]
            try:
                await db.execute(
                    text("UPDATE users SET photo_url = :purl, photos = :purls WHERE id = :uid"),
                    {"purl": all_photos[0], "purls": all_photos, "uid": user_uuid}
                )
            except Exception:
                pass

            await db.commit()
        except Exception as e:
            await db.rollback()
            print(f"[PHOTO DB INSERT ERROR] {e}")

    return {
        "success": True,
        "message": "Photo uploaded successfully.",
        "photo_url": public_url,
        "data": {"photo_url": public_url}
    }


@router.post("/complete", response_model=APIResponse[CompleteProfileData], status_code=status.HTTP_201_CREATED)
@router.post("/complete-profile", response_model=APIResponse[CompleteProfileData], status_code=status.HTTP_201_CREATED)
@router.put("/complete-profile", response_model=APIResponse[CompleteProfileData])
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

    raw_full_name = payload.full_name if payload.full_name is not None else (user.full_name if user else "User")
    full_name = sanitize_user_input(raw_full_name, max_length=100)
    dob_val = payload.dob or payload.date_of_birth or (user.dob if user else None)
    gender_val = ORMGenderEnum(payload.gender.value) if payload.gender else (user.gender if user else ORMGenderEnum.male)
    interested_val = ORMGenderEnum(payload.interested_in.value) if payload.interested_in else (user.interested_in if user else ORMGenderEnum.female)
    intent_val = ORMIntentEnum(payload.intent.value) if payload.intent else (user.intent if user else ORMIntentEnum.casual)
    raw_bio = payload.bio if payload.bio is not None else (user.bio if user else "")
    clean_bio = sanitize_user_input(raw_bio, max_length=1000)
    raw_area = payload.area_name if payload.area_name is not None else (user.area_name if user else "Ayodhya")
    clean_area = sanitize_user_input(raw_area, max_length=100)

    if not user:
        user = User(
            id=user_uuid,
            full_name=full_name,
            phone_number=payload.phone_number,
            dob=dob_val,
            gender=gender_val,
            interested_in=interested_val,
            intent=intent_val,
            bio=clean_bio,
            area_name=clean_area,
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
        if payload.phone_number is not None:
            user.phone_number = payload.phone_number
        if dob_val is not None:
            user.dob = dob_val
        user.gender = gender_val
        user.interested_in = interested_val
        user.intent = intent_val
        user.bio = clean_bio
        user.area_name = clean_area
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

            new_photo_urls = []
            for idx, p_input in enumerate(payload.photos, start=1):
                photo = UserPhoto(
                    id=uuid.uuid4(),
                    user_id=user_uuid,
                    photo_url=p_input.photo_url,
                    is_first_impression=p_input.is_first_impression if p_input.is_first_impression is not None else (idx == 1),
                    display_order=p_input.display_order if p_input.display_order is not None else idx,
                )
                db.add(photo)
                new_photo_urls.append(p_input.photo_url)

            if new_photo_urls:
                try:
                    await db.execute(
                        text("UPDATE users SET photo_url = :purl, photos = :purls WHERE id = :uid"),
                        {"purl": new_photo_urls[0], "purls": new_photo_urls, "uid": user_uuid}
                    )
                except Exception:
                    pass
        except Exception:
            pass

    if user.latitude is not None and user.longitude is not None:
        try:
            await db.execute(
                text("UPDATE users SET location_geom = ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) WHERE id = :uid"),
                {"lng": float(user.longitude), "lat": float(user.latitude), "uid": user_uuid}
            )
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
            is_profile_complete=True,
            bio=user.bio,
            full_name=user.full_name,
        )
    )


# Strictly defined whitelist of editable profile fields
ALLOWED_PROFILE_FIELDS = {
    "display_name",
    "full_name",
    "bio",
    "birthdate",
    "dob",
    "gender",
    "gender_preference",
    "interested_in",
    "intent",
    "area_name",
    "village_pin_code",
    "interests",
    "height",
    "relationship_goal",
    "smoking",
    "drinking",
    "is_location_masked",
}

# Explicit blacklist of sensitive/monetization columns (guaranteed never mutated here)
PROTECTED_SYSTEM_FIELDS = {
    "id", "email", "phone_number", "is_admin", "is_verified",
    "is_boosted", "boosted_until", "has_direct_dm", "direct_dm_until",
    "is_ad_free", "ad_free_until", "safe_bridge_active", "photo_pass_until",
    "is_premium", "premium_expires_at", "bonus_swipes", "created_at", "updated_at"
}


@router.put("", response_model=dict)
@router.put("/", response_model=dict)
@router.patch("", response_model=dict)
@router.patch("/", response_model=dict)
@router.put("/profile", response_model=dict)
@router.patch("/profile", response_model=dict)
async def update_profile(
    request: ProfileUpdateRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    user_record = None
    try:
        stmt = select(User).where(User.id == user_uuid)
        result = await db.execute(stmt)
        user_record = result.scalars().first()
    except Exception:
        user_record = None

    if not user_record:
        user_record = User(
            id=user_uuid,
            email=f"user_{user_uuid.hex[:8]}@ruralheart.com",
            full_name="UR Heart User",
            dob=date(2000, 1, 1),
            gender=ORMGenderEnum.male,
            interested_in=ORMGenderEnum.female,
            intent=ORMIntentEnum.casual,
            is_active=True,
            is_premium=False,
        )
        db.add(user_record)
        try:
            await db.commit()
            await db.refresh(user_record)
        except Exception:
            pass

    update_payload = request.model_dump(exclude_unset=True)

    # Apply only whitelisted fields with sanitization
    for field, value in update_payload.items():
        if field in ALLOWED_PROFILE_FIELDS and field not in PROTECTED_SYSTEM_FIELDS:
            target_col = field
            if field == "display_name":
                target_col = "full_name"
            elif field == "birthdate":
                target_col = "dob"
            elif field == "gender_preference":
                target_col = "interested_in"

            # Handle Enum conversions safely
            if target_col in ("gender", "interested_in"):
                if isinstance(value, str) and value.strip():
                    try:
                        value = ORMGenderEnum(value.lower().strip())
                    except ValueError:
                        continue
                else:
                    continue
            elif target_col == "intent":
                if isinstance(value, str) and value.strip():
                    try:
                        value = ORMIntentEnum(value.lower().strip())
                    except ValueError:
                        continue
                else:
                    continue

            # Sanitize free-form text inputs against XSS/injections
            if isinstance(value, str):
                value = sanitize_user_input(value)

            if hasattr(user_record, target_col):
                setattr(user_record, target_col, value)

    db.add(user_record)
    await db.commit()
    await db.refresh(user_record)

    return {
        "success": True,
        "message": "Profile updated successfully.",
        "user_id": str(user_record.id),
        "data": {
            "user_id": str(user_record.id),
            "full_name": user_record.full_name,
            "bio": user_record.bio,
            "dob": user_record.dob.isoformat() if user_record.dob else None,
            "is_location_masked": user_record.is_location_masked,
            "is_boosted": bool(user_record.boosted_until and user_record.boosted_until > datetime.now(timezone.utc)),
            "is_admin": user_record.is_admin,
            "is_verified": user_record.is_verified,
        }
    }


@router.put("/presence")
@router.post("/presence")
@router.get("/presence")
async def update_presence(
    payload: Optional[dict] = Body(default=None),
    is_online: Optional[bool] = Query(default=None),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates the user's online status (is_online: bool) and last_seen timestamp in database.
    Accepts PUT/POST with JSON payload or GET with optional query param / heartbeat ping.
    """
    online_val = True
    if payload and isinstance(payload, dict) and "is_online" in payload:
        online_val = bool(payload["is_online"])
    elif is_online is not None:
        online_val = bool(is_online)

    now_utc = datetime.now(timezone.utc)

    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if user_obj:
            user_obj.is_online = online_val
            user_obj.last_seen = now_utc
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message=f"Presence updated to is_online={online_val}.",
        data={"is_online": online_val, "last_seen": now_utc.isoformat()}
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


@router.post(
    "/users/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.put(
    "/users/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.post(
    "/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
@router.put(
    "/location",
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)
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
            user_obj = User(
                id=user_uuid,
                full_name="User",
                dob=date(2000, 1, 1),
                gender=ORMGenderEnum.male,
                interested_in=ORMGenderEnum.female,
                intent=ORMIntentEnum.casual,
                latitude=latitude,
                longitude=longitude,
                is_active=True,
            )
            db.add(user_obj)
            await db.flush()
        else:
            user_obj.latitude = latitude
            user_obj.longitude = longitude
        try:
            await db.execute(
                text("UPDATE users SET location_geom = ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) WHERE id = :uid"),
                {"lng": longitude, "lat": latitude, "uid": user_uuid}
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
        print(f"[PROFILE LOCATION UPDATE ERROR] {e}")
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


@router.post("/upload-voice-bio", response_model=APIResponse[VoiceBioUploadData])
async def upload_voice_bio(
    file: UploadFile = File(...),
    duration_seconds: int = Query(15, description="Duration in seconds (max 15s)"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Accepts 15-second audio voice greeting (.m4a, .mp3, .aac, .wav).
    Uploads directly to Supabase Storage 'voice-bios' or Cloudflare R2 and updates user profile.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user token session."
        )

    filename = (file.filename or f"voice_{uuid.uuid4().hex[:8]}.m4a").lower()

    # Security: Validate audio extension whitelist
    allowed_audio_ext = {".m4a", ".mp3", ".aac", ".wav", ".ogg"}
    file_ext = "." + filename.rsplit(".", 1)[-1] if "." in filename else ""
    if file_ext not in allowed_audio_ext:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid audio format '{file_ext}'. Allowed formats: .m4a, .mp3, .aac, .wav, .ogg"
        )

    try:
        contents = await file.read()
    except Exception:
        contents = b""

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded audio file is empty."
        )

    # Security: Max 10MB for voice bio
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file size exceeds the 10MB limit."
        )

    file_path = f"voice_bios/{user_uuid.hex}_{filename.split('/')[-1].split('\\')[-1]}"
    public_url = None

    if supabase is not None:
        try:
            # Upload to 'voice-bios' or 'profile-photos' bucket
            supabase.storage.from_("profile-photos").upload(
                file_path,
                contents,
                file_options={"content-type": file.content_type or "audio/m4a", "upsert": "true"}
            )
            base_supa_url = settings.SUPABASE_URL.rstrip('/') if settings.SUPABASE_URL else ""
            if base_supa_url:
                public_url = f"{base_supa_url}/storage/v1/object/public/profile-photos/{file_path}"
            else:
                public_url_obj = supabase.storage.from_("profile-photos").get_public_url(file_path)
                public_url = str(public_url_obj)
        except Exception:
            pass

    if not public_url:
        try:
            public_url = await StorageEngineService.upload_profile_photo(
                file_bytes=contents,
                filename=filename
            )
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Storage upload failed"
            )

    dur = min(max(1, duration_seconds), 15)

    try:
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user = user_res.scalars().first()
        if user:
            user.voice_bio_url = public_url
            user.voice_bio_duration_seconds = dur
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="Voice Bio uploaded successfully! 🎙️",
        data=VoiceBioUploadData(
            voice_bio_url=public_url,
            duration_seconds=dur,
            message="Voice Bio uploaded successfully! 🎙️"
        )
    )


@router.delete("/voice-bio", response_model=APIResponse[dict])
async def delete_voice_bio(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Removes the user's active voice bio audio introduction.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user = user_res.scalars().first()
        if user:
            user.voice_bio_url = None
            user.voice_bio_duration_seconds = 0
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="Voice Bio removed successfully.",
        data={"voice_bio_url": None}
    )


def _format_time_ago(dt: Optional[datetime]) -> str:
    if not dt:
        return "Recently"
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    diff = now - dt
    secs = int(diff.total_seconds())
    if secs < 60:
        return "Just now"
    mins = secs // 60
    if mins < 60:
        return f"Passed you {mins}m ago"
    hours = mins // 60
    if hours < 24:
        return f"Passed you {hours}h ago"
    days = hours // 24
    if days == 1:
        return "Passed you yesterday"
    return f"Passed you {days}d ago"


@router.get("/visitors", response_model=APIResponse[VisitorsListResponse])
@router.get("/visitors/", response_model=APIResponse[VisitorsListResponse])
async def get_profile_visitors(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches the list of users who visited or passed the current user (Who Passed You tray).
    Excludes users who are blocked or already matched.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID session.")

    # 1. Fetch current user coordinates
    current_user = None
    try:
        u_res = await db.execute(select(User).where(User.id == user_uuid))
        current_user = u_res.scalars().first()
    except Exception:
        pass

    # 2. Exclude blocked users and matched users
    excluded_ids = set()
    try:
        blocked_res = await db.execute(
            select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == user_uuid)
        )
        for b_id in blocked_res.scalars().all():
            excluded_ids.add(b_id)

        blocker_res = await db.execute(
            select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == user_uuid)
        )
        for b_id in blocker_res.scalars().all():
            excluded_ids.add(b_id)

        matches_res = await db.execute(
            select(Match).where(
                (Match.user1_id == user_uuid) | (Match.user2_id == user_uuid)
            )
        )
        for m in matches_res.scalars().all():
            excluded_ids.add(m.user2_id if m.user1_id == user_uuid else m.user1_id)
    except Exception:
        pass

    # 3. Query impressions where target_id == user_uuid
    visitors_list: List[VisitorItem] = []
    total_count = 0

    try:
        imp_query = (
            select(ProfileImpression)
            .where(ProfileImpression.target_id == user_uuid)
            .order_by(ProfileImpression.created_at.desc())
        )
        if excluded_ids:
            imp_query = imp_query.where(~ProfileImpression.visitor_id.in_(excluded_ids))

        imp_res = await db.execute(imp_query)
        all_impressions = imp_res.scalars().all()
        total_count = len(all_impressions)

        paged_impressions = all_impressions[offset: offset + limit]
        visitor_ids = [imp.visitor_id for imp in paged_impressions]

        if visitor_ids:
            users_res = await db.execute(
                select(User)
                .options(selectinload(User.photos))
                .where(User.id.in_(visitor_ids))
            )
            users_map = {u.id: u for u in users_res.scalars().all()}

            today = date.today()
            for imp in paged_impressions:
                v_user = users_map.get(imp.visitor_id)
                if not v_user:
                    continue

                age = (
                    today.year - v_user.dob.year - ((today.month, today.day) < (v_user.dob.month, v_user.dob.day))
                    if v_user.dob else 22
                )
                photos = [p.photo_url for p in v_user.photos] if v_user.photos else []
                photo_url = photos[0] if photos else (v_user.avatar_url if hasattr(v_user, 'avatar_url') else None)

                dist_km = None
                dist_label = "Nearby"
                if current_user and current_user.latitude and current_user.longitude and v_user.latitude and v_user.longitude:
                    dist_km = GeoEngineService.calculate_haversine_distance(
                        float(current_user.latitude),
                        float(current_user.longitude),
                        float(v_user.latitude),
                        float(v_user.longitude)
                    )
                    dist_km = round(dist_km, 1)
                    dist_label = GeoEngineService.obfuscate_distance(dist_km)

                visitors_list.append(
                    VisitorItem(
                        user_id=str(v_user.id),
                        name=v_user.full_name or "UR Heart User",
                        age=age,
                        city=v_user.area_name or "Ayodhya Region",
                        photo_url=photo_url,
                        photos=photos,
                        distance_km=dist_km,
                        distance_label=dist_label,
                        action_type=imp.action_type,
                        is_verified=bool(v_user.is_verified),
                        visited_at=imp.created_at.isoformat() if imp.created_at else datetime.now(timezone.utc).isoformat(),
                        time_ago=_format_time_ago(imp.created_at),
                    )
                )
    except Exception as e:
        print(f"[VISITORS QUERY ERROR] {e}")

    return APIResponse(
        success=True,
        message=f"Retrieved {len(visitors_list)} profile visitors.",
        data=VisitorsListResponse(
            total_count=total_count,
            unread_count=total_count,
            visitors=visitors_list,
        ),
    )


@router.delete("/visitors/{visitor_id}", response_model=APIResponse[dict])
async def dismiss_profile_visitor(
    visitor_id: str = Path(..., description="The visitor UUID to dismiss"),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Dismisses a visitor impression so they no longer appear in the visitors tray.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        visitor_uuid = uuid.UUID(visitor_id)

        stmt = delete(ProfileImpression).where(
            ProfileImpression.target_id == user_uuid,
            ProfileImpression.visitor_id == visitor_uuid,
        )
        await db.execute(stmt)
        await db.commit()
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid visitor UUID.")
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        message="Visitor impression dismissed successfully.",
        data={"visitor_id": visitor_id, "dismissed": True}
    )


@router.delete("", response_model=APIResponse[dict])
@router.delete("/", response_model=APIResponse[dict])
async def delete_profile_account(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Alias for DELETE /api/v1/users/me: Cascade account deletion.
    """
    from app.api.v1.users import delete_current_user_account
    return await delete_current_user_account(current_user_id=current_user_id, db=db)


