from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, text, and_
from datetime import datetime, timezone, date, timedelta

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.wallet import UserWallet, WalletTransaction
from app.models.schemas.wallet import WalletBalanceResponse, RewardSpendRequest

router = APIRouter()

# Rolling 24-hour manual ad limit to prevent AdMob IVT account suspension
MAX_MANUAL_ADS_PER_24H = 7


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
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    ad_tier = payload.get("ad_tier", "10s")
    reward_choice = payload.get("reward_choice", "dm_credit")
    idempotency_key = payload.get("idempotency_key")

    # 1. Anti-IVT Rate Limit Check for Manual Hub Ads
    if ad_tier in ["10s", "20s", "30s"]:
        twenty_four_hours_ago = datetime.now(timezone.utc) - timedelta(hours=24)

        count_stmt = text(
            "SELECT count(*) FROM public.ad_claim_logs "
            "WHERE user_id = :uid AND ad_tier IN ('10s', '20s', '30s') "
            "AND claimed_at >= :since"
        )
        res = await db.execute(count_stmt, {"uid": current_user.id, "since": twenty_four_hours_ago})
        claims_today = res.scalar() or 0

        if claims_today >= MAX_MANUAL_ADS_PER_24H:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Daily ad reward limit reached (maximum 7 claims per 24 hours). Please try again tomorrow to maintain account integrity."
            )

    # Check idempotency if key provided
    if idempotency_key:
        dup_stmt = select(WalletTransaction).where(WalletTransaction.idempotency_key == idempotency_key)
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
        "10s": {"dm_credit": 1, "missed_bio_pass": 1, "streak_shield": 1, "wa_reveal_token": 1},
        "20s": {"dm_credit": 2, "streak_shield": 1, "missed_bio_pass": 1, "wa_reveal_token": 1},
        "30s": {"dm_credit": 4, "wa_reveal_token": 1, "streak_shield": 1, "missed_bio_pass": 1},
        "night_farm": {"dm_credit": 1, "wa_reveal_token": 1, "streak_shield": 1, "missed_bio_pass": 1}
    }

    deltas = tier_deltas.get(ad_tier, {})
    delta = deltas.get(reward_choice, 1)

    # Night farmer daily cap check
    today = date.today()
    if ad_tier == "night_farm":
        if wallet.last_night_farm_date != today:
            wallet.night_farm_ads_today = 0
            wallet.last_night_farm_date = today
        if wallet.night_farm_ads_today >= 18:
            raise HTTPException(status_code=429, detail="Night Farm daily safety cap reached (18 ads/day).")
        wallet.night_farm_ads_today += 1

    # Apply Credit
    if reward_choice == "dm_credit":
        wallet.dm_credits += delta
    elif reward_choice == "wa_reveal_token":
        wallet.wa_reveal_tokens += delta
    elif reward_choice == "missed_bio_pass":
        wallet.missed_bio_passes += delta
    elif reward_choice == "streak_shield":
        wallet.streak_shields += delta

    wallet.total_ads_watched += 1

    # 3. Log claim in audit table
    await db.execute(
        text("INSERT INTO public.ad_claim_logs (user_id, ad_tier, reward_choice) VALUES (:uid, :tier, :reward)"),
        {"uid": current_user.id, "tier": ad_tier, "reward": reward_choice}
    )

    # Record Transaction
    if idempotency_key:
        tx = WalletTransaction(
            user_id=current_user.id,
            reward_type=reward_choice,
            delta=delta,
            source=f"ad_{ad_tier}_manual" if ad_tier != "night_farm" else "night_farmer_auto",
            idempotency_key=idempotency_key,
            metadata_json={"tier": ad_tier}
        )
        db.add(tx)

    await db.commit()

    return {
        "status": "success",
        "ad_tier": ad_tier,
        "reward_choice": reward_choice,
        "reward_credited": reward_choice,
        "delta": delta,
        "new_balance": getattr(wallet, f"{reward_choice}s" if reward_choice != "missed_bio_pass" else "missed_bio_passes"),
        "new_dm_balance": wallet.dm_credits,
        "new_wa_tokens": wallet.wa_reveal_tokens,
        "new_shields": wallet.streak_shields
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
