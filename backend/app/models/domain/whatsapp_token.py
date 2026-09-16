from datetime import datetime
from uuid import UUID, uuid4
from sqlalchemy import String, Boolean, SmallInteger, DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class WhatsAppRevealToken(Base):
    __tablename__ = "whatsapp_reveal_tokens"
    __table_args__ = {"schema": "public"}

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    match_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), unique=True, nullable=False)
    user1_consent: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    user2_consent: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    user1_ads_count: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)
    user2_ads_count: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)
    is_unlocked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ephemeral_token: Mapped[str] = mapped_column(String(64), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
