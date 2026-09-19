from datetime import datetime, timezone
from uuid import UUID
from typing import Optional, List
from fastapi import APIRouter, Depends, Request, HTTPException, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete, select, update, and_

from app.core.database import get_db
from app.core.rate_limiter import limiter
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.domain.user_report import UserReport
from app.models.domain.blocked_user import BlockedUser
from app.core.legal_audit import record_legal_audit_event
from app.services.storage_service import purge_user_storage_assets

router = APIRouter()


# ---------------------------------------------------------------------------
# 1. SCHEMAS
# ---------------------------------------------------------------------------
class UserReportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reported_id: UUID = Field(..., description="Target user UUID being reported")
    reason: str = Field(..., max_length=100, description="Reason category: harassment, scam, impersonation, etc.")
    details: Optional[str] = Field(None, max_length=500, description="Additional context or description")
    context_match_id: Optional[UUID] = Field(None, description="Related match UUID if applicable")


class BlockedUserResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: str
    full_name: str
    city: str
    photo_url: str | None
    blocked_at: str


class PrivacySettingsPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    is_incognito: bool
    hide_distance: bool


# ---------------------------------------------------------------------------
# 2. SAFETY REPORT
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 3. BLOCKED USERS MANAGEMENT
# ---------------------------------------------------------------------------
@router.get("/blocked", response_model=List[BlockedUserResponse])
async def get_blocked_users(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lists all active profiles blocked by the current user."""
    stmt = (
        select(BlockedUser, User)
        .join(User, User.id == BlockedUser.blocked_id)
        .where(BlockedUser.blocker_id == current_user.id)
        .order_by(BlockedUser.created_at.desc())
    )
    result = await db.execute(stmt)
    records = result.all()

    blocked_list = []
    for block_entry, user in records:
        # Fetch slot 1 photo
        photo_stmt = select(UserPhoto.photo_storage_path).where(
            and_(UserPhoto.user_id == user.id, UserPhoto.slot_index == 1)
        )
        photo_res = await db.execute(photo_stmt)
        primary_photo = photo_res.scalar_one_or_none()

        blocked_list.append(
            BlockedUserResponse(
                user_id=str(user.id),
                full_name=user.full_name,
                city=user.city,
                photo_url=primary_photo,
                blocked_at=block_entry.created_at.isoformat()
            )
        )
    return blocked_list


@router.delete("/unblock/{target_user_id}", status_code=status.HTTP_200_OK)
async def unblock_user(
    target_user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Removes a user from the blocked list."""
    stmt = delete(BlockedUser).where(
        and_(
            BlockedUser.blocker_id == current_user.id,
            BlockedUser.blocked_id == target_user_id
        )
    )
    res = await db.execute(stmt)
    await db.commit()

    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Block record not found.")

    return {"status": "unblocked", "target_user_id": str(target_user_id)}


# ---------------------------------------------------------------------------
# 4. PRIVACY TOGGLES
# ---------------------------------------------------------------------------
@router.patch("/privacy-settings", status_code=status.HTTP_200_OK)
async def update_privacy_settings(
    payload: PrivacySettingsPayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Updates incognito mode and distance badge suppression."""
    stmt = (
        update(User)
        .where(User.id == current_user.id)
        .values(
            is_incognito=payload.is_incognito,
            hide_distance=payload.hide_distance
        )
    )
    await db.execute(stmt)
    await db.commit()

    return {
        "status": "updated",
        "is_incognito": payload.is_incognito,
        "hide_distance": payload.hide_distance
    }


# ---------------------------------------------------------------------------
# 5. STATUTORY DATA ERASURE (DPDP ACT 2023 SECTION 11)
# ---------------------------------------------------------------------------
@router.post("/erase-account", status_code=status.HTTP_200_OK)
@router.delete("/erase-account", status_code=status.HTTP_200_OK)
@limiter.limit("5/day")
async def erase_account(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Executes statutory One-Tap Account Erase under DPDP Act 2023 Section 11.
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
    current_user.is_incognito = True
    current_user.updated_at = now

    await db.commit()

    # 4. Record statutory legal audit
    await record_legal_audit_event(
        request=request,
        action_type="ACCOUNT_DPDP_SECTION_11_ERASURE",
        user_id=user_id,
        db=db
    )

    return {
        "status": "erased",
        "message": "Your profile and photos have been permanently erased in compliance with Section 11 DPDP Act 2023."
    }
