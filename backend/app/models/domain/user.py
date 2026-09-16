from datetime import date, datetime
from uuid import UUID, uuid4
from sqlalchemy import String, Boolean, Date, DateTime, Numeric, SmallInteger, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "public"}

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    phone_number: Mapped[str] = mapped_column(String(15), unique=True, nullable=False)
    whatsapp_number: Mapped[str] = mapped_column(String(15), nullable=False)
    full_name: Mapped[str] = mapped_column(String(50), nullable=False)
    dob: Mapped[date] = mapped_column(Date, nullable=False)
    gender: Mapped[str] = mapped_column(String(10), nullable=False)
    city: Mapped[str] = mapped_column(String(50), nullable=False)
    bio: Mapped[str] = mapped_column(String(250), default="")
    streak_count: Mapped[int] = mapped_column(SmallInteger, default=0)
    reward_balance: Mapped[int] = mapped_column(Integer, default=0)
    kyc_status: Mapped[bool] = mapped_column(Boolean, default=False)
    kyc_state: Mapped[str] = mapped_column(String(30), default="pending_ai")
    kyc_ai_confidence: Mapped[float] = mapped_column(Numeric(3, 2), nullable=True)
    kyc_transcript: Mapped[str] = mapped_column(Text, nullable=True)
    kyc_failure_reason: Mapped[str] = mapped_column(Text, nullable=True)
    kyc_verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    kyc_document_sha256: Mapped[str] = mapped_column(String(64), nullable=True)
    last_installation_uuid: Mapped[str] = mapped_column(String(64), nullable=True)
    is_super_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
