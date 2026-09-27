from datetime import datetime
from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    func
)
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class InAppPurchase(Base):
    __tablename__ = "in_app_purchases"
    __table_args__ = {"schema": "public"}

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    transaction_reference = Column(String(150), unique=True, nullable=False)
    product_identifier = Column(String(60), nullable=False)
    store = Column(String(30), nullable=False, default="google_play", index=True)
    currency = Column(String(10), nullable=False, default="USD")
    amount_gross = Column(Numeric(10, 2), nullable=False)
    platform_fee = Column(Numeric(10, 2), nullable=False, default=0.00)
    amount_net = Column(Numeric(10, 2), nullable=False)
    status = Column(String(20), nullable=False, default="completed")
    purchased_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
