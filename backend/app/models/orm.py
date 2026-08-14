import uuid
from datetime import datetime, date
from typing import List, Optional
from sqlalchemy import (
    String,
    Text,
    Boolean,
    Integer,
    Date,
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Numeric,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum


class Base(DeclarativeBase):
    pass


class GenderEnum(str, enum.Enum):
    male = "male"
    female = "female"
    non_binary = "non_binary"
    other = "other"


class IntentEnum(str, enum.Enum):
    casual = "casual"
    serious = "serious"
    friendship = "friendship"
    networking = "networking"


class SwipeActionEnum(str, enum.Enum):
    reject = "reject"
    like = "like"
    dm = "dm"


class VerificationStatusEnum(str, enum.Enum):
    UNVERIFIED = "UNVERIFIED"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"


class SachetPlanTypeEnum(str, enum.Enum):
    chai_invite = "chai_invite"  # ₹9
    photo_pass = "photo_pass"    # ₹19
    monthly = "monthly"          # ₹99


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True)
    phone_number: Mapped[Optional[str]] = mapped_column(String(20), unique=True, nullable=True)
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    dob: Mapped[Optional[date]] = mapped_column(Date, nullable=True, default=None)

    @property
    def date_of_birth(self) -> Optional[date]:
        return self.dob

    @date_of_birth.setter
    def date_of_birth(self, value: Optional[date]) -> None:
        self.dob = value

    gender: Mapped[GenderEnum] = mapped_column(
        SQLEnum(GenderEnum, name="gender_type"), nullable=False
    )
    interested_in: Mapped[GenderEnum] = mapped_column(
        SQLEnum(GenderEnum, name="gender_type"), nullable=False
    )
    intent: Mapped[IntentEnum] = mapped_column(
        SQLEnum(IntentEnum, name="intent_type"), default=IntentEnum.casual
    )

    area_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    village_pin_code: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    latitude: Mapped[Optional[float]] = mapped_column(Numeric(10, 6), nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Numeric(10, 6), nullable=True)
    is_location_masked: Mapped[bool] = mapped_column(Boolean, default=True)

    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    premium_expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    verification_status: Mapped[VerificationStatusEnum] = mapped_column(
        SQLEnum(VerificationStatusEnum, name="verification_status_enum", native_enum=False, values_callable=lambda obj: [e.value for e in obj]),
        default=VerificationStatusEnum.UNVERIFIED,
        nullable=False,
    )
    verification_video_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_online: Mapped[bool] = mapped_column(Boolean, default=True)
    last_seen: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    fcm_token: Mapped[Optional[str]] = mapped_column(String(512), nullable=True, default=None)

    photos: Mapped[List["UserPhoto"]] = relationship(
        "UserPhoto", back_populates="user", cascade="all, delete-orphan", order_by="UserPhoto.display_order", lazy="selectin"
    )
    ad_counter: Mapped[Optional["UserAdCounter"]] = relationship(
        "UserAdCounter", back_populates="user", uselist=False, cascade="all, delete-orphan", lazy="selectin"
    )


class UserPhoto(Base):
    __tablename__ = "user_photos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    photo_url: Mapped[str] = mapped_column(Text, nullable=False)
    is_first_impression: Mapped[bool] = mapped_column(Boolean, default=False)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="photos", lazy="selectin")


class UserAdCounter(Base):
    __tablename__ = "user_ad_counters"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    persistent_skip_count: Mapped[int] = mapped_column(Integer, default=0)
    total_interstitials_shown: Mapped[int] = mapped_column(Integer, default=0)
    last_interstitial_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="ad_counter", lazy="selectin")


class ChaiStatus(Base):
    __tablename__ = "chai_status"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    is_free_for_chai: Mapped[bool] = mapped_column(Boolean, default=True)
    status_badge: Mapped[str] = mapped_column(String(100), default="☕ Free for Chai")
    location_landmark: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class ChaiInvite(Base):
    __tablename__ = "chai_invites"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    receiver_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending, accepted, declined
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Swipe(Base):
    __tablename__ = "swipes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    swiper_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    swiped_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    action: Mapped[SwipeActionEnum] = mapped_column(
        SQLEnum(SwipeActionEnum, name="swipe_action_type"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Match(Base):
    __tablename__ = "matches"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user1_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    user2_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    mutual_message_count: Mapped[int] = mapped_column(Integer, default=0)
    user1_whatsapp_consent: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    user2_whatsapp_consent: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_whatsapp_unlocked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    match_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"), nullable=False
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    client_msg_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    media_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    media_type: Mapped[str] = mapped_column(String(20), default="text")  # text, image, audio
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class SachetTransaction(Base):
    __tablename__ = "sachet_transactions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    plan_type: Mapped[str] = mapped_column(String(50), nullable=False)
    amount_inr: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    order_id: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="created")  # created, paid, failed
    valid_until: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class BlockedUser(Base):
    __tablename__ = "blocked_users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    blocker_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    blocked_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class UserReport(Base):
    __tablename__ = "user_reports"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    reported_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    reason: Mapped[str] = mapped_column(String(100), nullable=False)
    details: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
