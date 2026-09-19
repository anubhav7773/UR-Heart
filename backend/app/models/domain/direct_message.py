from datetime import datetime
from uuid import UUID
from sqlalchemy import BigInteger, Text, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class DirectMessage(Base):
    __tablename__ = "direct_messages"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    match_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), ForeignKey("public.matches.id", ondelete="CASCADE"), nullable=False)
    sender_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False)
    recipient_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_delivered: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    delivered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), default=datetime.utcnow, nullable=False)
