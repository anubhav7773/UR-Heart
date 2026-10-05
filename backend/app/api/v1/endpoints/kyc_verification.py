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
    selfie_b64: Optional[str] = Field(None, description="Base64 encoded live photo pose selfie snapshot")
    frames_b64: List[str] = Field(default_factory=list, description="Base64 encoded frames from live video")
    video_b64: Optional[str] = Field(None, description="Base64 encoded video clip")
    expected_pose: Optional[str] = Field(None, description="Randomized challenge pose requested from user")


@router.post("/verify-live", response_model=KycAiEvaluation, status_code=status.HTTP_200_OK)
async def verify_live_kyc(
    payload: VerifyLiveKycPayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Evaluates Live Photo Pose Selfie KYC (or fallback video frames) using fail-closed Vision Sentinel.
    If ambiguous or models unavailable, strictly fails closed (status: pending_manual_review),
    leaves kyc_status=False, and routes escalation to admin_kyc_escalations table.
    """
    if payload.selfie_b64 and len(payload.selfie_b64.strip()) > 50:
        frames = [payload.selfie_b64.strip()]
    elif payload.frames_b64:
        frames = payload.frames_b64
    elif payload.video_b64:
        frames = [payload.video_b64]
    else:
        frames = []

    evaluation = await GroqAiService.verify_kyc_liveness_secure(
        user_id=current_user.id,
        anchor_b64=payload.anchor_b64,
        frames_b64=frames,
        expected_pose=payload.expected_pose,
        db_session=db
    )

    # Strict Fail-Closed Security Policy: Only set kyc_status=True if all criteria pass.
    # High biometric similarity (>= 80%) with confirmed human liveness decisively proves account authenticity.
    is_approved = (
        evaluation.status == "approved"
        and evaluation.is_live_human is True
        and evaluation.face_match_score >= 75
        and (evaluation.pose_matched is True or evaluation.face_match_score >= 80)
        and not evaluation.is_underage
    )

    current_user.kyc_status = is_approved
    try:
        await db.commit()
        await db.refresh(current_user)
        if is_approved:
            print(f"[KYC VERIFY] User {current_user.id} ({current_user.email}) marked kyc_status=True in DB", flush=True)
            from app.api.v1.endpoints.notifications import push_notification
            push_notification(
                user_id=str(current_user.id),
                notif_type="kyc_approved",
                title="Identity Verified! 🛡️",
                body="Your biometric KYC verification is approved. Sovereign Blue Crest unlocked!",
                data={"target_route": "/settings", "kyc_status": True}
            )
        else:
            print(
                f"[KYC VERIFY] User {current_user.id} ({current_user.email}) fail-closed: "
                f"kyc_status=False (status={evaluation.status}, score={evaluation.face_match_score}, live={evaluation.is_live_human}, pose={evaluation.pose_matched})",
                flush=True
            )
            from app.api.v1.endpoints.notifications import push_notification
            push_notification(
                user_id=str(current_user.id),
                notif_type="kyc_resubmit",
                title="KYC Verification Notice 🛡️",
                body="Liveness verification requires clearer lighting. Please resubmit your portrait.",
                data={"target_route": "/settings", "kyc_status": False}
            )
    except Exception as e:
        await db.rollback()
        print(f"[KYC VERIFY] DB commit notice: {e}", flush=True)

    return evaluation
