from typing import List, Optional
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.services.groq_service import GroqAiService, KycAiEvaluation

router = APIRouter(prefix="/kyc", tags=["KYC Biometric Verification"])


class VerifyLiveKycPayload(BaseModel):
    anchor_b64: str = Field(..., description="Base64 encoded anchor profile portrait")
    frames_b64: List[str] = Field(default_factory=list, description="Base64 encoded frames from live video")


@router.post("/verify-live", response_model=KycAiEvaluation, status_code=status.HTTP_200_OK)
async def verify_live_kyc(
    payload: VerifyLiveKycPayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Evaluates video KYC using fail-closed Groq Vision Sentinel.
    If corrupted or ambiguous, fails closed, sets status to pending_manual_review,
    and inserts row into admin_kyc_escalations table.
    """
    evaluation = await GroqAiService.verify_kyc_liveness_secure(
        user_id=current_user.id,
        anchor_b64=payload.anchor_b64,
        frames_b64=payload.frames_b64,
        db_session=db
    )
    return evaluation
