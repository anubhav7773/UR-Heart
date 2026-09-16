from datetime import datetime
from sqlalchemy import String, SmallInteger, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class UnderageQuarantine(Base):
    __tablename__ = "underage_quarantine"
    __table_args__ = {"schema": "public"}

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    device_phone_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    quarantined_until: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempt_count: Mapped[int] = mapped_column(SmallInteger, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
