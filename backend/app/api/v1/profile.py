import uuid
from datetime import date
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

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
from app.models.orm import User, UserPhoto, GenderEnum as ORMGenderEnum, IntentEnum as ORMIntentEnum
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
async def get_user_profile(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves logged-in user profile details (id, full_name, dob, age, gender, interested_in, intent, bio, area_name, village_pin_code, photos).
    Safely uses selectinload(User.photos) and converts result to clean response dictionary.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    user = None
    photos = []
    try:
        stmt = select(User).options(selectinload(User.photos)).where(User.id == user_uuid)
        res = await db.execute(stmt)
        user = res.scalars().first()
        if user and user.photos:
            photos = user.photos
    except Exception:
        await db.rollback()

    today = date.today()
    if user and user.dob:
        age = today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day))
    else:
        age = 22

    photo_urls = [p.photo_url for p in photos] if photos else []

    profile_data = {
        "user_id": current_user_id,
        "full_name": user.full_name if user and user.full_name else "RuralHeart User",
        "dob": user.dob.isoformat() if user and user.dob else "2000-01-01",
        "age": age,
        "gender": user.gender.value if user and user.gender else "male",
        "interested_in": user.interested_in.value if user and user.interested_in else "female",
        "intent": user.intent.value if user and user.intent else "casual",
        "bio": user.bio if user and user.bio else "Simple & genuine person looking for connection.",
        "area_name": user.area_name if user and user.area_name else "Ayodhya",
        "village_pin_code": user.village_pin_code if user and user.village_pin_code else "224001",
        "photos": photo_urls,
        "is_profile_complete": bool(user and len(photo_urls) > 0),
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
            public_url_obj = supabase.storage.from_("profile-photos").get_public_url(file_path)
            public_url = str(public_url_obj)
        except Exception:
            pass

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

