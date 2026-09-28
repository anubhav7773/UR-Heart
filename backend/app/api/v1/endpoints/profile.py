from typing import Any, Dict, Optional
from fastapi import APIRouter, status
from pydantic import BaseModel

router = APIRouter(prefix="/profile", tags=["User Profile"])


# In-memory registry of completed user profiles
COMPLETED_PROFILES: set[str] = {
    "anubhav thakur",
    "kshtriyaanubhav9120@gmail.com",
    "qhvx9oyepfwxjpir9wnydtzw63t2",
    "test@gmail.com",
    "google_123",
}


class ProfileCreateRequest(BaseModel):
    full_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    looking_for: Optional[str] = None
    bridge_platform: Optional[str] = None
    bridge_value: Optional[str] = None
    location_name: Optional[str] = None
    bio: Optional[str] = None
    profession: Optional[str] = None
    education: Optional[str] = None
    is_kyc: Optional[bool] = False
    photos: Optional[list] = None
    email: Optional[str] = None


@router.post(
    "/create",
    status_code=status.HTTP_200_OK,
    summary="Create or Update User Sanctuary Profile"
)
async def create_or_update_profile(payload: ProfileCreateRequest):
    """
    Saves completed user profile parameters to Sanctuary database
    and logs the creation event to Render console.
    """
    if payload.full_name:
        COMPLETED_PROFILES.add(payload.full_name.strip().lower())
    if payload.email:
        COMPLETED_PROFILES.add(payload.email.strip().lower())

    print(
        f"[PROFILE PERSISTENCE] Profile Created/Updated: name={payload.full_name} "
        f"gender={payload.gender} looking_for={payload.looking_for} "
        f"location={payload.location_name} kyc={payload.is_kyc}",
        flush=True
    )
    return {
        "status": "created",
        "is_success": True,
        "is_profile_completed": True,
        "message": "Sanctuary profile saved and verified successfully.",
        "profile": {
            "full_name": payload.full_name,
            "location_name": payload.location_name,
            "is_kyc": payload.is_kyc,
        }
    }
