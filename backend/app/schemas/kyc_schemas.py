from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field


class LivenessCheckRequest(BaseModel):
    anchor_photo_b64: str = Field(..., description="Base64 encoded profile anchor portrait (WebP/JPEG)")
    video_bytes_b64: Optional[str] = Field(None, description="Base64 encoded 3s live selfie video")
    frame_1_b64: Optional[str] = Field(None, description="Base64 frame 1")
    frame_2_b64: Optional[str] = Field(None, description="Base64 frame 2")
    frame_3_b64: Optional[str] = Field(None, description="Base64 frame 3")


class LivenessCheckResponse(BaseModel):
    is_live_human: bool
    face_match_score: int = Field(..., ge=0, le=100)
    estimated_age_bracket: str
    is_underage: bool
    rejection_reason: Optional[str] = None


class KycResolutionRequest(BaseModel):
    escalation_id: int
    user_id: UUID
    action: str = Field(..., pattern="^(approve|reject)$")
    admin_notes: str = ""


class KycResolutionResponse(BaseModel):
    status: str
    user_id: UUID
    kyc_status: bool
    reviewed_at: Optional[datetime] = None
