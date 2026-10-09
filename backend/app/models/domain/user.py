import uuid
from datetime import date, datetime
from typing import Optional
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    func
)
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import validates
from app.core.database import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "public"}
    __allow_unmapped__ = True

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    auth_id = Column(UUID(as_uuid=True), unique=True, nullable=False, index=True)

    full_name = Column(String(60), nullable=False)
    dob = Column(Date, nullable=False)
    gender = Column(String(15), nullable=False)
    interested_in = Column(String(15), nullable=False)
    contact_bridge_type = Column(String(20), nullable=False, default="whatsapp")
    contact_bridge_encrypted = Column(Text, nullable=False)
    location_name = Column(String(100), nullable=False, default="Saket, Ayodhya")
    latitude = Column(Numeric(9, 6), nullable=True)
    longitude = Column(Numeric(9, 6), nullable=True)

    bio = Column(String(500), default="")
    profession = Column(String(80), default="")
    education = Column(String(100), default="")
    preferred_age_min = Column(SmallInteger, nullable=False, default=18)
    preferred_age_max = Column(SmallInteger, nullable=False, default=35)

    streak_count = Column(SmallInteger, nullable=False, default=0)
    boost_points = Column(Integer, nullable=False, default=0)
    last_streak_ad_at = Column(DateTime(timezone=True), nullable=True)
    streak_expires_at = Column(DateTime(timezone=True), nullable=True)
    reveal_tokens_count = Column(SmallInteger, nullable=False, default=0)
    reward_balance = Column(Integer, nullable=False, default=0)
    swipes_remaining = Column(Integer, nullable=False, default=10)
    direct_letters_count = Column(Integer, nullable=False, default=0)
    last_installation_uuid = Column(String(64), nullable=True)
    referral_code = Column(String(16), unique=True, nullable=False)

    kyc_status = Column(Boolean, nullable=False, default=False)
    is_incognito = Column(Boolean, nullable=False, default=False)
    is_photo_veiled = Column(Boolean, nullable=False, default=False)
    discreet_mode = Column(Boolean, nullable=False, default=False)
    night_slumber = Column(Boolean, nullable=False, default=False)
    is_profile_completed = Column(Boolean, nullable=False, default=False)
    welcome_email_sent = Column(Boolean, nullable=False, default=False)
    public_encryption_key = Column(String(64), nullable=True, default=None)
    push_notifications_enabled = Column(Boolean, nullable=False, default=True)
    fcm_token = Column(String(512), nullable=True)

    subscription_tier = Column(String(20), nullable=False, default="free")
    subscription_expires_at = Column(DateTime(timezone=True), nullable=True)
    is_ad_free = Column(Boolean, nullable=False, default=False)
    passport_city = Column(String(100), nullable=True)

    deleted_at = Column(DateTime(timezone=True), nullable=True)
    role = Column(String(20), nullable=False, default="user")
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    email = Column(String(255), unique=True, nullable=True, index=True)
    photos = Column(ARRAY(String), default=[])
    avatar_url = Column(String(500), nullable=True)
    voice_spark_url = Column(String(500), nullable=True)
    voice_spark_prompt = Column(String(120), nullable=True)
    voice_spark_duration = Column(Numeric(4, 1), nullable=True, default=7.0)
    is_voice_verified = Column(Boolean, nullable=False, default=False)
    last_blind_date_date = Column(Date, nullable=True)
    blind_date_passes = Column(Integer, nullable=False, default=0)

    @validates("latitude")
    def validate_latitude(self, key, value):
        """SEC-MED-05: Statutory DPDP purpose limitation & fuzzy radius truncation (2 decimal places ~1.1km)."""
        if value is not None:
            return round(float(value), 2)
        return value

    @validates("longitude")
    def validate_longitude(self, key, value):
        """SEC-MED-05: Statutory DPDP purpose limitation & fuzzy radius truncation (2 decimal places ~1.1km)."""
        if value is not None:
            return round(float(value), 2)
        return value
