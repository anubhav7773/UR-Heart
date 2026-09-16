from datetime import datetime
from uuid import UUID
from sqlalchemy import String, DateTime, Numeric, BigInteger, Text, ARRAY
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class KycReviewQueue(Base):
    __tablename__ = "kyc_review_queue"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[UUID] = mapped_column(nullable=False)
    video_storage_path: Mapped[str] = mapped_column(Text, nullable=False)
    registered_name: Mapped[str] = mapped_column(String(50), nullable=False)
    registered_city: Mapped[str] = mapped_column(String(50), nullable=False)
    extracted_transcript: Mapped[str] = mapped_column(Text, default="")
    ai_confidence_score: Mapped[float] = mapped_column(Numeric(3, 2), default=0.00)
    ai_flags: Mapped[list] = mapped_column(ARRAY(String), default=list)
    status: Mapped[str] = mapped_column(String(20), default="unreviewed")
    reviewed_by: Mapped[str] = mapped_column(String(100), nullable=True)
    rejection_reason: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    resolved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
