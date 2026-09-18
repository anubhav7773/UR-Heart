from datetime import date, datetime
from typing import Optional, List, Literal, Any
from uuid import UUID
import re
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

class ProfilePhotoItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    slot_index: int
    photo_url: str
    blur_hash: Optional[str] = ""

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
    photo_count: Optional[int] = 0
    photos: List[ProfilePhotoItem] = Field(default_factory=list)
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

# ==============================================================================
# GEOSPATIAL & DISCOVERY SCHEMAS (SUB-TASK A.3)
# ==============================================================================

# 1. Profile Setup Request Payload
class UserProfileSetupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(..., min_length=2, max_length=50, description="Legal full name")
    whatsapp_number: str = Field(..., description="Indian WhatsApp Number in E.164 format")
    gender: Literal["male", "female", "lgbtq+", "other"]
    city: str = Field(..., min_length=2, max_length=50)
    bio: Optional[str] = Field(default="", max_length=250)
    
    # Internal GPS Coordinates (Captured client-side from GPS)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    detected_locality: Optional[str] = Field(None, max_length=100)

    @field_validator("full_name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        clean_name = v.strip()
        if not re.match(r"^[a-zA-Z\s.'-]+$", clean_name):
            raise ValueError("Name can only contain alphabetic characters, spaces, dots, and hyphens.")
        return clean_name

    @field_validator("whatsapp_number")
    @classmethod
    def validate_whatsapp(cls, v: str) -> str:
        clean = re.sub(r"[\s\-()]", "", v)
        if not re.match(r"^\+91[6-9]\d{9}$", clean):
            raise ValueError("WhatsApp number must be a valid 10-digit Indian number prefixed with +91.")
        return clean

# 2. Public Photo DTO
class ProfilePhotoDTO(BaseModel):
    slot_index: int
    photo_storage_path: str
    blur_hash: str

# 3. Discovery Feed Card Response (Coordinates are strictly excluded)
class DiscoveryProfileResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    user_id: UUID
    full_name: str
    city: str
    detected_locality: Optional[str] = None
    distance_km: Optional[int] = None
    distance_badge: str = "Nearby"
    gender: str
    bio: str
    streak_count: int
    photos: List[ProfilePhotoDTO] = []

    @classmethod
    def from_row(cls, row: dict) -> "DiscoveryProfileResponse":
        dist = row.get("distance_km")
        if dist is not None:
            if dist < 1:
                badge = "Nearby < 1 km"
            else:
                badge = f"Nearby {dist} km"
        else:
            badge = "Location Unavailable"

        raw_photos = row.get("photos") or []
        parsed_photos = []
        for p in raw_photos:
            if isinstance(p, dict):
                parsed_photos.append(ProfilePhotoDTO(**p))
            elif isinstance(p, ProfilePhotoDTO):
                parsed_photos.append(p)

        return cls(
            user_id=row["user_id"],
            full_name=row["full_name"],
            city=row["city"],
            detected_locality=row.get("detected_locality"),
            distance_km=dist,
            distance_badge=badge,
            gender=row["gender"],
            bio=row.get("bio") or "",
            streak_count=row.get("streak_count", 0),
            photos=parsed_photos
        )
