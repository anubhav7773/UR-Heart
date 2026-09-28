from datetime import datetime
from sqlalchemy import (
    Column,
    BigInteger,
    DateTime,
    ForeignKey,
    String,
    func
)
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class Swipe(Base):
    __tablename__ = "swipes"
    __table_args__ = {"schema": "public"}

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    actor_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    target_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    swipe_type = Column(String(20), nullable=False)  # 'like', 'pass', 'direct'
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
