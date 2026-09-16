from datetime import datetime
from uuid import UUID
from sqlalchemy import String, Integer, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class Message(Base):
    __tablename__ = "messages"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    match_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    sender_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    encrypted_text: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(10), default="sent", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
