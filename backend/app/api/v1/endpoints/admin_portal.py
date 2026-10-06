import os
from datetime import datetime, timezone
import json
from typing import Any, Dict, List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import desc, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.api.v1.endpoints.admin_kyc import verify_superadmin_guard
from app.core.database import get_db
from app.models.domain.audit_log import AdminAuditLog
from app.models.domain.in_app_purchase import InAppPurchase
from app.models.domain.kyc_escalation import AdminKycEscalation
from app.models.domain.user import User

router = APIRouter(prefix="/admin/portal", tags=["Superadmin Sanctuary Portal"])

# In-memory runtime configuration store (persists across requests during runtime)
SYSTEM_RUNTIME_CONFIG: Dict[str, Any] = {
    "maintenance_mode": False,
    "strict_ai_moderation": True,
    "ad_mediation_active": True,
    "kyc_auto_purge_days": 7,
    "max_daily_direct_letters": 5,
    "registration_open": True,
}


class BanRequest(BaseModel):
    reason: Optional[str] = "Administrative policy enforcement"


class KycUpdateRequest(BaseModel):
    is_verified: bool
    notes: Optional[str] = "Manual KYC determination by Superadmin"


class ConfigUpdateRequest(BaseModel):
    config: Dict[str, Any]


class AdminUserItem(BaseModel):
    id: UUID
    full_name: str
    email: Optional[str] = None
    role: str
    kyc_status: bool
    subscription_tier: str
    streak_count: int
    reward_balance: int
    is_banned: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AdminAuditLogItem(BaseModel):
    id: int
    admin_email: str
    action: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    details: Optional[str] = None
    ip_address: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


async def _record_audit_log(
    db: AsyncSession,
    admin_email: str,
    action: str,
    target_type: Optional[str] = None,
    target_id: Optional[str] = None,
    details: Optional[str] = None,
    ip_address: Optional[str] = None,
) -> None:
    """Helper to record an immutable audit log entry."""
    try:
        log_entry = AdminAuditLog(
            admin_email=admin_email,
            action=action,
            target_type=target_type,
            target_id=target_id,
            details=details,
            ip_address=ip_address,
        )
        db.add(log_entry)
        await db.commit()
    except Exception as e:
        await db.rollback()


class AdminLoginRequest(BaseModel):
    email: str
    secret_key: str


@router.post("/auth/login", status_code=status.HTTP_200_OK)
async def admin_portal_login(
    payload: AdminLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Direct Sovereign Authentication Gate:
    Validates secret key and issues signed JWT access token exclusively for asiverticals@gmail.com.
    """
    import uuid as _uuid
    from datetime import date, timedelta
    from app.core.config import get_settings
    from app.core.security import create_access_token

    settings = get_settings()
    clean_email = payload.email.strip().lower()

    # Gate 1: Email must be strictly asiverticals@gmail.com
    if clean_email != "asiverticals@gmail.com":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access Denied: Email is not authorized for Sovereign Sanctuary privileges."
        )

    # Gate 2: Master key verification (strictly from environment secrets in production)
    valid_keys = {
        getattr(settings, "SUPERADMIN_SECRET_KEY", "").strip(),
        (os.getenv("SUPERADMIN_SECRET_KEY") or "").strip(),
        (os.getenv("ADMIN_SECRET_KEY") or "").strip(),
        (os.getenv("ADMIN_KEY") or "").strip(),
        (os.getenv("ADMIN_ACCESS_KEY") or "").strip(),
        (os.getenv("SOVEREIGN_KEY") or "").strip(),
    }
    # In development/test only, support dev bootstrap key
    if getattr(settings, "ENVIRONMENT", "").lower() != "production":
        valid_keys.add("asiverticals_sovereign_sanctuary_2026")

    valid_keys.discard("")
    import secrets
    provided_key = payload.secret_key.strip() if payload.secret_key else ""
    is_valid = bool(provided_key and any(secrets.compare_digest(provided_key, vk) for vk in valid_keys if vk))
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Sovereign Secret Key."
        )

    # Resolve or create the admin user shell in the database
    res = await db.execute(select(User).where(User.email == clean_email))
    user = res.scalar_one_or_none()
    if not user:
        user = User(
            id=_uuid.uuid4(),
            auth_id=_uuid.uuid4(),
            full_name="Asi Verticals Sovereign",
            email=clean_email,
            role="superadmin",
            dob=date(1995, 1, 1),
            gender="Unspecified",
            interested_in="Everyone",
            contact_bridge_type="whatsapp",
            contact_bridge_encrypted="",
            referral_code=f"UR-{_uuid.uuid4().hex[:6].upper()}",
            is_profile_completed=True,
            kyc_status=True,
        )
        db.add(user)
        try:
            await db.commit()
            await db.refresh(user)
        except Exception:
            await db.rollback()
            res2 = await db.execute(select(User).where(User.email == clean_email))
            user = res2.scalar_one_or_none()
    elif user.role != "superadmin":
        user.role = "superadmin"
        await db.commit()

    token = create_access_token(
        data={"sub": str(user.auth_id if user else _uuid.uuid4()), "email": clean_email, "role": "superadmin"},
        expires_delta=timedelta(days=7)
    )

    client_ip = request.client.host if request.client else "unknown"
    await _record_audit_log(
        db=db,
        admin_email=clean_email,
        action="SOVEREIGN_PORTAL_LOGIN",
        target_type="admin_portal",
        target_id=str(user.id if user else "sovereign"),
        details="Sovereign admin portal login successful via master key",
        ip_address=client_ip
    )

    return {
        "status": "success",
        "access_token": token,
        "token_type": "bearer",
        "email": clean_email,
        "role": "superadmin"
    }


@router.get("/stats", status_code=status.HTTP_200_OK)
async def get_portal_stats(
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
) -> Dict[str, Any]:
    """Provides high-level sanctuary metrics and telemetry for the Superadmin Dashboard."""
    # 1. Total users
    res_users = await db.execute(select(func.count(User.id)))
    total_users = res_users.scalar() or 0

    # 2. Banned / deactivated users
    res_banned = await db.execute(select(func.count(User.id)).where(User.deleted_at.is_not(None)))
    banned_users = res_banned.scalar() or 0

    # 3. Active subscribers
    now = datetime.now(timezone.utc)
    res_subscribers = await db.execute(
        select(func.count(User.id)).where(
            User.subscription_tier != "free",
            User.subscription_expires_at > now,
            User.deleted_at.is_(None),
        )
    )
    active_subscribers = res_subscribers.scalar() or 0

    # 4. Pending KYC Escalations
    res_kyc = await db.execute(
        select(func.count(AdminKycEscalation.id)).where(AdminKycEscalation.status == "pending")
    )
    pending_kyc = res_kyc.scalar() or 0

    # 5. Financials (Total Net In-App Revenue)
    res_revenue = await db.execute(
        select(func.sum(InAppPurchase.amount_net)).where(InAppPurchase.status == "completed")
    )
    total_net_rev = res_revenue.scalar() or 0.0

    return {
        "status": "healthy",
        "superadmin": "asiverticals@gmail.com",
        "total_users": total_users,
        "active_users": max(0, total_users - banned_users),
        "banned_users": banned_users,
        "active_subscribers": active_subscribers,
        "pending_kyc_escalations": pending_kyc,
        "total_net_revenue_usd": float(total_net_rev),
        "server_time": now.isoformat(),
        "runtime_config": SYSTEM_RUNTIME_CONFIG,
    }


@router.get("/users", response_model=List[AdminUserItem], status_code=status.HTTP_200_OK)
async def list_sanctuary_users(
    search: Optional[str] = Query(None, description="Search by name or email"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    role: Optional[str] = Query(None, description="Filter by role"),
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
):
    """Paginated search & listing of sanctuary members for superadmin oversight."""
    stmt = select(User)

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        stmt = stmt.where(
            or_(
                func.lower(User.full_name).like(term),
                func.lower(User.email).like(term),
            )
        )

    if role and role.strip():
        stmt = stmt.where(User.role == role.strip())

    stmt = stmt.order_by(desc(User.created_at)).limit(limit).offset(offset)
    result = await db.execute(stmt)
    users = result.scalars().all()

    items = []
    for u in users:
        items.append(
            AdminUserItem(
                id=u.id,
                full_name=u.full_name,
                email=u.email,
                role=u.role,
                kyc_status=bool(u.kyc_status),
                subscription_tier=u.subscription_tier or "free",
                streak_count=u.streak_count or 0,
                reward_balance=u.reward_balance or 0,
                is_banned=u.deleted_at is not None,
                created_at=u.created_at,
            )
        )
    return items


@router.post("/users/{user_id}/ban", status_code=status.HTTP_200_OK)
async def ban_user(
    user_id: UUID,
    payload: BanRequest,
    request: Request,
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
):
    """Enforces administrative ban on a user account."""
    res = await db.execute(select(User).where(User.id == user_id))
    target = res.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    target.deleted_at = datetime.now(timezone.utc)
    await db.commit()

    client_ip = request.client.host if request.client else "unknown"
    await _record_audit_log(
        db=db,
        admin_email="asiverticals@gmail.com",
        action="USER_BAN",
        target_type="user",
        target_id=str(user_id),
        details=f"Reason: {payload.reason} | Target: {target.email or target.full_name}",
        ip_address=client_ip,
    )

    return {"status": "banned", "user_id": str(user_id), "reason": payload.reason}


@router.post("/users/{user_id}/unban", status_code=status.HTTP_200_OK)
async def unban_user(
    user_id: UUID,
    request: Request,
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
):
    """Restores access to a previously suspended user account."""
    res = await db.execute(select(User).where(User.id == user_id))
    target = res.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    target.deleted_at = None
    await db.commit()

    client_ip = request.client.host if request.client else "unknown"
    await _record_audit_log(
        db=db,
        admin_email="asiverticals@gmail.com",
        action="USER_UNBAN",
        target_type="user",
        target_id=str(user_id),
        details=f"Restored account: {target.email or target.full_name}",
        ip_address=client_ip,
    )

    return {"status": "unbanned", "user_id": str(user_id)}


@router.post("/users/{user_id}/set-kyc", status_code=status.HTTP_200_OK)
async def set_user_kyc(
    user_id: UUID,
    payload: KycUpdateRequest,
    request: Request,
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
):
    """Direct administrative override for user KYC badge status."""
    res = await db.execute(select(User).where(User.id == user_id))
    target = res.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    target.kyc_status = payload.is_verified
    await db.commit()

    client_ip = request.client.host if request.client else "unknown"
    await _record_audit_log(
        db=db,
        admin_email="asiverticals@gmail.com",
        action="USER_KYC_OVERRIDE",
        target_type="user",
        target_id=str(user_id),
        details=f"kyc_status set to {payload.is_verified}. Notes: {payload.notes}",
        ip_address=client_ip,
    )

    return {"status": "updated", "user_id": str(user_id), "kyc_status": payload.is_verified}


@router.get("/audit-logs", response_model=List[AdminAuditLogItem], status_code=status.HTTP_200_OK)
async def get_audit_logs(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
):
    """Streams immutable forensic audit logs of administrative actions."""
    stmt = (
        select(AdminAuditLog)
        .order_by(desc(AdminAuditLog.created_at))
        .limit(limit)
        .offset(offset)
    )
    res = await db.execute(stmt)
    logs = res.scalars().all()
    return logs


@router.get("/config", status_code=status.HTTP_200_OK)
async def get_system_config(
    admin: User = Depends(verify_superadmin_guard),
) -> Dict[str, Any]:
    """Retrieves current platform runtime configuration and security flags."""
    return {
        "status": "success",
        "superadmin_email": "asiverticals@gmail.com",
        "config": SYSTEM_RUNTIME_CONFIG,
    }


@router.put("/config", status_code=status.HTTP_200_OK)
async def update_system_config(
    payload: ConfigUpdateRequest,
    request: Request,
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db),
) -> Dict[str, Any]:
    """Updates runtime configuration flags with mandatory audit trail."""
    client_ip = request.client.host if request.client else "unknown"
    old_state = json.dumps(SYSTEM_RUNTIME_CONFIG)

    for k, v in payload.config.items():
        if k in SYSTEM_RUNTIME_CONFIG:
            SYSTEM_RUNTIME_CONFIG[k] = v

    await _record_audit_log(
        db=db,
        admin_email="asiverticals@gmail.com",
        action="CONFIG_UPDATE",
        target_type="system_config",
        details=f"Old: {old_state} -> New: {json.dumps(SYSTEM_RUNTIME_CONFIG)}",
        ip_address=client_ip,
    )

    return {
        "status": "success",
        "updated_config": SYSTEM_RUNTIME_CONFIG,
    }
