from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, text
from sqlalchemy.exc import IntegrityError
from uuid import UUID

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.wallet import UserWallet
from app.services.notification_service import send_push_notification

router = APIRouter()

# Statutory Referral Reward Constants
BONUS_DIRECT_DMS = 5
BONUS_WA_REVEALS = 2


@router.get("/my-code", status_code=status.HTTP_200_OK)
async def get_my_referral_code(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns user's personal referral code and total friends invited.
    """
    # If referral code is not set, generate and assign one
    if not current_user.referral_code:
        res = await db.execute(text("SELECT public.generate_unique_referral_code()"))
        code = res.scalar()
        await db.execute(
            update(User).where(User.id == current_user.id).values(referral_code=code)
        )
        await db.commit()
        referral_code = code
    else:
        referral_code = current_user.referral_code

    # Total invites count
    count_stmt = select(text("COUNT(*)")).select_from(text("public.referral_logs")).where(
        text("referrer_id = :uid")
    )
    count_res = await db.execute(count_stmt, {"uid": current_user.id})
    total_invites = count_res.scalar() or 0

    return {
        "referral_code": referral_code,
        "share_url": f"https://urheart.asiverticals.me/join?ref={referral_code}",
        "total_invites": total_invites,
        "reward_per_invite": {
            "dm_credits": BONUS_DIRECT_DMS,
            "wa_reveals": BONUS_WA_REVEALS
        }
    }


@router.post("/redeem", status_code=status.HTTP_200_OK)
async def redeem_referral_code(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Redeems a referral code on signup/onboarding.
    Atomically awards 5 Direct DMs and 2 WhatsApp Reveals to BOTH users.
    """
    code = (payload.get("referral_code") or "").strip().upper()
    if not code:
        raise HTTPException(status_code=400, detail="Referral code is required.")

    # 1. Anti-Cheat: Referee already redeemed check (both in-memory and direct DB check)
    if getattr(current_user, "has_redeemed_referral", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already redeemed a referral reward on this account."
        )

    db_status_res = await db.execute(
        select(User.has_redeemed_referral).where(User.id == current_user.id)
    )
    if db_status_res.scalar():
        current_user.has_redeemed_referral = True
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already redeemed a referral reward on this account."
        )

    # 2. Find Referrer by code
    referrer_stmt = select(User).where(User.referral_code == code)
    referrer_res = await db.execute(referrer_stmt)
    referrer = referrer_res.scalar_one_or_none()

    if not referrer:
        raise HTTPException(status_code=404, detail="Invalid referral code. Please check and retry.")

    # 3. Anti-Cheat: Self referral block
    if referrer.id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot redeem your own referral code.")

    try:
        # 4. Atomic Wallet Updates: Referrer & Referee get +5 DMs & +2 WA Reveals
        # Update Referee (current_user)
        await db.execute(
            text("""
                INSERT INTO public.user_wallets (user_id, dm_credits, wa_reveal_tokens)
                VALUES (:uid, :dms, :wa)
                ON CONFLICT (user_id) DO UPDATE SET
                    dm_credits = public.user_wallets.dm_credits + :dms,
                    wa_reveal_tokens = public.user_wallets.wa_reveal_tokens + :wa
            """),
            {"uid": current_user.id, "dms": BONUS_DIRECT_DMS, "wa": BONUS_WA_REVEALS}
        )

        # Update Referrer
        await db.execute(
            text("""
                INSERT INTO public.user_wallets (user_id, dm_credits, wa_reveal_tokens)
                VALUES (:uid, :dms, :wa)
                ON CONFLICT (user_id) DO UPDATE SET
                    dm_credits = public.user_wallets.dm_credits + :dms,
                    wa_reveal_tokens = public.user_wallets.wa_reveal_tokens + :wa
            """),
            {"uid": referrer.id, "dms": BONUS_DIRECT_DMS, "wa": BONUS_WA_REVEALS}
        )

        # 5. Record in Referral Logs & mark redeemed
        await db.execute(
            text("""
                INSERT INTO public.referral_logs (referrer_id, referee_id, referral_code_used, dms_awarded, wa_tokens_awarded)
                VALUES (:referrer, :referee, :code, :dms, :wa)
            """),
            {
                "referrer": referrer.id,
                "referee": current_user.id,
                "code": code,
                "dms": BONUS_DIRECT_DMS,
                "wa": BONUS_WA_REVEALS
            }
        )

        await db.execute(
            update(User)
            .where(User.id == current_user.id)
            .values(referred_by=referrer.id, has_redeemed_referral=True)
        )

        await db.commit()
        current_user.has_redeemed_referral = True
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already redeemed a referral reward on this account."
        )

    # 6. Real-time FCM Notification to Referrer
    if referrer.fcm_token:
        try:
            await send_push_notification(
                fcm_token=referrer.fcm_token,
                title="🎁 Free Credits Unlocked!",
                body=f"{current_user.full_name} joined using your code! 5 Free DMs + 2 WhatsApp reveals added to your wallet.",
                data={"type": "referral_bonus"}
            )
        except Exception as e:
            print(f"⚠️ [Referral FCM Error] {e}")

    return {
        "status": "success",
        "message": "Referral redeemed! 5 Direct DMs and 2 WhatsApp Reveals added to your wallet.",
        "reward_credited": {
            "dm_credits": BONUS_DIRECT_DMS,
            "wa_reveals": BONUS_WA_REVEALS
        }
    }
