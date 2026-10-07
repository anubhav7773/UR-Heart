import uuid
from datetime import datetime
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    func
)
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class BlindDateSession(Base):
    """
    Active 5-minute timed Blind Date session ("Awaaz & Soul Connection First").
    Avatars and raw photos are heavily veiled until mutual resonance is achieved.
    """
    __tablename__ = "blind_date_sessions"
    __table_args__ = {"schema": "public"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user1_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    user2_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    # Status: 'active', 'expired', 'revealed', 'passed', 'cancelled'
    status = Column(String(20), nullable=False, default="active", index=True)

    started_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)

    # Decisions: 'pending', 'resonate', 'pass'
    user1_decision = Column(String(15), nullable=False, default="pending")
    user2_decision = Column(String(15), nullable=False, default="pending")

    icebreaker_prompt = Column(
        Text,
        nullable=False,
        default="What is a quiet dream you hold close to your heart?"
    )

    # Linked match_id once both users mutually resonate
    match_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.matches.id", ondelete="SET NULL"),
        nullable=True
    )

    extension_count = Column(SmallInteger, nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class BlindDateMessage(Base):
    """Ephemeral in-session chat messages during the 5-minute blind dialogue."""
    __tablename__ = "blind_date_messages"
    __table_args__ = {"schema": "public"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.blind_date_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    sender_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    ciphertext = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class BlindDateQueueEntry(Base):
    """
    ACID-safe matchmaking pool entry in PostgreSQL.
    Allows instant or synchronized matchmaking without paid Redis infrastructure.
    """
    __tablename__ = "blind_date_queue"
    __table_args__ = {"schema": "public"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True
    )

    # Cached attributes for fast candidate filtering
    gender = Column(String(20), nullable=False)
    interested_in = Column(String(100), nullable=False)
    age = Column(SmallInteger, nullable=False, default=24)
    preferred_age_min = Column(SmallInteger, nullable=False, default=18)
    preferred_age_max = Column(SmallInteger, nullable=False, default=45)

    # Status: 'waiting', 'paired', 'cancelled'
    status = Column(String(20), nullable=False, default="waiting", index=True)
    is_fast_track = Column(Boolean, nullable=False, default=False)
    joined_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    paired_session_id = Column(UUID(as_uuid=True), nullable=True)
