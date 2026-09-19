from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status, File, Form, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, update, select, func

from app.core.config import settings
from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.schemas.user import (
    UserProfileUpdateRequest,
    UserProfileResponse,
    UserProfileSetupRequest,
    DiscoveryProfileResponse,
    ProfilePhotoItem,
)
from app.core.legal_audit import record_legal_audit_event
from app.services.storage_service import validate_photo_file, upload_profile_photo_to_storage, supabase_storage_client

router = APIRouter()

# 1. Profile Retrieval Endpoint
@router.get("/me", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
@router.get("/profile", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the authenticated user's profile with verified user photos ordered by slot.
    Extracts identity strictly from verified server-side JWT (prevents IDOR).
    """
    stmt = (
        select(UserPhoto)
        .where(UserPhoto.user_id == current_user.id)
        .order_by(UserPhoto.slot_index.asc())
    )
    result = await db.execute(stmt)
    photos = result.scalars().all()

    supabase_base = settings.SUPABASE_URL or "https://pzrsyxvjbmzqlzlehuxg.supabase.co"
    photo_items = []
    for p in photos:
        path = p.photo_storage_path
        if not path.startswith("http"):
            photo_url = f"{supabase_base}/storage/v1/object/public/user-photos/{path}"
        else:
            photo_url = path
        photo_items.append(
            ProfilePhotoItem(
                slot_index=p.slot_index,
                photo_url=photo_url,
                blur_hash=p.blur_hash or "",
            )
        )

    resp = UserProfileResponse.model_validate(current_user)
    resp.photo_count = len(photos)
    resp.photos = photo_items
    return resp

# 2. Profile Update Endpoint
@router.patch("/profile", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def update_profile(
    payload: UserProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates the authenticated user's profile.
    - Locks record access: Strictly uses current_user.id from verified JWT (prevents IDOR).
    - Prevents mass assignment: UserProfileUpdateRequest forbids unknown/privileged fields (extra='forbid').
    - Executes 100% parameterized SQLAlchemy 2.0 update query.
    """
    update_data = payload.model_dump(exclude_unset=True)
    if not update_data:
        return current_user

    update_data["updated_at"] = datetime.now(timezone.utc)

    stmt = (
        update(User)
        .where(User.id == current_user.id)
        .values(**update_data)
        .execution_options(synchronize_session="fetch")
    )
    await db.execute(stmt)
    await db.commit()

    res = await db.execute(select(User).where(User.id == current_user.id))
    updated_user = res.scalar_one()
    return updated_user

# 3. Profile Setup Endpoint (Sub-Task A.4)
@router.post("/profile-setup", status_code=status.HTTP_200_OK)
async def setup_user_profile(
    payload: UserProfileSetupRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Saves user name, WhatsApp (+91), inclusive gender, and private GPS coordinates.
    Exact GPS coordinates are secured and never exposed to other clients.
    """
    stmt = (
        update(User)
        .where(User.id == current_user.id)
        .values(
            full_name=payload.full_name,
            whatsapp_number=payload.whatsapp_number,
            gender=payload.gender,
            city=payload.city,
            bio=payload.bio or "",
            latitude=payload.latitude,
            longitude=payload.longitude,
            detected_locality=payload.detected_locality
        )
    )
    await db.execute(stmt)
    await db.commit()

    # Log Profile Setup in statutory audit trail
    await record_legal_audit_event(
        request=request,
        action_type="USER_PROFILE_SETUP",
        user_id=current_user.id,
        db=db
    )

    return {
        "status": "success",
        "message": "Profile initialized successfully. Proceed to media KYC."
    }

# 4. Discovery Feed Endpoint with Relative Distance Badge (Sub-Task A.4)
@router.get("/feed", response_model=List[DiscoveryProfileResponse])
async def get_feed(
    lat: float = Query(..., ge=-90.0, le=90.0, description="Caller's current GPS Latitude"),
    lon: float = Query(..., ge=-180.0, le=180.0, description="Caller's current GPS Longitude"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches discovery feed ordered by proximity using the database spatial function.
    Returns relative distance badges (e.g. 'Nearby 12 km') without leaking exact coordinates.
    """
    sql = text("""
        SELECT * FROM public.get_discovery_feed(
            :current_user_id,
            :lat,
            :lon,
            :limit,
            :offset
        )
    """)
    
    result = await db.execute(
        sql,
        {
            "current_user_id": current_user.id,
            "lat": lat,
            "lon": lon,
            "limit": limit,
            "offset": offset
        }
    )
    rows = result.mappings().all()

    return [DiscoveryProfileResponse.from_row(dict(row)) for row in rows]


from pydantic import BaseModel, Field

class DeviceTokenRequest(BaseModel):
    fcm_token: str = Field(..., min_length=10, max_length=255)

@router.post("/device-token", status_code=status.HTTP_200_OK)
async def update_device_token(
    payload: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Registers or updates the user's FCM device token for WhatsApp-style push notifications.
    """
    current_user.fcm_token = payload.fcm_token
    await db.commit()
    return {"status": "success", "message": "Device token updated"}


@router.post("/photos/upload", status_code=status.HTTP_200_OK)
async def upload_user_photo(
    slot_index: int = Form(..., ge=1, le=5),
    file: UploadFile = File(...),
    blur_hash: Optional[str] = Form(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Uploads compressed WebP photo to Supabase storage 'user-photos' bucket and persists
    the record in Supabase public.user_photos table.
    """
    contents = await file.read()
    validate_photo_file(contents, filename=file.filename or "")

    # Upload to Supabase Storage bucket 'user-photos'
    public_url = await upload_profile_photo_to_storage(
        user_id=current_user.id,
        slot_index=slot_index,
        file_bytes=contents,
        content_type=file.content_type or "image/webp"
    )

    # Persist or update record in public.user_photos
    existing_stmt = select(UserPhoto).where(
        UserPhoto.user_id == current_user.id,
        UserPhoto.slot_index == slot_index
    )
    res = await db.execute(existing_stmt)
    existing = res.scalars().first()

    if existing:
        existing.photo_storage_path = public_url
        existing.blur_hash = blur_hash or ""
        existing.ocr_verified = True
        existing.created_at = datetime.now(timezone.utc)
    else:
        new_photo = UserPhoto(
            user_id=current_user.id,
            slot_index=slot_index,
            photo_storage_path=public_url,
            blur_hash=blur_hash or "",
            ocr_verified=True,
            created_at=datetime.now(timezone.utc)
        )
        db.add(new_photo)

    await db.commit()

    return {
        "status": "success",
        "slot_index": slot_index,
        "photo_url": public_url,
        "blur_hash": blur_hash or ""
    }


@router.delete("/photos/{slot_index}", status_code=status.HTTP_200_OK)
async def delete_user_photo(
    slot_index: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Deletes a secondary photo from slots 2-5.
    Slot 1 (Hero avatar) cannot be deleted directly; it can only be replaced.
    """
    if slot_index == 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Primary hero photo (Slot 1) cannot be deleted. You may replace it with a new photo."
        )

    stmt = select(UserPhoto).where(
        UserPhoto.user_id == current_user.id,
        UserPhoto.slot_index == slot_index
    )
    res = await db.execute(stmt)
    photo = res.scalar_one_or_none()

    if not photo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo slot is already empty.")

    # Remove file from Supabase storage
    try:
        if supabase_storage_client:
            storage_path = f"{current_user.id}/slot_{slot_index}.webp"
            supabase_storage_client.storage.from_("user-photos").remove([storage_path, photo.photo_storage_path])
    except Exception:
        pass

    await db.delete(photo)
    await db.commit()

    return {"status": "success", "message": f"Photo in slot {slot_index} deleted."}


@router.post("/fcm-token", status_code=status.HTTP_200_OK)
@router.post("/device-token", status_code=status.HTTP_200_OK)
async def update_fcm_token(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    token = payload.get("fcm_token")
    if not token:
        raise HTTPException(status_code=400, detail="Missing fcm_token")

    current_user.fcm_token = token
    await db.execute(
        update(User).where(User.id == current_user.id).values(fcm_token=token)
    )
    await db.commit()
    return {"status": "success", "message": "FCM token registered."}
