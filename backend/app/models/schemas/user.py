from datetime import date, datetime
from typing import Optional, List, Any
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict, field_validator
from app.core.sanitizer import sanitize_user_html, strip_null_bytes

class UserProfileUpdateRequest(BaseModel):
    """
    Profile update payload.
    - Security Check 14: Strict regex & boundary validation.
    - Security Check 8: extra='forbid' to prevent field tampering and mass assignment.
    - Security Check 15: HTML escaping on user-provided strings.
    """
    model_config = ConfigDict(extra="forbid")

    full_name: Optional[str] = Field(
        None, min_length=2, max_length=50, pattern=r"^[a-zA-Z\s]+$",
        description="User's display name (letters and spaces only)"
    )
    bio: Optional[str] = Field(None, max_length=250, description="Short bio")
    city: Optional[str] = Field(None, min_length=2, max_length=50, description="Current city")
    whatsapp_number: Optional[str] = Field(
        None, pattern=r"^\+91[6-9]\d{9}$", description="WhatsApp contact number E.164"
    )

    @field_validator("*", mode="before")
    @classmethod
    def validate_and_sanitize(cls, v: Any) -> Any:
        if isinstance(v, str):
            strip_null_bytes(v)
            return sanitize_user_html(v)
        return v

class UserProfileResponse(BaseModel):
    """
    Safe profile response schema.
    - Security Check 17: Strips internal system & admin flags:
      firebase_uid, kyc_document_sha256, last_installation_uuid, ip_address, is_super_admin, deleted_at.
    """
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: str
    phone_number: str
    whatsapp_number: str
    dob: date
    gender: str
    city: str
    bio: Optional[str] = ""
    streak_count: Optional[int] = 0
    reward_balance: Optional[int] = 0
    kyc_status: Optional[bool] = False
    kyc_state: Optional[str] = "pending_ai"
    created_at: Optional[datetime] = None

class PhotoDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    url: str
    blur_hash: Optional[str] = ""

class UserDiscoveryProfileResponse(BaseModel):
    """
    Data-minimized DTO for discovery/matching. Exposes only public demographic and profile data.
    """
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: str
    age: int
    city: str
    bio: Optional[str] = ""
    photos: List[PhotoDTO] = Field(default_factory=list)
    streak_tier: str = "Bronze"

