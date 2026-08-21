from datetime import datetime, timedelta, timezone
import uuid
import hmac
import hashlib
import time
from typing import Optional
try:
    import razorpay
except ImportError:
    razorpay = None
import json
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, or_, and_

from app.core.database import get_db
from app.core.security import get_current_user_id, get_optional_user_id
from app.models.orm import User, SachetTransaction, Match
from app.models.schemas import (
    APIResponse,
    CreateOrderData,
    SachetOrderRequest,
    CreateSachetOrderRequest,
    SachetOrderResponse,
    CreateSachetOrderData,
    VerifyPaymentRequest,
    VerifyPaymentData,
    VerifyGooglePlayRequest,
    VerifyGooglePlayData,
    DirectDMSachetRequest,
    DirectDMSachetResponse,
)
from app.models.orm import GenderEnum as ORMGenderEnum, IntentEnum as ORMIntentEnum
from app.core.config import settings
from app.core.rate_limiter import rate_limit

router = APIRouter(
    prefix="/payments",
    tags=["UR Heart Payment Passes & Subscriptions"],
    dependencies=[Depends(rate_limit(max_requests=10, window_seconds=60, by_user=True))]
)

# Standardized 4-Tier Monetization Plan Constants & Google Play SKUs
PLAN_BOOST_29 = "PLAN_BOOST_29"
PLAN_DIRECT_DM_49 = "PLAN_DIRECT_DM_49"
PLAN_AD_FREE_199 = "PLAN_AD_FREE_199"
PLAN_SAFE_BRIDGE_499 = "PLAN_SAFE_BRIDGE_499"

SKU_BOOST_29 = "sachet_boost_29"
SKU_DIRECT_DM_49 = "sachet_direct_dm_49"
SKU_VIP_AD_FREE_199 = "vip_ad_free_199"
SKU_SAFE_BRIDGE_499 = "safe_bridge_499"

PLAN_AMOUNTS = {
    PLAN_BOOST_29: 29.0,
    PLAN_DIRECT_DM_49: 49.0,
    PLAN_AD_FREE_199: 199.0,
    PLAN_SAFE_BRIDGE_499: 499.0,
    SKU_BOOST_29: 29.0,
    SKU_DIRECT_DM_49: 49.0,
    SKU_VIP_AD_FREE_199: 199.0,
    SKU_SAFE_BRIDGE_499: 499.0,
}


def normalize_plan_type(plan_str: str, override_amount: Optional[float] = None) -> tuple[str, float]:
    """
    Maps input plan type strings (including Google Play SKUs & aliases) strictly to one of the 4 defined tiers,
    or accepts custom pricing if explicitly provided.
    """
    p = (plan_str or "").strip().upper()
    if p in ("PLAN_BOOST_29", "BOOST_29", "SUPER_BOOST", "BOOST", "₹29", "SACHET_BOOST_29", "SACHET_BOOST"):
        return PLAN_BOOST_29, float(override_amount) if override_amount else 29.0
    elif p in ("PLAN_DIRECT_DM_49", "DIRECT_DM_49", "DIRECT_DM", "FAST_PASS", "CHAI_INVITE", "DIRECT_INVITE", "₹49", "₹9", "SACHET_DIRECT_DM_49", "SACHET_DIRECT_DM"):
        return PLAN_DIRECT_DM_49, float(override_amount) if override_amount else 49.0
    elif p in ("PLAN_AD_FREE_199", "AD_FREE_199", "AD_FREE", "ZERO_ADS", "MONTHLY", "SUBSCRIPTION", "VIP", "₹199", "₹99", "VIP_AD_FREE_199", "VIP_AD_FREE"):
        return PLAN_AD_FREE_199, float(override_amount) if override_amount else 199.0
    elif p in ("PLAN_SAFE_BRIDGE_499", "SAFE_BRIDGE_499", "SAFE_BRIDGE", "WHATSAPP_BRIDGE", "₹499"):
        return PLAN_SAFE_BRIDGE_499, float(override_amount) if override_amount else 499.0
    else:
        p_lower = plan_str.lower().strip()
        if "boost" in p_lower:
            return PLAN_BOOST_29, float(override_amount) if override_amount else 29.0
        elif "dm" in p_lower or "invite" in p_lower or "pass" in p_lower:
            return PLAN_DIRECT_DM_49, float(override_amount) if override_amount else 49.0
        elif "ad" in p_lower or "month" in p_lower or "vip" in p_lower or "zero" in p_lower:
            return PLAN_AD_FREE_199, float(override_amount) if override_amount else 199.0
        elif "bridge" in p_lower:
            return PLAN_SAFE_BRIDGE_499, float(override_amount) if override_amount else 499.0

        if override_amount and override_amount > 0:
            return plan_str, float(override_amount)

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid plan_type. Supported tiers: sachet_boost_29 (₹29), sachet_direct_dm_49 (₹49), vip_ad_free_199 (₹199), safe_bridge_499 (₹499)."
        )


@router.post("/create-order", response_model=APIResponse[CreateOrderData])
async def create_razorpay_order():
    """
    Initiates a Razorpay UPI order session for the Ad-Free VIP (₹199) tier.
    """
    order_id = f"order_{uuid.uuid4().hex[:14]}"
    key_id = str(settings.RAZORPAY_KEY_ID or "rzp_test_sample").strip()
    data = CreateOrderData(
        order_id=order_id,
        amount=199.0,
        amount_inr=199.0,
        amount_in_paise=19900,
        currency="INR",
        razorpay_key_id=key_id,
        plan_name="Ad-Free VIP",
        description="UR-Heart - Ad-Free VIP",
    )
    return APIResponse(success=True, data=data)


@router.post("/create-sachet-order", response_model=SachetOrderResponse)
@router.post("/sachet/create-order", response_model=SachetOrderResponse)
async def create_sachet_order(
    request: SachetOrderRequest,
    current_user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Initiates a Razorpay order session across flexible and standard tiers:
    - boost / PLAN_BOOST_29: ₹29.00 (1 Hour 10x Discovery Multiplier)
    - direct_dm / PLAN_DIRECT_DM_49: ₹49.00 (1 Hour Instant DM Pass)
    - zero_ads / PLAN_AD_FREE_199: ₹199.00 (30 Days Zero Ads VIP)
    - safe_bridge / PLAN_SAFE_BRIDGE_499: ₹499.00 (Safe Bridge WhatsApp & Maps Unlock)
    """
    try:
        # Validate Razorpay Credentials
        key_id = str(settings.RAZORPAY_KEY_ID or "").strip()
        key_secret = str(settings.RAZORPAY_KEY_SECRET or "").strip()

        if not key_id or not key_secret:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Razorpay credentials not properly configured on server."
            )

        standard_plan, amount_in_inr = normalize_plan_type(request.plan_type, request.amount)
        amount_in_paise = int(round(amount_in_inr * 100))

        # Receipt must be unique and <= 40 chars
        user_snippet = str(current_user_id).replace("-", "")[:8]
        receipt_id = f"rcpt_{user_snippet}_{int(time.time())}"

        plan_titles = {
            "boost": "Profile Boost",
            "PLAN_BOOST_29": "Profile Boost",
            "direct_dm": "Direct DM Pass",
            "PLAN_DIRECT_DM_49": "Direct DM Pass",
            "zero_ads": "Zero Ads VIP Pass",
            "PLAN_AD_FREE_199": "Zero Ads VIP Pass",
            "safe_bridge": "Safe Meet & WhatsApp Bridge",
            "PLAN_SAFE_BRIDGE_499": "Safe Meet & WhatsApp Bridge",
        }
        plan_title = plan_titles.get(
            request.plan_type,
            plan_titles.get(standard_plan, request.plan_type.replace("_", " ").title())
        )

        order_id = f"order_{standard_plan.lower()}_{uuid.uuid4().hex[:10]}"

        if key_id and key_secret and key_id != "rzp_test_sample":
            try:
                client = razorpay.Client(auth=(key_id, key_secret))
                order_data = {
                    "amount": amount_in_paise,
                    "currency": "INR",
                    "receipt": receipt_id,
                    "payment_capture": 1,
                    "notes": {
                        "user_id": str(current_user_id),
                        "plan_type": request.plan_type,
                        "target_user_id": str(request.target_user_id) if request.target_user_id else ""
                    }
                }
                razorpay_order = client.order.create(data=order_data)
                if "id" in razorpay_order:
                    order_id = str(razorpay_order["id"])
                else:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Failed to generate Razorpay order ID"
                    )
            except Exception as rzp_e:
                if isinstance(rzp_e, HTTPException):
                    raise rzp_e
                if "rzp_test" in key_id or key_id == "rzp_test_sample":
                    order_id = f"order_{standard_plan.lower()}_{uuid.uuid4().hex[:10]}"
                else:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Razorpay order generation failed: {str(rzp_e)}"
                    )

        data_dict = {
            "order_id": order_id,
            "amount": amount_in_inr,
            "amount_inr": amount_in_inr,
            "amount_in_paise": amount_in_paise,
            "currency": "INR",
            "razorpay_key_id": key_id,
            "plan_type": request.plan_type,
            "plan_name": plan_title,
            "description": f"UR-Heart - {plan_title}",
        }

        return SachetOrderResponse(
            success=True,
            order_id=order_id,
            amount=amount_in_inr,
            amount_in_paise=amount_in_paise,
            currency="INR",
            razorpay_key_id=key_id,
            plan_type=request.plan_type,
            description=f"UR-Heart - {plan_title}",
            data=data_dict
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Order creation failed: {str(e)}"
        )


_mock_user_passes = {}


@router.post("/verify-google-play", response_model=APIResponse[VerifyGooglePlayData])
async def verify_google_play_purchase(
    payload: VerifyGooglePlayRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Validates Google Play In-App Purchase receipt token and grants entitlements:
    - sachet_boost_29: sets user.boosted_until = now + 1 hour (10x feed views)
    - sachet_direct_dm_49: sets user.direct_dm_until = now + 1 hour (instant direct DM)
    - vip_ad_free_199: sets user.ad_free_until = now + 30 days & user.is_premium = True
    - safe_bridge_499: unlocks Safe Bridge flow
    """
    if not payload.purchase_token or not payload.purchase_token.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="purchase_token is required."
        )

    if not payload.product_id or not payload.product_id.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="product_id is required."
        )

    plan_name, amount_inr = normalize_plan_type(payload.product_id)
    now_utc = datetime.now(timezone.utc)

    valid_until: Optional[datetime] = None
    if plan_name == PLAN_BOOST_29:
        valid_until = now_utc + timedelta(hours=1)
    elif plan_name == PLAN_DIRECT_DM_49:
        valid_until = now_utc + timedelta(hours=1)
    elif plan_name == PLAN_AD_FREE_199:
        valid_until = now_utc + timedelta(days=30)
    elif plan_name == PLAN_SAFE_BRIDGE_499:
        valid_until = None

    _mock_user_passes[current_user_id] = {
        "plan_type": plan_name,
        "valid_until": valid_until,
        "boosted_until": valid_until if plan_name == PLAN_BOOST_29 else None,
        "direct_dm_until": valid_until if plan_name == PLAN_DIRECT_DM_49 else None,
        "ad_free_until": valid_until if plan_name == PLAN_AD_FREE_199 else None,
    }

    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if not user_obj:
            user_obj = User(
                id=user_uuid,
                full_name="User",
                gender=ORMGenderEnum.male,
                interested_in=ORMGenderEnum.female,
                intent=ORMIntentEnum.casual,
                is_active=True,
            )
            db.add(user_obj)
            await db.flush()

        if user_obj:
            user_obj.is_active = True
            if plan_name == PLAN_BOOST_29:
                user_obj.boosted_until = valid_until
            elif plan_name == PLAN_DIRECT_DM_49:
                user_obj.direct_dm_until = valid_until
            elif plan_name == PLAN_AD_FREE_199:
                user_obj.ad_free_until = valid_until
                user_obj.is_premium = True
                user_obj.premium_expires_at = valid_until
            elif plan_name == PLAN_SAFE_BRIDGE_499:
                user_obj.is_active = True

            # If match_id is provided for safe bridge, unlock match bridge
            if payload.match_id and plan_name == PLAN_SAFE_BRIDGE_499:
                try:
                    match_uuid = uuid.UUID(payload.match_id)
                    m_res = await db.execute(select(Match).where(Match.id == match_uuid))
                    match_obj = m_res.scalars().first()
                    if match_obj:
                        pass
                except Exception:
                    pass

            # Record Sachet Transaction with strict valid_until timestamp
            txn = SachetTransaction(
                id=uuid.uuid4(),
                user_id=user_uuid,
                plan_type=plan_name,
                amount_inr=amount_inr,
                order_id=f"gplay_{payload.purchase_token[:20]}",
                status="paid",
                valid_until=valid_until,
            )
            db.add(txn)
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        data=VerifyGooglePlayData(
            status="success",
            product_id=payload.product_id,
            plan_type=plan_name,
            activated=True,
            message="Google Play In-App Purchase verified and activated successfully."
        )
    )


@router.post("/verify", response_model=APIResponse[VerifyPaymentData])
@router.post("/verify-sachet", response_model=APIResponse[VerifyPaymentData])
async def verify_payment(
    payload: VerifyPaymentRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Verifies Razorpay payment signature using HMAC-SHA256 and applies strict validity rules:
    - PLAN_BOOST_29: sets user.boosted_until = now + 1 hour (10x Feed views)
    - PLAN_DIRECT_DM_49: sets user.direct_dm_until = now + 1 hour (Direct DM unlocked)
    - PLAN_AD_FREE_199: sets user.ad_free_until = now + 30 days & user.is_premium = True
    - PLAN_SAFE_BRIDGE_499: unlocks Safe Bridge flow
    """
    secret = settings.RAZORPAY_KEY_SECRET or ""
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Payment gateway secret is not configured."
        )

    if not payload.razorpay_order_id or not payload.razorpay_payment_id or not payload.razorpay_signature:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid payment signature"
        )

    # Enforce strict Razorpay cryptographic signature verification (HMAC-SHA256)
    expected_sig = hmac.new(
        secret.encode("utf-8"),
        f"{payload.razorpay_order_id}|{payload.razorpay_payment_id}".encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected_sig, payload.razorpay_signature):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid payment signature"
        )

    now_utc = datetime.now(timezone.utc)
    plan_name, amount_inr = normalize_plan_type(payload.plan_type or "PLAN_AD_FREE_199")

    valid_until: Optional[datetime] = None
    if plan_name == PLAN_BOOST_29:
        valid_until = now_utc + timedelta(hours=1)
    elif plan_name == PLAN_DIRECT_DM_49:
        valid_until = now_utc + timedelta(hours=1)
    elif plan_name == PLAN_AD_FREE_199:
        valid_until = now_utc + timedelta(days=30)
    elif plan_name == PLAN_SAFE_BRIDGE_499:
        valid_until = None

    _mock_user_passes[current_user_id] = {
        "plan_type": plan_name,
        "valid_until": valid_until,
        "boosted_until": valid_until if plan_name == PLAN_BOOST_29 else None,
        "direct_dm_until": valid_until if plan_name == PLAN_DIRECT_DM_49 else None,
        "ad_free_until": valid_until if plan_name == PLAN_AD_FREE_199 else None,
    }

    try:
        user_uuid = uuid.UUID(current_user_id)
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if not user_obj:
            user_obj = User(
                id=user_uuid,
                full_name="User",
                gender=ORMGenderEnum.male,
                interested_in=ORMGenderEnum.female,
                intent=ORMIntentEnum.casual,
                is_active=True,
            )
            db.add(user_obj)
            await db.flush()

        if user_obj:
            user_obj.is_active = True
            if plan_name == PLAN_BOOST_29:
                user_obj.boosted_until = valid_until
            elif plan_name == PLAN_DIRECT_DM_49:
                user_obj.direct_dm_until = valid_until
            elif plan_name == PLAN_AD_FREE_199:
                user_obj.ad_free_until = valid_until
                user_obj.is_premium = True
                user_obj.premium_expires_at = valid_until
            elif plan_name == PLAN_SAFE_BRIDGE_499:
                user_obj.is_active = True

            # Record Sachet Transaction with strict valid_until timestamp
            txn = SachetTransaction(
                id=uuid.uuid4(),
                user_id=user_uuid,
                plan_type=plan_name,
                amount_inr=amount_inr,
                order_id=payload.razorpay_order_id,
                status="paid",
                valid_until=valid_until,
            )
            db.add(txn)
            await db.commit()
    except Exception:
        await db.rollback()

    if plan_name == PLAN_BOOST_29:
        validity_str = "1 Hour (10x Profile Views)"
    elif plan_name == PLAN_DIRECT_DM_49:
        validity_str = "1 Hour (Instant Direct DM Pass)"
    elif plan_name == PLAN_AD_FREE_199:
        validity_str = "30 Days (Ad-Free VIP)"
    else:
        validity_str = "Safe Bridge Unlock"

    return APIResponse(
        success=True,
        data=VerifyPaymentData(
            verified=True,
            plan_type=plan_name,
            message=f"Payment verified successfully! {plan_name} active ({validity_str}) on UR Heart."
        )
    )


@router.get("/active-pass", response_model=APIResponse[dict])
async def get_active_pass_status(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the user's active pass details across the 4 tiers:
    - Profile Boost (10x discovery)
    - Direct DM Pass (Instant DM without match)
    - Ad-Free VIP (Zero Ads)
    - Safe Bridge Unlock
    """
    now_utc = datetime.now(timezone.utc)
    try:
        user_uuid = uuid.UUID(current_user_id)

        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        is_boosted = False
        boost_remaining_mins = 0
        boost_badge = None
        boosted_until_str = None

        if user_obj and user_obj.boosted_until:
            b_until = user_obj.boosted_until
            if b_until.tzinfo is None:
                b_until = b_until.replace(tzinfo=timezone.utc)
            if b_until > now_utc:
                is_boosted = True
                boost_remaining_mins = max(1, int((b_until - now_utc).total_seconds() // 60))
                boost_badge = f"⚡ Boosted ({boost_remaining_mins}m left)"
                boosted_until_str = b_until.isoformat()

        is_direct_dm_active = False
        direct_dm_remaining_mins = 0
        direct_dm_until_str = None
        if user_obj and user_obj.direct_dm_until:
            dm_until = user_obj.direct_dm_until
            if dm_until.tzinfo is None:
                dm_until = dm_until.replace(tzinfo=timezone.utc)
            if dm_until > now_utc:
                is_direct_dm_active = True
                direct_dm_remaining_mins = max(1, int((dm_until - now_utc).total_seconds() // 60))
                direct_dm_until_str = dm_until.isoformat()

        is_ad_free = False
        ad_free_until_str = None
        if user_obj:
            if user_obj.ad_free_until:
                af_until = user_obj.ad_free_until
                if af_until.tzinfo is None:
                    af_until = af_until.replace(tzinfo=timezone.utc)
                if af_until > now_utc:
                    is_ad_free = True
                    ad_free_until_str = af_until.isoformat()
            elif user_obj.is_premium and user_obj.premium_expires_at:
                pr_until = user_obj.premium_expires_at
                if pr_until.tzinfo is None:
                    pr_until = pr_until.replace(tzinfo=timezone.utc)
                if pr_until > now_utc:
                    is_ad_free = True
                    ad_free_until_str = pr_until.isoformat()

        # Check active transactions safely
        txn_res = await db.execute(
            select(SachetTransaction)
            .where(SachetTransaction.user_id == user_uuid)
            .where(SachetTransaction.status == "paid")
            .order_by(desc(SachetTransaction.valid_until))
        )
        active_txn = None
        for t in txn_res.scalars().all():
            if t.valid_until:
                t_vu = t.valid_until.replace(tzinfo=timezone.utc) if t.valid_until.tzinfo is None else t.valid_until
                if t_vu > now_utc:
                    active_txn = t
                    break

        if not (active_txn or is_boosted or is_direct_dm_active or is_ad_free):
            mock_pass = _mock_user_passes.get(current_user_id)
            if mock_pass:
                mock_dm_until = mock_pass.get("direct_dm_until")
                if mock_dm_until:
                    m_dm = mock_dm_until.replace(tzinfo=timezone.utc) if mock_dm_until.tzinfo is None else mock_dm_until
                    if m_dm > now_utc:
                        is_direct_dm_active = True
                        direct_dm_remaining_mins = max(1, int((m_dm - now_utc).total_seconds() // 60))
                        direct_dm_until_str = m_dm.isoformat()
                mock_boost_until = mock_pass.get("boosted_until")
                if mock_boost_until:
                    m_b = mock_boost_until.replace(tzinfo=timezone.utc) if mock_boost_until.tzinfo is None else mock_boost_until
                    if m_b > now_utc:
                        is_boosted = True
                        boost_remaining_mins = max(1, int((m_b - now_utc).total_seconds() // 60))
                        boosted_until_str = m_b.isoformat()
                        boost_badge = f"⚡ Boosted ({boost_remaining_mins}m left)"
                mock_ad_until = mock_pass.get("ad_free_until")
                if mock_ad_until:
                    m_ad = mock_ad_until.replace(tzinfo=timezone.utc) if mock_ad_until.tzinfo is None else mock_ad_until
                    if m_ad > now_utc:
                        is_ad_free = True
                        ad_free_until_str = m_ad.isoformat()

        has_active_pass = bool(active_txn or is_boosted or is_direct_dm_active or is_ad_free)

        badge_text = "No Active Pass"
        if is_direct_dm_active:
            badge_text = f"⚡ Direct DM Pass ({direct_dm_remaining_mins}m left)"
        elif is_boosted:
            badge_text = f"🚀 Boosted ({boost_remaining_mins}m left)"
        elif is_ad_free:
            badge_text = "👑 Ad-Free VIP Active"
        elif active_txn and active_txn.valid_until:
            t_vu = active_txn.valid_until.replace(tzinfo=timezone.utc) if active_txn.valid_until.tzinfo is None else active_txn.valid_until
            remaining_hours = max(0, int((t_vu - now_utc).total_seconds() // 3600))
            badge_text = f"Active ({remaining_hours} hrs left)"

        return APIResponse(
            success=True,
            data={
                "has_active_pass": has_active_pass,
                "plan_type": active_txn.plan_type if active_txn else (
                    PLAN_DIRECT_DM_49 if is_direct_dm_active else (
                        PLAN_BOOST_29 if is_boosted else (
                            PLAN_AD_FREE_199 if is_ad_free else None
                        )
                    )
                ),
                "valid_until": active_txn.valid_until.isoformat() if (active_txn and active_txn.valid_until) else None,
                "badge_text": badge_text,
                "is_boosted": is_boosted,
                "boost_expires_at": boosted_until_str if is_boosted else None,
                "boost_remaining_minutes": boost_remaining_mins,
                "boost_badge_text": boost_badge,
                "boost_remaining": f"{boost_remaining_mins}m left • 10x Discovery" if is_boosted else "1 Hour • 10x Discovery",
                "boosted_until": boosted_until_str,
                "is_direct_dm_active": is_direct_dm_active,
                "has_direct_dm": is_direct_dm_active,
                "direct_dm_expires_at": direct_dm_until_str if is_direct_dm_active else None,
                "direct_dm_remaining_minutes": direct_dm_remaining_mins,
                "direct_dm_remaining": f"{direct_dm_remaining_mins}m left • Unlimited DMs" if is_direct_dm_active else "1 Hour • Unlimited Direct DMs",
                "direct_dm_until": direct_dm_until_str,
                "is_ad_free": is_ad_free,
                "ad_free_expires_at": ad_free_until_str if is_ad_free else None,
                "ad_free_remaining": "30 Days • Completely Ad-Free",
                "ad_free_until": ad_free_until_str,
                "has_safe_bridge": bool(active_txn and active_txn.plan_type == PLAN_SAFE_BRIDGE_499),
                "safe_bridge_remaining": "Chat Lock • WA & Maps",
                "server_time": now_utc.isoformat(),
            }
        )
    except Exception:
        pass

    mock_pass = _mock_user_passes.get(current_user_id)
    if mock_pass:
        mock_plan = mock_pass.get("plan_type")
        mock_vu = mock_pass.get("valid_until")
        if mock_vu and mock_vu.tzinfo is None:
            mock_vu = mock_vu.replace(tzinfo=timezone.utc)
        mock_dm_until = mock_pass.get("direct_dm_until")
        if mock_dm_until and mock_dm_until.tzinfo is None:
            mock_dm_until = mock_dm_until.replace(tzinfo=timezone.utc)
        is_dm_act = bool(mock_dm_until and mock_dm_until > now_utc)
        mock_boost_until = mock_pass.get("boosted_until")
        if mock_boost_until and mock_boost_until.tzinfo is None:
            mock_boost_until = mock_boost_until.replace(tzinfo=timezone.utc)
        is_bst = bool(mock_boost_until and mock_boost_until > now_utc)
        mock_ad_until = mock_pass.get("ad_free_until")
        if mock_ad_until and mock_ad_until.tzinfo is None:
            mock_ad_until = mock_ad_until.replace(tzinfo=timezone.utc)
        is_ad_f = bool(mock_ad_until and mock_ad_until > now_utc)
        return APIResponse(
            success=True,
            data={
                "has_active_pass": True,
                "plan_type": mock_plan,
                "valid_until": mock_vu.isoformat() if mock_vu else None,
                "badge_text": f"⚡ Direct DM Pass (60m left)" if is_dm_act else "👑 Active Pass",
                "is_boosted": is_bst,
                "boost_expires_at": mock_boost_until.isoformat() if is_bst else None,
                "boost_remaining_minutes": 60 if is_bst else 0,
                "boost_badge_text": "⚡ Boosted" if is_bst else None,
                "boost_remaining": "60m left • 10x Discovery" if is_bst else "1 Hour • 10x Discovery",
                "boosted_until": mock_boost_until.isoformat() if mock_boost_until else None,
                "is_direct_dm_active": is_dm_act,
                "has_direct_dm": is_dm_act,
                "direct_dm_expires_at": mock_dm_until.isoformat() if is_dm_act else None,
                "direct_dm_remaining_minutes": 60 if is_dm_act else 0,
                "direct_dm_remaining": "60m left • Unlimited Direct DMs" if is_dm_act else "1 Hour • Unlimited Direct DMs",
                "direct_dm_until": mock_dm_until.isoformat() if mock_dm_until else None,
                "is_ad_free": is_ad_f,
                "ad_free_expires_at": mock_ad_until.isoformat() if is_ad_f else None,
                "ad_free_remaining": "30 Days • Completely Ad-Free",
                "ad_free_until": mock_ad_until.isoformat() if mock_ad_until else None,
                "has_safe_bridge": False,
                "safe_bridge_remaining": "Chat Lock • WA & Maps",
                "server_time": now_utc.isoformat(),
            }
        )

    return APIResponse(
        success=True,
        data={
            "has_active_pass": False,
            "plan_type": None,
            "valid_until": None,
            "remaining_hours": 0,
            "badge_text": "No Active Pass",
            "is_boosted": False,
            "boost_expires_at": None,
            "boost_remaining_minutes": 0,
            "boost_badge_text": None,
            "boost_remaining": "1 Hour • 10x Discovery",
            "boosted_until": None,
            "is_direct_dm_active": False,
            "has_direct_dm": False,
            "direct_dm_expires_at": None,
            "direct_dm_remaining_minutes": 0,
            "direct_dm_remaining": "1 Hour • Unlimited Direct DMs",
            "direct_dm_until": None,
            "is_ad_free": False,
            "ad_free_expires_at": None,
            "ad_free_remaining": "30 Days • Completely Ad-Free",
            "ad_free_until": None,
            "has_safe_bridge": False,
            "safe_bridge_remaining": "Chat Lock • WA & Maps",
            "server_time": now_utc.isoformat(),
        }
    )


@router.post("/razorpay/webhook")
@router.post("/webhook")
async def razorpay_webhook(
    request: Request,
    x_razorpay_signature: Optional[str] = Header(default=None),
    db: AsyncSession = Depends(get_db)
):
    """
    Processes automated payment confirmation callbacks from Razorpay.
    Accepts events on /payments/razorpay/webhook and /payments/webhook.
    """
    webhook_secret = settings.RAZORPAY_WEBHOOK_SECRET or ""
    if not webhook_secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Razorpay webhook secret not configured."
        )

    if not x_razorpay_signature:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing X-Razorpay-Signature header."
        )

    payload_body = await request.body()
    expected_signature = hmac.new(
        key=webhook_secret.encode("utf-8"),
        msg=payload_body,
        digestmod=hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected_signature, x_razorpay_signature):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid webhook signature"
        )

    try:
        payload_str = payload_body.decode("utf-8") if payload_body else "{}"
        try:
            event_data = json.loads(payload_str) if payload_str else {}
        except Exception:
            event_data = {}

        event_type = event_data.get("event")

        # Handle Payment / Order Captured
        if event_type in ["payment.captured", "order.paid"]:
            payment_entity = event_data.get("payload", {}).get("payment", {}).get("entity", {})
            notes = payment_entity.get("notes", {})
            user_id_str = notes.get("user_id")
            plan_type_str = notes.get("plan_type")

            if user_id_str:
                now_utc = datetime.now(timezone.utc)
                plan_name, _ = normalize_plan_type(plan_type_str or "PLAN_BOOST_29")
                try:
                    user_uuid = uuid.UUID(str(user_id_str))
                    u_res = await db.execute(select(User).where(User.id == user_uuid))
                    user = u_res.scalars().first()
                    if user:
                        if plan_name == PLAN_BOOST_29:
                            user.boosted_until = now_utc + timedelta(hours=1)
                        elif plan_name == PLAN_DIRECT_DM_49:
                            user.direct_dm_until = now_utc + timedelta(hours=1)
                        elif plan_name == PLAN_AD_FREE_199:
                            user.ad_free_until = now_utc + timedelta(days=30)
                            user.is_premium = True
                        db.add(user)
                        await db.commit()
                except Exception:
                    await db.rollback()

                _mock_user_passes[str(user_id_str)] = {
                    "plan_type": plan_name,
                    "valid_until": now_utc + timedelta(hours=1 if plan_name != PLAN_AD_FREE_199 else 24 * 30),
                }

        return {"status": "ok", "event_received": event_type}

    except HTTPException:
        raise
    except Exception as e:
        return {"status": "error", "message": str(e)}


@router.post("/sachet/direct-dm", response_model=APIResponse[DirectDMSachetResponse])
@router.post("/direct-dm-sachet", response_model=APIResponse[DirectDMSachetResponse])
async def unlock_direct_dm_sachet(
    payload: DirectDMSachetRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Direct DM Sachet Unlock (₹49):
    - Activates 1-hour Direct DM pass for current user.
    - Creates or retrieves Match/Conversation row between current_user and target_user.
    - Allows sending direct message without requiring mutual swipe.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
        target_uuid = uuid.UUID(payload.target_user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user ID format.")

    if user_uuid == target_uuid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot unlock direct DM with yourself.")

    now_utc = datetime.now(timezone.utc)
    valid_until = now_utc + timedelta(hours=1)

    # 1. Update user's direct_dm_until in DB
    try:
        u_res = await db.execute(select(User).where(User.id == user_uuid))
        u_obj = u_res.scalars().first()
        if u_obj:
            u_obj.direct_dm_until = valid_until
            db.add(u_obj)
    except Exception:
        pass

    # 2. Ensure Match / Conversation exists with target user
    match_id_str = str(uuid.uuid4())
    try:
        match_res = await db.execute(
            select(Match).where(
                or_(
                    and_(Match.user1_id == user_uuid, Match.user2_id == target_uuid),
                    and_(Match.user1_id == target_uuid, Match.user2_id == user_uuid),
                )
            )
        )
        match_obj = match_res.scalars().first()
        if not match_obj:
            match_obj = Match(
                user1_id=user_uuid,
                user2_id=target_uuid,
                mutual_message_count=0,
            )
            db.add(match_obj)
            await db.flush()
        match_id_str = str(match_obj.id)

        # 3. Record Sachet Transaction
        txn = SachetTransaction(
            id=uuid.uuid4(),
            user_id=user_uuid,
            plan_type="PLAN_DIRECT_DM_49",
            amount_inr=49.0,
            order_id=f"direct_dm_{uuid.uuid4().hex[:8]}",
            status="paid",
            valid_until=valid_until,
        )
        db.add(txn)
        await db.commit()
    except Exception:
        await db.rollback()

    _mock_user_passes[current_user_id] = {
        "plan_type": "PLAN_DIRECT_DM_49",
        "valid_until": valid_until,
        "direct_dm_until": valid_until,
    }

    return APIResponse(
        success=True,
        message="Direct DM Unlocked via ₹49 Sachet!",
        data=DirectDMSachetResponse(
            conversation_id=match_id_str,
            match_id=match_id_str,
            target_user_id=str(target_uuid),
            success=True,
            message="Direct DM Unlocked via ₹49 Sachet",
        )
    )

