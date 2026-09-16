from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, Request, HTTPException, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.rate_limiter import limiter
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_report import UserReport
from app.core.legal_audit import record_legal_audit_event

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
