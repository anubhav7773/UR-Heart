from datetime import datetime, timezone
from uuid import UUID
from sqlalchemy import BigInteger, DateTime, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class SecondChanceUnlock(Base):
    __tablename__ = "second_chance_unlocks"
    __table_args__ = (
        UniqueConstraint("viewer_id", "target_id", name="uq_second_chance_unlocks_viewer_target"),
        {"schema": "public"}
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    viewer_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    target_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

class SecondChanceDm(Base):
    __tablename__ = "second_chance_dms"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    sender_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    recipient_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
