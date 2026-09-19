from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from uuid import UUID
from datetime import datetime, timezone
from app.core.database import get_db
from app.api.dependencies import require_master_admin
from app.models.domain.user import User

router = APIRouter()

@router.get("/crpc-91-dossier/{target_user_id}", status_code=status.HTTP_200_OK)
async def generate_crpc_91_compliance_dossier(
    target_user_id: UUID,
    admin: User = Depends(require_master_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Statutory Section 91 CrPC Law Enforcement Compliance Dossier.
    Exports immutable audit logs, IP history, and device identifiers within 72 hours of notice.
    """
    # 1. Fetch user identity records
    user_stmt = select(User).where(User.id == target_user_id)
    user_res = await db.execute(user_stmt)
    target_user = user_res.scalar_one_or_none()

    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found.")

    # 2. Fetch immutable legal audit logs
    logs_stmt = select(
        text("id, partner_id, action_type, ip_address, device_id, user_agent, event_metadata, created_at")
    ).select_from(text("public.legal_audit_logs")).where(
        text("user_id = :uid")
    ).order_by(text("created_at ASC"))
    
    logs_res = await db.execute(logs_stmt, {"uid": target_user_id})
    raw_logs = logs_res.mappings().all()

    audit_records = [
        {
            "log_id": r["id"],
            "action_type": r["action_type"],
            "partner_id": str(r["partner_id"]) if r["partner_id"] else None,
            "ip_address": r["ip_address"],
            "device_id": r["device_id"],
            "user_agent": r["user_agent"],
            "metadata": r["event_metadata"],
            "timestamp_utc": r["created_at"].isoformat()
        }
        for r in raw_logs
    ]

    # 3. Format Statutory Dossier
    return {
        "statutory_header": {
            "issuing_entity": "UR-Heart Intermediary Grievance & Legal Division (ASI Verticals)",
            "statutory_mandate": "Compliance with Section 91 CrPC / Rule 3(1)(n) IT Rules 2021 (72-Hour Response Window)",
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "target_user_id": str(target_user.id),
            "phone_registered": target_user.phone_number,
            "full_name": target_user.full_name,
            "account_status": "FROZEN" if target_user.is_frozen else ("BANNED" if target_user.is_banned else "ACTIVE"),
            "is_kyc_verified": target_user.kyc_status
        },
        "total_audit_events": len(audit_records),
        "audit_trail": audit_records
    }
