"""User schemas re-exports and secure models."""
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from app.models.schemas import (
    UserRead,
    UserResponse,
    PhotoRead,
    ProfileCardData,
    CompleteProfileRequest,
    CompleteProfileData,
    DirectDMRequest,
    DirectDMData,
    ClerkUserClaims,
    ClerkSyncRequest,
    ClerkSyncData,
    UserSessionData,
)


class UserProfileResponse(BaseModel):
    id: str
    clerk_id: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    first_name: Optional[str] = None
    age: Optional[int] = None
    bio: Optional[str] = None
    gender: Optional[str] = None
    interested_in: Optional[str] = None
    intent: Optional[str] = None
    area_name: Optional[str] = None
    photos: List[str] = []
    photo_url: Optional[str] = None
    is_verified: bool = False
    is_admin: bool = False
    is_online: bool = False
    is_onboarded: bool = False

    model_config = ConfigDict(
        from_attributes=True,
        extra='ignore',
    )


__all__ = [
    "UserRead",
    "UserResponse",
    "PhotoRead",
    "ProfileCardData",
    "CompleteProfileRequest",
    "CompleteProfileData",
    "DirectDMRequest",
    "DirectDMData",
    "UserProfileResponse",
    "ClerkUserClaims",
    "ClerkSyncRequest",
    "ClerkSyncData",
    "UserSessionData",
]
