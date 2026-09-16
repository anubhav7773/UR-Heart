from datetime import datetime
from uuid import UUID
from sqlalchemy import BigInteger, SmallInteger, String, Boolean, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class UserPhoto(Base):
    __tablename__ = "user_photos"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    slot_index: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    photo_storage_path: Mapped[str] = mapped_column(Text, nullable=False)
    blur_hash: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    ocr_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
