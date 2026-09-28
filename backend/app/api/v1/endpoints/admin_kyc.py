from datetime import datetime, timezone
from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.dependencies import get_current_user
from app.core.config import get_settings
from app.core.database import get_db
from app.core.exceptions import ForbiddenException
from app.models.domain.kyc_escalation import AdminKycEscalation
from app.models.domain.user import User
from app.services.kyc_purge import purge_ephemeral_kyc_video

router = APIRouter(prefix="/admin/kyc", tags=["Superadmin KYC Sentinel"])
settings = get_settings()
SUPERADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"


def verify_superadmin_guard(user: User = Depends(get_current_user)) -> User:
    user_email = (getattr(user, "email", "") or "").strip().lower()
    user_role = getattr(user, "role", "user") or "user"
    if user_email != SUPERADMIN_EMAIL.lower():
        raise ForbiddenException("Access Denied: You do not possess Sanctuary Sovereign privileges. Access strictly restricted to the Sovereign Sanctuary Sentinel.")
    return user


class KycResolutionRequest(BaseModel):
    escalation_id: int
    user_id: UUID
    action: str  # "approve" or "reject"
    admin_notes: str = ""


class AdminKycQueueItem(BaseModel):
    id: int
    user_id: UUID
    declared_dob: str
    declared_age: int
    groq_match_score: int
    groq_reasoning: str
    anchor_photo_url: str
    kyc_video_url: str
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


@router.get("/escalations", response_model=List[AdminKycQueueItem], status_code=status.HTTP_200_OK)
@router.get("/pending-queue", response_model=List[AdminKycQueueItem], status_code=status.HTTP_200_OK)
async def list_pending_escalations(
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db)
):
    """
    Lists pending KYC escalations for human Sentinel review.
    Strictly locked to kshtriyaanubhav9120@gmail.com.
    """
    stmt = (
        select(AdminKycEscalation)
        .where(AdminKycEscalation.status == "pending")
        .order_by(AdminKycEscalation.created_at.asc())
        .limit(20)
    )
    result = await db.execute(stmt)
    records = result.scalars().all()
    return [
        AdminKycQueueItem(
            id=r.id,
            user_id=r.user_id,
            declared_dob=r.declared_dob.isoformat() if hasattr(r.declared_dob, "isoformat") else str(r.declared_dob),
            declared_age=r.declared_age,
            groq_match_score=r.groq_match_score,
            groq_reasoning=r.groq_reasoning,
            anchor_photo_url=r.anchor_photo_url,
            kyc_video_url=r.kyc_video_url,
            status=r.status,
            created_at=r.created_at
        )
        for r in records
    ]


@router.post("/resolve", status_code=status.HTTP_200_OK)
async def resolve_kyc_ticket(
    payload: KycResolutionRequest,
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db)
):
    """
    Resolves an escalated KYC ticket.
    Updates User.kyc_status, AdminKycEscalation status, and triggers hard-purge of ephemeral video.
    """
    is_approved = (payload.action == "approve")

    # 1. Update User Profile Status
    await db.execute(
        update(User)
        .where(User.id == payload.user_id)
        .values(kyc_status=is_approved)
    )

    # 2. Update Escalation Queue
    await db.execute(
        update(AdminKycEscalation)
        .where(AdminKycEscalation.id == payload.escalation_id)
        .values(
            status="approved" if is_approved else "rejected",
            reviewed_at=datetime.now(timezone.utc),
            reviewed_by=SUPERADMIN_EMAIL
        )
    )
    await db.commit()

    # 3. DPDP COMPLIANCE: Hard purge the ephemeral video immediately (<60s)
    purge_ephemeral_kyc_video(str(payload.user_id))

    return {
        "status": "resolved",
        "user_id": payload.user_id,
        "kyc_status": is_approved
    }
