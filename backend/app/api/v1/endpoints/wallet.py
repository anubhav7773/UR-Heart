from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from datetime import datetime, timezone, date

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.wallet import UserWallet, WalletTransaction
from app.models.schemas.wallet import WalletBalanceResponse, RewardClaimRequest, RewardSpendRequest

router = APIRouter()


@router.get("/balance", response_model=WalletBalanceResponse)
async def get_wallet_balance(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(UserWallet).where(UserWallet.user_id == current_user.id)
    res = await db.execute(stmt)
    wallet = res.scalar_one_or_none()

    if not wallet:
        wallet = UserWallet(user_id=current_user.id, dm_credits=3)
        db.add(wallet)
        await db.commit()
        await db.refresh(wallet)

    today = date.today()
    if wallet.last_night_farm_date != today:
        wallet.night_farm_ads_today = 0
        wallet.last_night_farm_date = today
        await db.commit()

    return WalletBalanceResponse(
        user_id=wallet.user_id,
        dm_credits=wallet.dm_credits,
        wa_reveal_tokens=wallet.wa_reveal_tokens,
        missed_bio_passes=wallet.missed_bio_passes,
        streak_shields=wallet.streak_shields,
        total_ads_watched=wallet.total_ads_watched,
        night_farm_ads_today=wallet.night_farm_ads_today,
        can_farm_tonight=(wallet.night_farm_ads_today < 18)
    )


@router.post("/claim-reward", status_code=status.HTTP_200_OK)
async def claim_ad_reward(
    payload: RewardClaimRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Check idempotency
    dup_stmt = select(WalletTransaction).where(WalletTransaction.idempotency_key == payload.idempotency_key)
    dup_res = await db.execute(dup_stmt)
    if dup_res.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Reward already claimed for this ad impression.")

    # Concurrency safe row-lock
    wallet_stmt = select(UserWallet).where(UserWallet.user_id == current_user.id).with_for_update()
    res = await db.execute(wallet_stmt)
    wallet = res.scalar_one_or_none()

    if not wallet:
        wallet = UserWallet(user_id=current_user.id)
        db.add(wallet)

    # Determine Delta by Tier
    tier_deltas = {
        "10s": {"dm_credit": 1, "missed_bio_pass": 1},
        "20s": {"dm_credit": 2, "streak_shield": 1},
        "30s": {"dm_credit": 4, "wa_reveal_token": 1},
        "night_farm": {"dm_credit": 1, "wa_reveal_token": 1, "streak_shield": 1, "missed_bio_pass": 1}
    }

    deltas = tier_deltas.get(payload.ad_tier, {})
    delta = deltas.get(payload.reward_choice, 1)

    # Night farmer daily cap check
    today = date.today()
    if payload.ad_tier == "night_farm":
        if wallet.last_night_farm_date != today:
            wallet.night_farm_ads_today = 0
            wallet.last_night_farm_date = today
        if wallet.night_farm_ads_today >= 18:
            raise HTTPException(status_code=429, detail="Night Farm daily safety cap reached (18 ads/day).")
        wallet.night_farm_ads_today += 1

    # Apply Credit
    if payload.reward_choice == "dm_credit":
        wallet.dm_credits += delta
    elif payload.reward_choice == "wa_reveal_token":
        wallet.wa_reveal_tokens += delta
    elif payload.reward_choice == "missed_bio_pass":
        wallet.missed_bio_passes += delta
    elif payload.reward_choice == "streak_shield":
        wallet.streak_shields += delta

    wallet.total_ads_watched += 1

    # Record Transaction
    tx = WalletTransaction(
        user_id=current_user.id,
        reward_type=payload.reward_choice,
        delta=delta,
        source=f"ad_{payload.ad_tier}_manual" if payload.ad_tier != "night_farm" else "night_farmer_auto",
        idempotency_key=payload.idempotency_key,
        metadata_json={"tier": payload.ad_tier}
    )
    db.add(tx)
    await db.commit()

    return {
        "status": "success",
        "reward_choice": payload.reward_choice,
        "delta": delta,
        "new_balance": getattr(wallet, f"{payload.reward_choice}s" if payload.reward_choice != "missed_bio_pass" else "missed_bio_passes")
    }


@router.post("/spend", status_code=status.HTTP_200_OK)
async def spend_reward(
    payload: RewardSpendRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    wallet_stmt = select(UserWallet).where(UserWallet.user_id == current_user.id).with_for_update()
    res = await db.execute(wallet_stmt)
    wallet = res.scalar_one_or_none()

    if not wallet:
        raise HTTPException(status_code=400, detail="Wallet not initialized.")

    attr_map = {
        "dm_credit": "dm_credits",
        "wa_reveal_token": "wa_reveal_tokens",
        "missed_bio_pass": "missed_bio_passes",
        "streak_shield": "streak_shields"
    }
    field_name = attr_map[payload.reward_type]
    current_val = getattr(wallet, field_name)

    if current_val < payload.amount:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Insufficient {payload.reward_type} balance. Current: {current_val}, Required: {payload.amount}"
        )

    # Decrement
    setattr(wallet, field_name, current_val - payload.amount)

    # Record consumption in ledger
    tx = WalletTransaction(
        user_id=current_user.id,
        reward_type=payload.reward_type,
        delta=-payload.amount,
        source="consumed_feature",
        metadata_json={"target_id": payload.target_id}
    )
    db.add(tx)
    await db.commit()

    return {
        "status": "spent",
        "reward_type": payload.reward_type,
        "amount_deducted": payload.amount,
        "remaining_balance": getattr(wallet, field_name)
    }
