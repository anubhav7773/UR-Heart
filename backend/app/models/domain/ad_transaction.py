from datetime import datetime
from uuid import UUID
from sqlalchemy import String, Integer, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class ProcessedAdTransaction(Base):
    __tablename__ = "processed_ad_transactions"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    transaction_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    network: Mapped[str] = mapped_column(String(20), nullable=False)
    user_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    ad_type: Mapped[str] = mapped_column(String(30), nullable=False)
    reward_amount: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    raw_custom_data: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
