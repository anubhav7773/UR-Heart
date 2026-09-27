from datetime import datetime
from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class ProcessedAdTransaction(Base):
    __tablename__ = "processed_ad_transactions"
    __table_args__ = {"schema": "public"}

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    transaction_id = Column(String(150), unique=True, nullable=False, index=True)
    network = Column(String(20), nullable=False)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False
    )
    ad_type = Column(String(30), nullable=False)
    processed_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
