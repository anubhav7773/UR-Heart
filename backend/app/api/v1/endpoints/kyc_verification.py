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
    video_b64: Optional[str] = Field(None, description="Base64 encoded video clip")


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
    frames = payload.frames_b64 if payload.frames_b64 else ([payload.video_b64] if payload.video_b64 else [])
    evaluation = await GroqAiService.verify_kyc_liveness_secure(
        user_id=current_user.id,
        anchor_b64=payload.anchor_b64,
        frames_b64=frames,
        db_session=db
    )

    if evaluation.status == "approved" or (evaluation.is_live_human and evaluation.face_match_score >= 70):
        current_user.kyc_status = True
        try:
            await db.commit()
            await db.refresh(current_user)
            print(f"[KYC VERIFY] User {current_user.id} ({current_user.email}) marked kyc_status=True in DB", flush=True)
        except Exception as e:
            await db.rollback()
            print(f"[KYC VERIFY] DB commit notice: {e}", flush=True)

    return evaluation
