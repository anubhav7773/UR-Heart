import uuid
from datetime import datetime, date
from typing import Optional, Dict, Any
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    BigInteger,
    String,
    Text,
    func,
    ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from app.core.database import Base


def generate_grievance_ref() -> str:
    return f"GRV-{datetime.utcnow().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"


class DataExportRequest(Base):
    __tablename__ = "data_export_requests"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(String(30), nullable=False, default="pending")
    export_url = Column(Text, nullable=True)
    export_payload = Column(JSONB, nullable=True)
    checksum_sha256 = Column(String(64), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class DataNominee(Base):
    __tablename__ = "data_nominees"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    user_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), primary_key=True)
    nominee_name = Column(String(60), nullable=False)
    nominee_contact = Column(String(30), nullable=False)
    relationship = Column(String(30), nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class GrievanceDossier(Base):
    __tablename__ = "grievance_dossiers"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    dossier_reference_id = Column(String(32), unique=True, nullable=False, default=generate_grievance_ref)
    reporter_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    reported_user_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    violation_category = Column(String(50), nullable=False)
    evidence_text = Column(String(500), nullable=False, default="")
    status = Column(String(30), nullable=False, default="under_review")
    acknowledgment_sent_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    statutory_resolution_due_at = Column(DateTime(timezone=True), nullable=False)
    resolution_summary = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actioned_at = Column(DateTime(timezone=True), nullable=True)


class UnderageQuarantineRegistry(Base):
    __tablename__ = "underage_quarantine_registry"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_hash = Column(String(64), nullable=False, index=True)
    attempted_dob = Column(Date, nullable=False)
    quarantine_until = Column(DateTime(timezone=True), nullable=False)
    attempt_metadata = Column(JSONB, nullable=False, default=dict)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class ConsentAuditLog(Base):
    __tablename__ = "consent_audit_logs"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    consent_purpose_id = Column(String(50), nullable=False)
    is_granted = Column(Boolean, nullable=False, default=True)
    ip_hash = Column(String(64), nullable=False)
    installation_uuid = Column(String(64), nullable=False)
    consented_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class BlockedUser(Base):
    __tablename__ = "blocked_users"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    blocker_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    blocked_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    reason = Column(String(100), nullable=True, default="unspecified")
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
