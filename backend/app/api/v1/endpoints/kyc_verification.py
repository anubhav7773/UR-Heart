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
    anchor_b64: Optional[str] = Field(None, description="Base64 encoded anchor profile portrait (Slot 1)")
    profile_photos_b64: List[str] = Field(default_factory=list, description="Base64 encoded profile photos from slots 1 to 5")
    profile_photo_urls: List[str] = Field(default_factory=list, description="Remote URLs for profile photos")
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
    Evaluates Live Photo Pose Selfie KYC using fail-closed Vision Sentinel.
    Cross-matches live selfie against all uploaded profile photos (up to 5 photos).
    If identity diverges, impersonation is detected, or models are unavailable, strictly fails closed.
    """
    if payload.selfie_b64 and len(payload.selfie_b64.strip()) > 50:
        frames = [payload.selfie_b64.strip()]
    elif payload.frames_b64:
        frames = payload.frames_b64
    elif payload.video_b64:
        frames = [payload.video_b64]
    else:
        frames = []

    # Aggregate candidate profile photos from payload and user database record
    raw_profile_items: List[str] = []
    if payload.profile_photos_b64:
        raw_profile_items.extend(payload.profile_photos_b64)
    if payload.anchor_b64 and payload.anchor_b64.strip():
        raw_profile_items.insert(0, payload.anchor_b64.strip())
    if payload.profile_photo_urls:
        raw_profile_items.extend(payload.profile_photo_urls)
    if current_user.avatar_url and str(current_user.avatar_url).strip():
        raw_profile_items.insert(0, str(current_user.avatar_url).strip())
    if current_user.photos:
        for p in current_user.photos:
            if p and str(p).strip():
                raw_profile_items.append(str(p).strip())

    # Deduplicate candidate items
    unique_items: List[str] = []
    for item in raw_profile_items:
        if item not in unique_items:
            unique_items.append(item)

    resolved_profile_photos = await GroqAiService.resolve_images_to_b64(unique_items)

    # Strict Fail-Closed Gate:
    # 1. If neither profile photos nor frames exist (corrupted input like SEC-11 test),
    # forward to EvaIdentityEngine to trigger fail-closed admin queue escalation and pending_manual_review.
    if not resolved_profile_photos and not frames:
        return await GroqAiService.verify_kyc_liveness_secure(
            user_id=current_user.id,
            anchor_b64=payload.anchor_b64 or "",
            frames_b64=frames,
            expected_pose=payload.expected_pose,
            profile_photos_b64=[],
            db_session=db
        )

    # 2. If selfie frames are submitted but profile photos are missing, strictly reject (Anti-Catfish)
    if not resolved_profile_photos:
        print(f"[KYC VERIFY] User {current_user.id} ({current_user.email}) fail-closed: No profile photos found.", flush=True)
        current_user.kyc_status = False
        try:
            await db.commit()
        except Exception:
            await db.rollback()

        return KycAiEvaluation(
            is_live_human=False,
            face_match_score=0,
            is_identity_match=False,
            gallery_consistent=False,
            pose_matched=False,
            is_underage=False,
            rejection_reason="Profile photos missing: Please upload your profile photos first before verifying KYC.",
            status="rejected",
            analysis_summary="Profile photos missing. Self-matching is strictly prohibited."
        )

    evaluation = await GroqAiService.verify_kyc_liveness_secure(
        user_id=current_user.id,
        anchor_b64=resolved_profile_photos[0] if resolved_profile_photos else "",
        frames_b64=frames,
        expected_pose=payload.expected_pose,
        profile_photos_b64=resolved_profile_photos,
        db_session=db
    )

    # Strict Fail-Closed Anti-Catfish Security Policy:
    # Only set kyc_status=True if all criteria pass, including verified identity match against profile photos.
    is_approved = (
        evaluation.status == "approved"
        and evaluation.is_live_human is True
        and evaluation.is_identity_match is True
        and evaluation.gallery_consistent is True
        and evaluation.face_match_score >= 75
        and evaluation.pose_matched is True
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
                f"kyc_status=False (status={evaluation.status}, score={evaluation.face_match_score}, "
                f"match={evaluation.is_identity_match}, live={evaluation.is_live_human}, pose={evaluation.pose_matched})",
                flush=True
            )
            from app.api.v1.endpoints.notifications import push_notification
            rejection_body = evaluation.rejection_reason or "Identity verification unconfirmed. Please resubmit your portrait."
            push_notification(
                user_id=str(current_user.id),
                notif_type="kyc_resubmit",
                title="KYC Verification Notice 🛡️",
                body=rejection_body,
                data={"target_route": "/settings", "kyc_status": False}
            )
    except Exception as e:
        await db.rollback()
        print(f"[KYC VERIFY] DB commit notice: {e}", flush=True)

    return evaluation
