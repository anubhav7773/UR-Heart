from datetime import datetime
from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class AdRewardLedger(Base):
    __tablename__ = "ad_reward_ledger"
    __table_args__ = {"schema": "public"}

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("public.users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    ssv_transaction_id = Column(String(150), unique=True, nullable=False, index=True)
    network = Column(String(30), nullable=False)
    ad_type = Column(String(50), nullable=False)
    reward_points = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    @property
    def transaction_id(self) -> str:
        return self.ssv_transaction_id


from app.models.domain.ad_transaction import ProcessedAdTransaction

__all__ = ["AdRewardLedger", "ProcessedAdTransaction"]
