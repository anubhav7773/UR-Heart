from datetime import date, datetime
from sqlalchemy import (
    BigInteger,
    Column,
    Date,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    Text,
    func
)
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class AdminKycEscalation(Base):
    __tablename__ = "admin_kyc_escalations"
    __table_args__ = {"schema": "public"}

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False
    )
    declared_dob = Column(Date, nullable=False)
    declared_age = Column(SmallInteger, nullable=False)
    groq_match_score = Column(SmallInteger, nullable=False)
    groq_reasoning = Column(String(255), nullable=False)
    anchor_photo_url = Column(Text, nullable=False)
    kyc_video_url = Column(Text, nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    reviewed_by = Column(String(80), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
