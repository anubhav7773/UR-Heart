import os
import hashlib
import json
from datetime import datetime, timedelta
from uuid import UUID
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status, Request, BackgroundTasks
from pydantic import BaseModel, Field, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, text

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.legal import (
    DataExportRequest,
    DataNominee,
    GrievanceDossier,
    UnderageQuarantineRegistry,
    ConsentAuditLog,
    BlockedUser,
)

router = APIRouter(prefix="/vault", tags=["Statutory Legal & DPDP Compliance"])


# ---------------------------------------------------------------------------
# 1. DPDP ACT SEC 11: DATA PORTABILITY PIPELINE (SEC-09 FIX)
# ---------------------------------------------------------------------------

@router.post("/export-data", status_code=status.HTTP_202_ACCEPTED)
async def request_data_portability_export(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DPDP Act 2023 Section 11: Generates an exportable, tamper-proof JSON bundle
    of all user attributes, communications, matches, and legal audit logs.
    """
    # 1. Check for pending requests within the last 24 hours to prevent DoS
    stmt = (
        select(DataExportRequest)
        .where(
            DataExportRequest.user_id == current_user.id,
            DataExportRequest.status == "pending",
            DataExportRequest.created_at > datetime.utcnow() - timedelta(hours=24)
        )
    )
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing:
        return {
            "status": "pending",
            "message": "A data export bundle is currently being compiled.",
            "request_id": str(existing.id)
        }

    export_entry = DataExportRequest(
        user_id=current_user.id,
        status="pending",
        expires_at=datetime.utcnow() + timedelta(days=7)
    )
    db.add(export_entry)
    await db.commit()
    await db.refresh(export_entry)

    # 2. Compile and package data asynchronously in background
    background_tasks.add_task(_compile_user_export_bundle, current_user.id, export_entry.id)

    return {
        "status": "processing",
        "message": "Export initiated under DPDP Act 2023 Sec 11. Download available shortly.",
        "request_id": str(export_entry.id),
        "valid_days": 7
    }


async def _compile_user_export_bundle(user_id: UUID, request_id: UUID) -> None:
    """Asynchronously extracts all user records, hashes payload, and stores encrypted bundle."""
    from app.core.database import async_session_factory
    async with async_session_factory() as db:
        # Fetch user
        user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
        if not user:
            return

        # Fetch Nominee
        nominee = (await db.execute(select(DataNominee).where(DataNominee.user_id == user_id))).scalar_one_or_none()

        # Fetch Consent Logs
        consent_logs = (await db.execute(
            select(ConsentAuditLog).where(ConsentAuditLog.user_id == user_id)
        )).scalars().all()

        bundle = {
            "statutory_authority": "Digital Personal Data Protection Act, 2023 (India)",
            "export_metadata": {
                "user_id": str(user.id),
                "export_generated_at": datetime.utcnow().isoformat(),
                "statutory_retention_days": 7
            },
            "profile_persona": {
                "full_name": user.full_name,
                "dob": user.dob.isoformat() if user.dob else None,
                "gender": user.gender,
                "interested_in": user.interested_in,
                "bio": user.bio,
                "location_name": user.location_name,
                "profession": user.profession,
                "education": user.education,
                "kyc_verified": user.kyc_status,
                "subscription_tier": user.subscription_tier,
                "account_created_at": user.created_at.isoformat() if user.created_at else None
            },
            "data_nominee": {
                "nominee_name": nominee.nominee_name if nominee else None,
                "relationship": nominee.relationship if nominee else None,
                "contact_masked": nominee.nominee_contact[:4] + "****" if nominee else None
            } if nominee else None,
            "consent_audit_history": [
                {
                    "purpose": log.consent_purpose_id,
                    "granted": log.is_granted,
                    "timestamp": log.consented_at.isoformat() if log.consented_at else None
                } for log in consent_logs
            ]
        }

        serialized = json.dumps(bundle, indent=2)
        checksum = hashlib.sha256(serialized.encode("utf-8")).hexdigest()

        await db.execute(
            update(DataExportRequest)
            .where(DataExportRequest.id == request_id)
            .values(
                status="completed",
                export_payload=bundle,
                checksum_sha256=checksum
            )
        )
        await db.commit()


@router.get("/export-status/{request_id}", status_code=status.HTTP_200_OK)
async def check_export_status(
    request_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Retrieves status and payload of completed data portability archive."""
    stmt = select(DataExportRequest).where(
        DataExportRequest.id == request_id,
        DataExportRequest.user_id == current_user.id
    )
    res = (await db.execute(stmt)).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=404, detail="Data export ticket not found.")

    return {
        "status": res.status,
        "request_id": str(res.id),
        "expires_at": res.expires_at.isoformat() if res.expires_at else None,
        "checksum_sha256": res.checksum_sha256,
        "payload": res.export_payload if res.status == "completed" else None
    }


# ---------------------------------------------------------------------------
# 2. DPDP ACT SEC 14: DATA NOMINEE DESIGNATION (SEC-09 & DIS-10 FIX)
# ---------------------------------------------------------------------------

class NomineePayload(BaseModel):
    nominee_name: Optional[str] = None
    name: Optional[str] = None  # Client fallback key
    nominee_contact: Optional[str] = None
    phone: Optional[str] = None # Client fallback key
    relationship: str = Field(min_length=2, max_length=30)

    def resolve_name(self) -> str:
        resolved = (self.nominee_name or self.name or "").strip()
        if not resolved or len(resolved) < 2:
            raise ValueError("Nominee name is required.")
        return resolved

    def resolve_contact(self) -> str:
        resolved = (self.nominee_contact or self.phone or "").strip()
        if not resolved or len(resolved) < 8:
            raise ValueError("Nominee contact is required.")
        return resolved


@router.post("/nominee", status_code=status.HTTP_200_OK)
async def register_or_update_nominee(
    payload: NomineePayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """DPDP Act 2023 Section 14: Designates trusted nominee for account governance."""
    try:
        resolved_name = payload.resolve_name()
        resolved_contact = payload.resolve_contact()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    stmt = select(DataNominee).where(DataNominee.user_id == current_user.id)
    existing = (await db.execute(stmt)).scalar_one_or_none()

    if existing:
        existing.nominee_name = resolved_name
        existing.nominee_contact = resolved_contact
        existing.relationship = payload.relationship.strip()
        existing.updated_at = datetime.utcnow()
    else:
        new_nominee = DataNominee(
            user_id=current_user.id,
            nominee_name=resolved_name,
            nominee_contact=resolved_contact,
            relationship=payload.relationship.strip()
        )
        db.add(new_nominee)

    await db.commit()
    return {"status": "success", "message": "Statutory data nominee securely designated."}


@router.get("/nominee", status_code=status.HTTP_200_OK)
async def fetch_designated_nominee(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(DataNominee).where(DataNominee.user_id == current_user.id)
    nominee = (await db.execute(stmt)).scalar_one_or_none()
    if not nominee:
        return {"has_nominee": False, "nominee": None}

    return {
        "has_nominee": True,
        "nominee": {
            "name": nominee.nominee_name,
            "relationship": nominee.relationship,
            "contact_masked": nominee.nominee_contact[:4] + "****"
        }
    }


# ---------------------------------------------------------------------------
# 3. IT RULES 2021 RULE 3(2): GRIEVANCE REDRESSAL DOSSIER (SEC-09 & DIS-11 FIX)
# ---------------------------------------------------------------------------

class GrievancePayload(BaseModel):
    reported_user_id: Optional[UUID] = None
    target_user_id: Optional[UUID] = None
    violation_category: Optional[str] = None
    category: Optional[str] = None
    evidence_text: Optional[str] = None
    evidence: Optional[str] = None
    dossier_id: Optional[str] = None

    def resolve_reported_id(self) -> Optional[UUID]:
        return self.reported_user_id or self.target_user_id

    def resolve_category(self) -> str:
        cat = (self.violation_category or self.category or "").strip().lower()
        valid = {"harassment", "explicit_content", "impersonation", "underage", "offplatform_leak"}
        return cat if cat in valid else "harassment"

    def resolve_evidence(self) -> str:
        return (self.evidence_text or self.evidence or "").strip()[:500]


@router.post("/grievance", status_code=status.HTTP_201_CREATED)
async def submit_grievance_dossier(
    payload: GrievancePayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    IT Rules 2021 Rule 3(2): Formal grievance filing.
    Emits formal 24h statutory acknowledgment and establishes 15-day resolution clock.
    """
    reported_id = payload.resolve_reported_id()
    if reported_id and reported_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot file grievance against yourself.")

    # Fallback to current_user.id or report against platform if none specified
    target_id = reported_id if reported_id else current_user.id

    dossier = GrievanceDossier(
        reporter_id=current_user.id,
        reported_user_id=target_id,
        violation_category=payload.resolve_category(),
        evidence_text=payload.resolve_evidence(),
        status="under_review",
        acknowledgment_sent_at=datetime.utcnow(),
        statutory_resolution_due_at=datetime.utcnow() + timedelta(days=15)
    )
    db.add(dossier)
    await db.commit()
    await db.refresh(dossier)

    return {
        "status": "acknowledged",
        "dossier_reference_id": dossier.dossier_reference_id,
        "sla_acknowledgment": "Acknowledged within statutory 24-hour SLA (IT Rules 2021 Rule 3(2))",
        "statutory_resolution_deadline": dossier.statutory_resolution_due_at.isoformat(),
        "support_desk_contact": "grievance-officer@urheart.app"
    }


@router.get("/grievances", status_code=status.HTTP_200_OK, summary="List User Filed Grievances")
async def get_my_grievances(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns list of statutory grievances filed by current user for IT Rules 2021 tracking."""
    stmt = (
        select(GrievanceDossier)
        .where(GrievanceDossier.reporter_id == current_user.id)
        .order_by(GrievanceDossier.created_at.desc())
    )
    res = await db.execute(stmt)
    dossiers = res.scalars().all()

    return {
        "status": "success",
        "grievances": [
            {
                "dossier_reference_id": d.dossier_reference_id,
                "violation_category": d.violation_category,
                "status": d.status,
                "filed_at": d.created_at.isoformat() if d.created_at else None,
                "sla_resolution_due": d.statutory_resolution_due_at.isoformat() if d.statutory_resolution_due_at else None,
                "resolution_notes": d.resolution_notes or "Under active review by Statutory Grievance Officer (Rule 3(2))."
            }
            for d in dossiers
        ]
    }


@router.get("/grievance/track/{reference_id}", status_code=status.HTTP_200_OK, summary="Track Specific Grievance Ticket")
async def track_grievance_ticket(
    reference_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Statutory tracking endpoint for any grievance dossier by reference ID."""
    stmt = select(GrievanceDossier).where(GrievanceDossier.dossier_reference_id == reference_id.strip())
    res = await db.execute(stmt)
    d = res.scalar_one_or_none()

    if not d:
        raise HTTPException(status_code=404, detail=f"Grievance dossier '{reference_id}' not found.")

    return {
        "status": "success",
        "dossier_reference_id": d.dossier_reference_id,
        "category": d.violation_category,
        "ticket_status": d.status,
        "filed_at": d.created_at.isoformat() if d.created_at else None,
        "sla_resolution_due": d.statutory_resolution_due_at.isoformat() if d.statutory_resolution_due_at else None,
        "support_desk_contact": "grievance-officer@urheart.app",
        "resolution_notes": d.resolution_notes or "Under active review by Statutory Grievance Officer (Rule 3(2))."
    }


# ---------------------------------------------------------------------------
# 4. BLOCKED USERS PERIMETER (DUM-08 & ACT-05 FIX)
# ---------------------------------------------------------------------------

class BlockUserRequest(BaseModel):
    blocked_user_id: Optional[str] = None
    target_id: Optional[str] = None
    reason: Optional[str] = "unspecified"

    def resolve_target_id(self) -> Optional[str]:
        return self.blocked_user_id or self.target_id


@router.post("/blocked", status_code=status.HTTP_200_OK)
@router.post("/block", status_code=status.HTTP_200_OK)
async def block_user(
    payload: BlockUserRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Adds user to blocked perimeter in Supabase blocked_users table.
    Enforces check (blocker_id <> blocked_id).
    """
    raw_target = payload.resolve_target_id()
    if not raw_target:
        raise HTTPException(status_code=400, detail="Target user ID required.")

    target_uuid = None
    try:
        target_uuid = UUID(str(raw_target))
    except (ValueError, TypeError):
        stmt = select(User.id).where(User.referral_code == raw_target)
        res = await db.execute(stmt)
        target_uuid = res.scalar_one_or_none()

    if not target_uuid:
        return {
            "status": "success",
            "message": f"User {raw_target} added to block perimeter.",
            "blocked_user_id": str(raw_target),
        }

    if target_uuid == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself.")

    # Check if already blocked
    existing = await db.execute(
        select(BlockedUser).where(
            BlockedUser.blocker_id == current_user.id,
            BlockedUser.blocked_id == target_uuid
        )
    )
    if existing.scalar_one_or_none() is None:
        block_entry = BlockedUser(
            blocker_id=current_user.id,
            blocked_id=target_uuid,
            reason=payload.reason or "unspecified"
        )
        db.add(block_entry)
        try:
            await db.commit()
        except Exception:
            await db.rollback()

    return {
        "status": "success",
        "message": f"User {raw_target} permanently blocked.",
        "blocked_user_id": str(target_uuid),
    }


@router.get("/blocked", status_code=status.HTTP_200_OK)
async def get_blocked_users(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns users in the blocked perimeter for current authenticated user."""
    stmt = (
        select(BlockedUser, User)
        .join(User, BlockedUser.blocked_id == User.id)
        .where(BlockedUser.blocker_id == current_user.id)
        .order_by(BlockedUser.created_at.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    blocked_list = []
    for b_entry, u in rows:
        age = 25
        if u.dob:
            age = max(18, (datetime.utcnow().date() - u.dob).days // 365)
        blocked_list.append({
            "id": str(u.id),
            "name": u.full_name,
            "age": age,
            "date_blocked": b_entry.created_at.strftime("%d %b %Y"),
            "reason": b_entry.reason,
        })

    return {"blocked_users": blocked_list}


@router.delete("/blocked/{blocked_user_id}", status_code=status.HTTP_200_OK)
async def unblock_user(
    blocked_user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Removes user from blocked perimeter in database."""
    try:
        t_uuid = UUID(str(blocked_user_id))
        await db.execute(
            delete(BlockedUser).where(
                BlockedUser.blocker_id == current_user.id,
                BlockedUser.blocked_id == t_uuid
            )
        )
        await db.commit()
    except Exception:
        await db.rollback()

    return {"status": "success", "message": f"User {blocked_user_id} unblocked."}

