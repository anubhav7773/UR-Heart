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
)


class UserProfileResponse(BaseModel):
    id: str
    full_name: Optional[str] = None
    first_name: Optional[str] = None
    age: Optional[int] = None
    bio: Optional[str] = None
    photos: List[str] = []
    is_verified: bool = False
    is_online: bool = False

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
]
