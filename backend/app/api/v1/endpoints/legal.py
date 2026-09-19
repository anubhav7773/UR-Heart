from datetime import datetime, timezone, timedelta
import random
from typing import List, Optional, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.grievance_ticket import GrievanceTicket
from app.services.storage_service import supabase_storage_client

router = APIRouter()

# -----------------------------------------------------------------------------
# 1. SCHEMAS
# -----------------------------------------------------------------------------
class GrievanceOfficerInfoResponse(BaseModel):
    officer_name: str = "Anubhav Singh"
    designation: str = "Grievance Redressal Officer (Rule 3(2) IT Rules 2021)"
    entity_name: str = "ASI Verticals"
    email: str = "kshtriyaanubhav9120@gmail.com"
    physical_address: str = "ASI Verticals Legal Compliance Cell, Lucknow, Uttar Pradesh, India"
    acknowledgement_sla: str = "Within 24 Hours"
    resolution_sla: str = "Within 15 Days (72 Hours for NCII / Intimate Images)"

class GrievanceTicketResponse(BaseModel):
    model_config = ConfigDict(extra="ignore", from_attributes=True)
    ticket_number: str
    category: str
    description: str
    status: str
    created_at: datetime
    sla_acknowledgement_deadline: datetime
    sla_resolution_deadline: datetime
    resolution_notes: Optional[str] = None

# -----------------------------------------------------------------------------
# 2. STATUTORY OFFICER & LEGAL POLICIES ENDPOINTS
# -----------------------------------------------------------------------------
@router.get("/officer-details", response_model=GrievanceOfficerInfoResponse)
async def get_grievance_officer_details():
    """Returns statutory compliance details under Rule 3(2) IT Rules 2021."""
    return GrievanceOfficerInfoResponse()

@router.get("/policies/{policy_type}")
async def get_legal_policy(policy_type: Literal["privacy", "terms", "community_guidelines"]):
    """Returns canonical legal policy content."""
    policies = {
        "privacy": {
            "title": "DPDP Privacy Notice & Data Charter",
            "version": "1.3 (September 2026)",
            "content": (
                "UR-Heart operates under ASI Verticals. In accordance with the Digital Personal Data Protection Act, 2023 (DPDP), "
                "user geolocation is strictly obfuscated to city-level and approximate distances. "
                "Raw KYC verification video files are auto-purged following verification under Section 8(7). "
                "Users retain full Section 11 rights to erasure.\n\n"
                "5. THIRD-PARTY ADVERTISING NETWORKS & MONETIZATION\n"
                "We use third-party ad networks (Google AdMob, AppLovin) to monetize our platform. They may collect device identifiers and approximate location to serve targeted ads.\n\n"
                "Under Google Play Developer Policy and DPDP Act 2023:\n"
                "- We never share your real phone number, KYC documents, or real-time GPS coordinates with ad networks.\n"
                "- Only approximate (fuzzy) location and advertising identifiers are processed subject to your Google UMP consent choices.\n"
                "- You can revoke or modify your personalized ad tracking preferences at any time via Profile Settings > Ad Privacy & Tracking Preferences."
            )
        },
        "terms": {
            "title": "End User License Agreement (EULA)",
            "version": "1.0 (2026)",
            "content": "By accessing UR-Heart, you affirm that you are 18 years of age or older. Zero tolerance for harassment, hate speech, financial fraud, or non-consensual sharing of intimate images. Violators are subject to immediate permanent hardware banning and reporting to law enforcement."
        },
        "community_guidelines": {
            "title": "Safe Harbor & Zero Harassment Policy",
            "version": "1.0 (2026)",
            "content": "Authentic profiles only. Circumvention of anti-leak protection to distribute off-platform contacts maliciously triggers automated account suspension."
        }
    }
    return policies.get(policy_type, {})

# -----------------------------------------------------------------------------
# 3. GRIEVANCE TICKETING ENDPOINTS
# -----------------------------------------------------------------------------
@router.post("/grievance/file", status_code=status.HTTP_201_CREATED)
async def file_grievance_ticket(
    category: str = Form(...),
    description: str = Form(...),
    reported_user_id: Optional[str] = Form(None),
    evidence: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Submits a formal grievance ticket with optional screenshot evidence."""
    evidence_path = None
    if evidence:
        bytes_data = await evidence.read()
        if len(bytes_data) > 3 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Evidence file must be under 3 MB.")
        evidence_path = f"evidence/{current_user.id}_{int(datetime.now(timezone.utc).timestamp())}.jpg"
        if supabase_storage_client:
            try:
                supabase_storage_client.storage.from_("user-photos").upload(
                    path=evidence_path,
                    file=bytes_data,
                    file_options={"content-type": "image/jpeg", "upsert": "true"}
                )
            except Exception:
                pass

    # Special SLA: 72 hours for NCII under Rule 3(2)(b)
    resolution_delta = timedelta(hours=72) if category == 'ncii_nudity' else timedelta(days=15)
    now = datetime.now(timezone.utc)

    # Generate ticket number (URH-YYYYMMDD-XXXX)
    generated_ticket_number = f"URH-{now.strftime('%Y%m%d')}-{random.randint(1000, 9999)}"

    ticket = GrievanceTicket(
        ticket_number=generated_ticket_number,
        reporter_id=current_user.id,
        reported_user_id=UUID(reported_user_id) if (reported_user_id and reported_user_id.strip()) else None,
        category=category,
        description=description.strip(),
        evidence_storage_path=evidence_path,
        status="received",
        sla_acknowledgement_deadline=now + timedelta(hours=24),
        sla_resolution_deadline=now + resolution_delta,
        created_at=now,
        updated_at=now,
    )
    db.add(ticket)
    await db.commit()
    await db.refresh(ticket)

    return {
        "status": "ticket_created",
        "ticket_number": ticket.ticket_number,
        "acknowledgement_sla": "Within 24 Hours",
        "resolution_sla": "Within 72 Hours" if category == 'ncii_nudity' else "Within 15 Days"
    }

@router.get("/grievance/my-tickets", response_model=List[GrievanceTicketResponse])
async def get_my_grievance_tickets(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Retrieves user's filed grievance tickets with live SLA tracking."""
    stmt = (
        select(GrievanceTicket)
        .where(GrievanceTicket.reporter_id == current_user.id)
        .order_by(GrievanceTicket.created_at.desc())
    )
    res = await db.execute(stmt)
    tickets = res.scalars().all()
    return tickets
