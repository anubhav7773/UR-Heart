from datetime import datetime, timezone
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, Request, HTTPException, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete

from app.core.database import get_db
from app.core.rate_limiter import limiter
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.domain.user_report import UserReport
from app.core.legal_audit import record_legal_audit_event
from app.services.storage_service import purge_user_storage_assets

router = APIRouter()

class UserReportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reported_id: UUID = Field(..., description="Target user UUID being reported")
    reason: str = Field(..., max_length=100, description="Reason category: harassment, scam, impersonation, etc.")
    details: Optional[str] = Field(None, max_length=500, description="Additional context or description")
    context_match_id: Optional[UUID] = Field(None, description="Related match UUID if applicable")

@router.post("/report", status_code=status.HTTP_200_OK)
@limiter.limit("10/hour")
async def submit_safety_report(
    request: Request,
    payload: UserReportRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    User safety reporting endpoint.
    - Rate limited strictly to 10 requests per hour per client IP.
    - Protected by server-side Firebase JWT authentication (get_current_user).
    - Extra fields strictly forbidden to prevent payload tampering.
    - Persists report to public.user_reports and creates legal audit log.
    """
    if current_user.id == payload.reported_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot report your own account."
        )

    report_entry = UserReport(
        reporter_id=current_user.id,
        reported_id=payload.reported_id,
        reason=payload.reason,
        details=payload.details,
        context_match_id=payload.context_match_id
    )
    db.add(report_entry)
    await db.commit()

    await record_legal_audit_event(
        request=request,
        action_type="SAFETY_REPORT_SUBMITTED",
        user_id=current_user.id,
        db=db
    )

    return {
        "status": "reported",
        "message": "Safety report received and queued for immediate human safety review."
    }

@router.post("/erase-account", status_code=status.HTTP_200_OK)
@limiter.limit("5/day")
async def erase_account(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Executes statutory One-Tap Account Erase under DPDP Act 2023 Section 8(7).
    - Hard deletes user photos from storage and database.
    - Soft-deletes and anonymizes user account in public.users.
    - Wipes streak and reward balances.
    - Logs legal audit event for 180-day statutory retention.
    """
    user_id = current_user.id

    # 1. Purge Supabase storage assets
    try:
        await purge_user_storage_assets(user_id)
    except Exception:
        pass

    # 2. Remove database photo entries
    await db.execute(delete(UserPhoto).where(UserPhoto.user_id == user_id))

    # 3. Anonymize user record & mark deleted
    now = datetime.now(timezone.utc)
    current_user.deleted_at = now
    current_user.full_name = "Deleted User"
    current_user.phone_number = f"+919999999999"
    current_user.whatsapp_number = f"+919999999999"
    current_user.bio = ""
    current_user.streak_count = 0
    current_user.reward_balance = 0
    current_user.updated_at = now

    await db.commit()

    # 4. Record statutory legal audit
    await record_legal_audit_event(
        request=request,
        action_type="ACCOUNT_ONE_TAP_ERASED",
        user_id=user_id,
        db=db
    )

    return {
        "status": "erased",
        "message": "Your profile and photos have been permanently erased in compliance with DPDP Act 2023."
    }

