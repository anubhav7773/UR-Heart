from datetime import datetime
from sqlalchemy import (
    Column,
    BigInteger,
    DateTime,
    ForeignKey,
    String,
    Text,
    func
)
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = {"schema": "public"}

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    match_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.matches.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    sender_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    encrypted_text = Column(Text, nullable=False)
    status = Column(String(20), nullable=False, default="delivered")  # 'sent', 'delivered', 'read'
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
