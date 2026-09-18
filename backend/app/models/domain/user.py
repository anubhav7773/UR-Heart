from datetime import date, datetime
from uuid import UUID as PyUUID, uuid4
from sqlalchemy import Column, String, Boolean, Date, Integer, Numeric, Text, DateTime, CheckConstraint, TypeDecorator
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.core.database import Base

class CoerceDate(TypeDecorator):
    """Safely coerces ISO date strings (e.g. '2000-01-01') or date objects for asyncpg."""
    impl = Date
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if isinstance(value, str):
            return date.fromisoformat(value)
        return value

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4, server_default=func.gen_random_uuid())
    firebase_uid = Column(String(128), unique=True, nullable=False, index=True)
    phone_number = Column(String(15), unique=True, nullable=False)
    whatsapp_number = Column(String(15), nullable=False)
    full_name = Column(String(50), nullable=False)
    dob = Column(CoerceDate, nullable=False)
    gender = Column(String(10), nullable=False)  # 'male', 'female', 'lgbtq+'
    city = Column(String(50), nullable=False)
    bio = Column(String(250), default="")
    
    # Spatial Attributes (Protected, never sent in discovery responses)
    latitude = Column(Numeric(9, 6), nullable=True)
    longitude = Column(Numeric(9, 6), nullable=True)
    detected_locality = Column(String(100), nullable=True)

    # Gamification & Verification
    streak_count = Column(Integer, default=0, nullable=False)
    reward_balance = Column(Integer, default=0, nullable=False)
    kyc_status = Column(Boolean, default=False, nullable=False)
    kyc_state = Column(String(30), default="pending_ai", nullable=False)
    kyc_ai_confidence = Column(Numeric(3, 2), nullable=True)
    kyc_transcript = Column(Text, nullable=True)
    kyc_failure_reason = Column(Text, nullable=True)
    kyc_verified_at = Column(DateTime(timezone=True), nullable=True)
    kyc_document_sha256 = Column(String(64), nullable=True)

    # Security & Audit
    last_installation_uuid = Column(String(64), nullable=True)
    fcm_token = Column(String(255), nullable=True)
    is_super_admin = Column(Boolean, default=False, nullable=False)
    is_banned = Column(Boolean, default=False, nullable=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), default=datetime.utcnow, onupdate=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint("gender IN ('male', 'female', 'lgbtq+')", name="users_gender_check"),
        CheckConstraint("streak_count >= 0", name="users_streak_positive"),
        CheckConstraint("reward_balance >= 0", name="users_reward_positive"),
        {"schema": "public"}
    )
