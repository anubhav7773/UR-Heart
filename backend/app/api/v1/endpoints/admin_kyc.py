import os
from uuid import UUID
from datetime import datetime, timezone
from typing import List, Optional, Literal
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, and_

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue
from app.services.storage_service import purge_kyc_video_from_storage, supabase_storage_client

router = APIRouter()
MASTER_ADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"

# -----------------------------------------------------------------------------
# 1. RBAC DEPENDENCY (Strict Email Enforcement)
# -----------------------------------------------------------------------------
async def require_master_admin(current_user: User = Depends(get_current_user)) -> User:
    """
    Validates that the authenticated caller matches the master administrative email.
    Rejects any other authenticated user with HTTP 403 Forbidden.
    """
    if not current_user.is_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access Denied: Restricted to ASI Verticals Master Admin portal."
        )
    return current_user

# -----------------------------------------------------------------------------
# 2. PYDANTIC SCHEMAS FOR ADMIN PORTAL
# -----------------------------------------------------------------------------
class KycStatsResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    pending_count: int
    verified_count: int
    rejected_count: int

class KycQueueItemResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    queue_id: int
    user_id: UUID
    registered_name: str
    registered_city: str
    extracted_transcript: str
    ai_confidence_score: float
    ai_flags: List[str]
    video_playback_url: str
    created_at: datetime

class KycReviewDecisionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    queue_id: int = Field(..., description="ID of the record in kyc_review_queue")
    user_id: UUID = Field(..., description="Target user UUID")
    decision: Literal["approve", "reject"] = Field(...)
    rejection_reason: Optional[str] = Field(None, max_length=250)

# -----------------------------------------------------------------------------
# 3. STATS ENDPOINT
# -----------------------------------------------------------------------------
@router.get("/stats", response_model=KycStatsResponse)
async def get_kyc_dashboard_stats(
    admin: User = Depends(require_master_admin),
    db: AsyncSession = Depends(get_db)
):
    """Returns aggregated real-time counts across verification states."""
    pending_query = select(func.count(KycReviewQueue.id)).where(KycReviewQueue.status == "unreviewed")
    verified_query = select(func.count(User.id)).where(and_(User.kyc_status == True, User.deleted_at.is_(None)))
    rejected_query = select(func.count(User.id)).where(and_(User.kyc_state == "rejected", User.deleted_at.is_(None)))

    pending_res = await db.execute(pending_query)
    verified_res = await db.execute(verified_query)
    rejected_res = await db.execute(rejected_query)

    return KycStatsResponse(
        pending_count=pending_res.scalar_one() or 0,
        verified_count=verified_res.scalar_one() or 0,
        rejected_count=rejected_res.scalar_one() or 0
    )

# -----------------------------------------------------------------------------
# 4. PENDING QUEUE ENDPOINT (WITH PRESIGNED VIDEO URLS)
# -----------------------------------------------------------------------------
@router.get("/queue", response_model=List[KycQueueItemResponse])
async def get_pending_kyc_queue(
    limit: int = Query(25, ge=1, le=100),
    offset: int = Query(0, ge=0),
    admin: User = Depends(require_master_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches unreviewed candidate profiles for human moderation.
    Generates a temporary 10-minute signed URL for secure video inspection.
    """
    stmt = (
        select(KycReviewQueue)
        .where(and_(KycReviewQueue.status == "unreviewed", KycReviewQueue.video_storage_path != "PURGED"))
        .order_by(KycReviewQueue.created_at.asc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    records = result.scalars().all()

    queue_items = []
    for item in records:
        playback_url = ""
        if item.video_storage_path and item.video_storage_path != "PURGED":
            try:
                # Generate 10-minute (600s) presigned ephemeral read URL from Supabase storage
                if supabase_storage_client:
                    res = supabase_storage_client.storage.from_("kyc-temp").create_signed_url(
                        path=item.video_storage_path,
                        expires_in=600
                    )
                    playback_url = res.get("signedURL") or res.get("signedUrl") or ""
            except Exception:
                playback_url = ""

        queue_items.append(
            KycQueueItemResponse(
                queue_id=item.id,
                user_id=item.user_id,
                registered_name=item.registered_name,
                registered_city=item.registered_city,
                extracted_transcript=item.extracted_transcript or "No transcript generated.",
                ai_confidence_score=float(item.ai_confidence_score or 0.0),
                ai_flags=item.ai_flags or [],
                video_playback_url=playback_url,
                created_at=item.created_at
            )
        )

    return queue_items

# -----------------------------------------------------------------------------
# 5. REVIEW DECISION & ATOMIC DPDP PURGE ENDPOINT
# -----------------------------------------------------------------------------
@router.post("/review-decision", status_code=status.HTTP_200_OK)
async def submit_review_decision(
    payload: KycReviewDecisionRequest,
    admin: User = Depends(require_master_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Applies admin manual override and immediately wipes the video asset
    from cloud storage to preserve compliance under Section 8(7) DPDP Act 2023.
    """
    # 1. Fetch queue entry
    stmt = select(KycReviewQueue).where(KycReviewQueue.id == payload.queue_id)
    res = await db.execute(stmt)
    queue_record = res.scalar_one_or_none()

    if not queue_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="KYC review queue record not found."
        )

    is_approval = (payload.decision == "approve")

    # 2. Update Target User Profile State
    user_update_stmt = (
        update(User)
        .where(User.id == payload.user_id)
        .values(
            kyc_status=is_approval,
            kyc_state="verified" if is_approval else "rejected",
            kyc_failure_reason=None if is_approval else (payload.rejection_reason or "Manual review rejection."),
            kyc_verified_at=datetime.now(timezone.utc) if is_approval else None
        )
    )
    await db.execute(user_update_stmt)

    # 3. Update Review Queue Entry
    queue_update_stmt = (
        update(KycReviewQueue)
        .where(KycReviewQueue.id == payload.queue_id)
        .values(
            status="approved" if is_approval else "rejected",
            reviewed_by=MASTER_ADMIN_EMAIL,
            rejection_reason=payload.rejection_reason if not is_approval else None,
            resolved_at=datetime.now(timezone.utc)
        )
    )
    await db.execute(queue_update_stmt)
    await db.commit()

    # 4. ATOMIC DATA MINIMIZATION PURGE
    # Hard-delete the video from Supabase storage regardless of decision outcome
    video_purged = await purge_kyc_video_from_storage(
        storage_path=queue_record.video_storage_path,
        user_id=payload.user_id,
        db=db
    )

    return {
        "status": "success",
        "decision": payload.decision,
        "queue_id": payload.queue_id,
        "user_id": str(payload.user_id),
        "video_purged_from_storage": video_purged,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
