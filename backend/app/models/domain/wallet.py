from sqlalchemy import Column, String, Integer, Date, DateTime, ForeignKey, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from app.core.database import Base


class UserWallet(Base):
    __tablename__ = "user_wallets"

    user_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), primary_key=True)
    dm_credits = Column(Integer, default=3, nullable=False)
    wa_reveal_tokens = Column(Integer, default=0, nullable=False)
    missed_bio_passes = Column(Integer, default=0, nullable=False)
    streak_shields = Column(Integer, default=0, nullable=False)
    total_ads_watched = Column(Integer, default=0, nullable=False)
    night_farm_ads_today = Column(Integer, default=0, nullable=False)
    last_night_farm_date = Column(Date, server_default=func.current_date(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint("dm_credits >= 0", name="wallets_dm_credits_positive"),
        CheckConstraint("wa_reveal_tokens >= 0", name="wallets_wa_tokens_positive"),
        CheckConstraint("missed_bio_passes >= 0", name="wallets_bio_passes_positive"),
        CheckConstraint("streak_shields >= 0", name="wallets_streak_shields_positive"),
        {"schema": "public"},
    )


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("public.users.id", ondelete="CASCADE"), nullable=False, index=True)
    reward_type = Column(String(30), nullable=False)
    delta = Column(Integer, nullable=False)
    source = Column(String(50), nullable=False)
    idempotency_key = Column(String(128), unique=True, nullable=True)
    metadata_json = Column("metadata", JSONB, default=dict)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        {"schema": "public"},
    )
