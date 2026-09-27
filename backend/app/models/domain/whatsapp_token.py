import uuid
from datetime import datetime
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    func
)
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class WhatsAppRevealToken(Base):
    __tablename__ = "whatsapp_reveal_tokens"
    __table_args__ = {"schema": "public"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    match_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.matches.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True
    )
    user1_consent = Column(Boolean, nullable=False, default=False)
    user2_consent = Column(Boolean, nullable=False, default=False)
    user1_ads_count = Column(SmallInteger, nullable=False, default=0)
    user2_ads_count = Column(SmallInteger, nullable=False, default=0)
    is_unlocked = Column(Boolean, nullable=False, default=False)
    ephemeral_token = Column(String(64), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
