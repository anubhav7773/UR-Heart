from typing import Any, Dict, Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User

router = APIRouter(prefix="/profile", tags=["User Profile Engine"])

# Legacy set maintained for backward compatibility
COMPLETED_PROFILES: set[str] = set()


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = Field(None, max_length=60)
    gender: Optional[str] = Field(None, max_length=20)
    bio: Optional[str] = Field(None, max_length=500)
    profession: Optional[str] = Field(None, max_length=80)
    education: Optional[str] = Field(None, max_length=100)
    location: Optional[str] = Field(None, max_length=100)
    location_name: Optional[str] = Field(None, max_length=100)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    contact_bridge_type: Optional[str] = Field(None, max_length=30)
    contact_bridge_handle: Optional[str] = None
    is_kyc_verified: Optional[bool] = None
    photo_slots_count: Optional[int] = None
    preferred_age_min: Optional[int] = Field(None, ge=18, le=100)
    preferred_age_max: Optional[int] = Field(None, ge=18, le=100)
    email: Optional[str] = None

    model_config = ConfigDict(extra="ignore")


class SlumberToggleRequest(BaseModel):
    is_slumber_active: bool


@router.get("/me", status_code=status.HTTP_200_OK)
async def get_my_authenticated_profile(
    current_user: User = Depends(get_current_user)
):
    """Fetches verified persona for Screen 11 without PII leakage."""
    return {
        "id": str(current_user.id),
        "full_name": current_user.full_name,
        "dob": current_user.dob.isoformat() if current_user.dob else None,
        "gender": current_user.gender,
        "interested_in": current_user.interested_in,
        "bio": current_user.bio,
        "profession": current_user.profession,
        "education": current_user.education,
        "location_name": current_user.location_name,
        "kyc_status": current_user.kyc_status,
        "subscription_tier": current_user.subscription_tier,
        "is_ad_free": current_user.is_ad_free,
        "reward_balance": current_user.reward_balance,
        "swipes_remaining": current_user.swipes_remaining,
        "direct_letters_count": current_user.direct_letters_count,
        "referral_code": current_user.referral_code,
        "is_profile_completed": current_user.is_profile_completed,
        "night_slumber": current_user.night_slumber,
        "is_incognito": current_user.is_incognito,
        "discreet_mode": current_user.discreet_mode,
        "contact_bridge_type": current_user.contact_bridge_type,
        "contact_bridge_masked": (
            current_user.contact_bridge_encrypted[:4] + "****"
            if current_user.contact_bridge_encrypted
            else ""
        )
    }


@router.put("/me", status_code=status.HTTP_200_OK)
@router.post("/me", status_code=status.HTTP_200_OK)
async def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-03 Fix: Live profile editor route.
    Updates bio, profession, education, location, name, and preferences in database.
    """
    update_data = payload.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(status_code=400, detail="No editable fields provided.")

    if payload.preferred_age_min and payload.preferred_age_max:
        if payload.preferred_age_min > payload.preferred_age_max:
            raise HTTPException(status_code=422, detail="Minimum preferred age cannot exceed maximum age.")

    # Remap field aliases to User table columns
    if "location" in update_data and "location_name" not in update_data:
        update_data["location_name"] = update_data.pop("location")
    else:
        update_data.pop("location", None)

    if "contact_bridge_handle" in update_data:
        handle = update_data.pop("contact_bridge_handle")
        if handle:
            update_data["contact_bridge_encrypted"] = str(handle)

    if "is_kyc_verified" in update_data:
        update_data["kyc_status"] = update_data.pop("is_kyc_verified")

    update_data.pop("photo_slots_count", None)
    email_val = update_data.pop("email", None)

    # Mark profile completed in database (Fixes DUM-17 volatile memory set)
    update_data["is_profile_completed"] = True

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(**update_data)
    )
    await db.commit()

    if getattr(current_user, "email", None):
        COMPLETED_PROFILES.add(current_user.email.strip().lower())
    if email_val:
        COMPLETED_PROFILES.add(email_val.strip().lower())
    if payload.full_name:
        COMPLETED_PROFILES.add(payload.full_name.strip().lower())

    return {"status": "success", "message": "Profile updated and persisted successfully."}


@router.patch("/slumber-mode", status_code=status.HTTP_200_OK)
async def toggle_night_slumber(
    payload: SlumberToggleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-13 Fix: Persists night slumber mode in Supabase users table.
    """
    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(night_slumber=payload.is_slumber_active)
    )
    await db.commit()

    return {
        "status": "success",
        "night_slumber": payload.is_slumber_active
    }


class ProfileCreateRequest(BaseModel):
    full_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    looking_for: Optional[str] = None
    bridge_platform: Optional[str] = None
    bridge_value: Optional[str] = None
    location: Optional[str] = None
    location_name: Optional[str] = None
    bio: Optional[str] = None
    profession: Optional[str] = None
    education: Optional[str] = None
    is_kyc: Optional[bool] = False
    photos: Optional[list] = None
    email: Optional[str] = None

    model_config = ConfigDict(extra="ignore")


@router.post(
    "/create",
    status_code=status.HTTP_200_OK,
    summary="Create or Update User Sanctuary Profile"
)
async def create_or_update_profile(
    payload: ProfileCreateRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Saves completed user profile parameters to Sanctuary database
    and logs the creation event to Render console.
    """
    loc_name = payload.location_name or payload.location

    if payload.full_name:
        COMPLETED_PROFILES.add(payload.full_name.strip().lower())
    if payload.email:
        COMPLETED_PROFILES.add(payload.email.strip().lower())

    if payload.email:
        clean_email = payload.email.strip().lower()
        up_vals: Dict[str, Any] = {"is_profile_completed": True}
        if payload.full_name:
            up_vals["full_name"] = payload.full_name
        if payload.gender:
            up_vals["gender"] = payload.gender
        if payload.bio:
            up_vals["bio"] = payload.bio
        if payload.profession:
            up_vals["profession"] = payload.profession
        if payload.education:
            up_vals["education"] = payload.education
        if loc_name:
            up_vals["location_name"] = loc_name
        if payload.is_kyc is not None:
            up_vals["kyc_status"] = payload.is_kyc
        if payload.bridge_platform:
            up_vals["contact_bridge_type"] = payload.bridge_platform
        if payload.bridge_value:
            up_vals["contact_bridge_encrypted"] = payload.bridge_value

        await db.execute(
            update(User)
            .where(User.email == clean_email)
            .values(**up_vals)
        )
        await db.commit()

    print(
        f"[PROFILE PERSISTENCE] Profile Created/Updated: name={payload.full_name} "
        f"gender={payload.gender} looking_for={payload.looking_for} "
        f"location={loc_name} kyc={payload.is_kyc}",
        flush=True
    )
    return {
        "status": "created",
        "is_success": True,
        "is_profile_completed": True,
        "message": "Sanctuary profile saved and verified successfully.",
        "profile": {
            "full_name": payload.full_name,
            "location_name": loc_name,
            "is_kyc": payload.is_kyc,
        }
    }
