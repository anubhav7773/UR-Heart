from datetime import datetime
from uuid import UUID
from typing import Optional
from sqlalchemy import String, Integer, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, INET
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class LegalAuditLog(Base):
    __tablename__ = "legal_audit_logs"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[UUID]] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
    action_type: Mapped[str] = mapped_column(String(50), nullable=False)
    ip_address: Mapped[str] = mapped_column(INET, nullable=False)
    client_port: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    user_agent: Mapped[str] = mapped_column(Text, nullable=False)
    installation_uuid: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
