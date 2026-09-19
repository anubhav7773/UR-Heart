from pydantic import BaseModel, Field, ConfigDict
from typing import Literal, Optional
from datetime import datetime, date
from uuid import UUID


class WalletBalanceResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: UUID
    dm_credits: int
    wa_reveal_tokens: int
    missed_bio_passes: int
    streak_shields: int
    total_ads_watched: int
    night_farm_ads_today: int
    night_farm_daily_cap: int = 18
    can_farm_tonight: bool


class RewardClaimRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ad_tier: Literal["10s", "20s", "30s", "night_farm"]
    reward_choice: Literal["dm_credit", "wa_reveal_token", "missed_bio_pass", "streak_shield"]
    idempotency_key: str = Field(..., min_length=16, max_length=128)


class RewardSpendRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reward_type: Literal["dm_credit", "wa_reveal_token", "missed_bio_pass", "streak_shield"]
    amount: int = Field(default=1, ge=1, le=10)
    target_id: Optional[str] = None
