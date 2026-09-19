from datetime import datetime
from sqlalchemy import Column, BigInteger, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.core.database import Base


class BlockedUser(Base):
    __tablename__ = "blocked_users"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    blocker_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    blocked_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), default=datetime.utcnow, nullable=False)

    __table_args__ = (
        {"schema": "public"}
    )
