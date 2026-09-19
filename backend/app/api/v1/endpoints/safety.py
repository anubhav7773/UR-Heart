from datetime import datetime, timezone
from uuid import UUID
from typing import Optional, List
from fastapi import APIRouter, Depends, Request, HTTPException, status
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete, select, update, and_, text, func

from app.core.database import get_db
from app.core.rate_limiter import limiter
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.domain.user_report import UserReport
from app.models.domain.blocked_user import BlockedUser
from app.core.legal_audit import record_legal_audit_event
from app.services.storage_service import purge_user_storage_assets
from app.services.websocket_manager import chat_manager

router = APIRouter()
STRIKE_THRESHOLD = 3  # 3 distinct reports trigger automated account freeze


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


@router.post("/report-user", status_code=status.HTTP_200_OK)
async def report_violating_user(
    payload: dict,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits a violation report against another user.
    Enforces 3-strike automated bannery: 3 distinct reports auto-freeze the offending account.
    """
    target_user_id_str = payload.get("target_user_id")
    reason = payload.get("reason", "harassment_or_abuse")
    details = payload.get("details", "")

    if not target_user_id_str:
        raise HTTPException(status_code=400, detail="Missing target_user_id.")

    try:
        target_user_id = UUID(str(target_user_id_str))
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid target_user_id format.")

    if target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot report your own account.")

    # 1. Capture Client IP and Device ID for statutory compliance
    client_ip = request.headers.get("x-forwarded-for") or (request.client.host if request.client else "0.0.0.0")
    if "," in client_ip:
        client_ip = client_ip.split(",")[0].strip()
    device_id = request.headers.get("x-device-id", "unknown-device")
    user_agent = request.headers.get("user-agent", "")

    # 2. Insert report and log to legal_audit_logs
    await db.execute(
        text("""
            INSERT INTO public.user_safety_reports (reporter_id, reported_user_id, report_type, message_content_snapshot)
            VALUES (:rep_id, :target_id, :rtype, :snap)
        """),
        {"rep_id": current_user.id, "target_id": target_user_id, "rtype": reason, "snap": details}
    )

    clean_reason = reason.replace('"', '\\"')
    await db.execute(
        text("""
            INSERT INTO public.legal_audit_logs (user_id, partner_id, action_type, ip_address, device_id, user_agent, event_metadata)
            VALUES (:uid, :pid, 'report_filed', :ip, :dev, :ua, CAST(:meta AS jsonb))
        """),
        {
            "uid": current_user.id,
            "pid": target_user_id,
            "ip": client_ip,
            "dev": device_id,
            "ua": user_agent,
            "meta": '{"reason": "' + clean_reason + '"}'
        }
    )

    # 3. Calculate distinct reporters count for target user
    count_stmt = select(func.count(func.distinct(text("reporter_id")))).select_from(
        text("public.user_safety_reports")
    ).where(text("reported_user_id = :tid"))
    
    count_res = await db.execute(count_stmt, {"tid": target_user_id})
    distinct_reports = count_res.scalar() or 0

    # 4. Check 3-strike threshold
    account_frozen = False
    if distinct_reports >= STRIKE_THRESHOLD:
        account_frozen = True
        # Automated Bannery: Freeze account, ban profile, and purge live session
        await db.execute(
            update(User)
            .where(User.id == target_user_id)
            .values(
                is_frozen=True,
                is_banned=True,
                report_count=distinct_reports,
                frozen_at=datetime.now(timezone.utc),
                freeze_reason=f"Automated Bannery: {distinct_reports} distinct violation reports received."
            )
        )

        # Log freeze event in legal audit trail
        await db.execute(
            text("""
                INSERT INTO public.legal_audit_logs (user_id, partner_id, action_type, ip_address, device_id, user_agent, event_metadata)
                VALUES (:uid, NULL, 'account_frozen', :ip, :dev, :ua, CAST(:meta AS jsonb))
            """),
            {
                "uid": target_user_id,
                "ip": client_ip,
                "dev": device_id,
                "ua": user_agent,
                "meta": '{"distinct_reports": ' + str(distinct_reports) + '}'
            }
        )

        # Terminate live WebSocket connection if active
        try:
            chat_manager.disconnect(str(target_user_id))
        except Exception:
            pass
    else:
        await db.execute(
            update(User)
            .where(User.id == target_user_id)
            .values(report_count=distinct_reports)
        )

    await db.commit()

    return {
        "status": "success",
        "message": "Report logged and evaluated.",
        "distinct_reports": distinct_reports,
        "account_frozen": account_frozen
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


@router.post("/report-and-block", status_code=status.HTTP_200_OK)
async def report_and_block_user(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    If a recipient reports an unsolicited direct DM, automatically suspend
    the sender's direct DM capability immediately and log the report.
    """
    reported_user_id_str = payload.get("reported_user_id")
    report_type = payload.get("report_type", "direct_dm_abuse")
    message_snippet = payload.get("message_snippet", "")

    if not reported_user_id_str:
        raise HTTPException(status_code=400, detail="Missing reported_user_id.")

    try:
        reported_user_id = UUID(reported_user_id_str)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid reported_user_id format.")

    # 1. Log safety report
    await db.execute(
        text("""
            INSERT INTO public.user_safety_reports (reporter_id, reported_user_id, report_type, message_content_snapshot)
            VALUES (:rep_id, :target_id, :rtype, :snap)
        """),
        {
            "rep_id": current_user.id,
            "target_id": reported_user_id,
            "rtype": report_type,
            "snap": message_snippet
        }
    )

    # 2. Immediate Block Action: Auto-ban sender from Direct DMs
    await db.execute(
        update(User)
        .where(User.id == reported_user_id)
        .values(
            is_dm_banned=True,
            dm_banned_at=func.now()
        )
    )

    # 3. Create mutual block to prevent further interactions
    try:
        await db.execute(
            text("""
                INSERT INTO public.blocks (blocker_id, blocked_id)
                VALUES (:b1, :b2)
                ON CONFLICT DO NOTHING
            """),
            {"b1": current_user.id, "b2": reported_user_id}
        )
    except Exception:
        pass

    try:
        await db.execute(
            text("""
                INSERT INTO public.blocked_users (blocker_id, blocked_id)
                VALUES (:b1, :b2)
            """),
            {"b1": current_user.id, "b2": reported_user_id}
        )
    except Exception:
        pass

    await db.commit()

    return {
        "status": "success",
        "action": "user_blocked_and_dm_banned",
        "message": "User has been blocked. Direct DM privileges for the reported user have been frozen."
    }

