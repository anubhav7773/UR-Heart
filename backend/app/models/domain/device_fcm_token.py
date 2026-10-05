import uuid

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class DeviceFcmToken(Base):
    __tablename__ = "device_fcm_tokens"
    __table_args__ = (
        UniqueConstraint("user_id", "token", name="uq_device_fcm_tokens_user_token"),
        UniqueConstraint("token", name="uq_device_fcm_tokens_token"),
        {"schema": "public"},
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token = Column(String(512), nullable=False)
    platform = Column(String(20), nullable=False, default="unknown")
    installation_id = Column(String(128), nullable=True)
    active = Column(Boolean, nullable=False, default=True)
    last_seen_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
