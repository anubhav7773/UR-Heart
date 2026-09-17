from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict

class CandidatePhoto(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    slot_index: int
    photo_url: str
    blur_hash: str = ""

class CandidateProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    full_name: str
    age: int
    city: str
    bio: str = ""
    gender: str
    streak_count: int = 0
    kyc_status: bool = False
    interests: List[str] = Field(default_factory=list)
    photos: List[CandidatePhoto] = Field(default_factory=list)
    distance_km: int = 5
    distance_badge: str = "Nearby 5 km"

class FeedResponse(BaseModel):
    candidates: List[CandidateProfile]
    total: int

class SwipeRequest(BaseModel):
    target_user_id: UUID
    swipe_type: str = Field(..., pattern=r"^(like|pass|direct_dm)$")

class SwipeResponse(BaseModel):
    status: str
    is_match: bool
    match_id: Optional[UUID] = None
    message: str
    whatsapp_unlocked: bool = False
    remaining_dm_tokens: Optional[int] = None
