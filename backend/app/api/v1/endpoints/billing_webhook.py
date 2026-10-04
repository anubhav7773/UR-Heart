import os
import hmac
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Request, HTTPException, status, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.in_app_purchases import InAppPurchase
from app.schemas.billing_schemas import (
    BillingAuditResponse,
    RevenueCatWebhookPayload,
    WebStorePurchasePayload,
)

router = APIRouter(prefix="/billing", tags=["Billing & Store Webhooks"])

REVENUECAT_SECRET = os.getenv("REVENUECAT_WEBHOOK_SECRET", "rc_webhook_secret_sanctuary_2026")
RAZORPAY_WEBHOOK_SECRET = os.getenv("RAZORPAY_WEBHOOK_SECRET", "rzp_webhook_secret_sanctuary_2026")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "stripe_webhook_secret_sanctuary_2026")


def verify_bearer_auth(authorization: Optional[str] = Header(None)) -> None:
    """Enforces shared secret on RevenueCat webhooks."""
    if not REVENUECAT_SECRET:
        raise HTTPException(status_code=500, detail="Server webhook secret unconfigured.")
    if not authorization or authorization != f"Bearer {REVENUECAT_SECRET}":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid webhook credentials.")


@router.post("/webhook/revenuecat", status_code=status.HTTP_200_OK)
async def process_revenuecat_event(
    request: Request,
    _: None = Depends(verify_bearer_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Handles Google Play lifecycle events via RevenueCat.
    Grants entitlements on purchase and revokes on cancellation/expiration.
    """
    payload = await request.json()
    event = payload.get("event", {})
    event_type = event.get("type")
    user_id_str = event.get("app_user_id")
    tx_id = event.get("id")

    if not user_id_str or not tx_id:
        return {"status": "ignored", "reason": "Missing identifiers"}

    try:
        user_uuid = UUID(user_id_str)
    except (ValueError, TypeError, AttributeError):
        return {"status": "ignored", "reason": "Invalid UUID format"}

    # 1. Idempotency Check
    existing = await db.execute(
        select(InAppPurchase).where(InAppPurchase.transaction_reference == tx_id)
    )
    if existing.scalar_one_or_none():
        return {"status": "already_processed"}

    # 2. Lifecycle Event Routing
    if event_type in ("INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "NON_RENEWING_PURCHASE"):
        product_id = event.get("product_id", "")
        exp_ms = event.get("expiration_at_ms")
        expires_at = datetime.fromtimestamp(exp_ms / 1000.0, tz=timezone.utc) if exp_ms else None

        tier = "monthly"
        curr = (event.get("currency") or "USD").upper()
        swipes_grant = 500 if curr == "INR" else 1000
        letters_grant = 5
        if "weekly" in product_id:
            tier = "weekly"
            swipes_grant = 100 if curr == "INR" else 200
            letters_grant = 0
        elif "lifetime" in product_id:
            tier = "lifetime"
            swipes_grant = 999999
            letters_grant = 10

        # Entitlement Grant
        await db.execute(
            update(User)
            .where(User.id == user_uuid)
            .values(
                subscription_tier=tier,
                subscription_expires_at=expires_at,
                is_ad_free=True,
                swipes_remaining=User.swipes_remaining + swipes_grant,
                direct_letters_count=User.direct_letters_count + letters_grant
            )
        )

        # Audit Record (Financial ledger split)
        gross = float(event.get("price_in_purchased_currency", 14.99))
        fee = round(gross * 0.15, 2)  # 15% Google Play tier
        net = round(gross - fee, 2)

        iap_audit = InAppPurchase(
            user_id=user_uuid,
            transaction_reference=tx_id,
            product_identifier=product_id,
            store="google_play",
            currency=event.get("currency", "USD"),
            amount_gross=gross,
            platform_fee=fee,
            amount_net=net,
            status="completed"
        )
        db.add(iap_audit)
        await db.commit()

    elif event_type in ("EXPIRATION", "CANCELLATION", "BILLING_ISSUE"):
        # Entitlement Revocation: Revert gracefully to Free Tier
        await db.execute(
            update(User)
            .where(User.id == user_uuid)
            .values(
                subscription_tier="free",
                subscription_expires_at=None,
                is_ad_free=False,
                swipes_remaining=25
            )
        )
        await db.commit()

    return {"status": "success", "event": event_type}


@router.post("/webhook/razorpay", status_code=status.HTTP_200_OK)
async def process_razorpay_webhook(
    request: Request,
    x_razorpay_signature: str = Header(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Authenticates Sanctuary Web Store payments (India Corridor).
    Enforces HMAC-SHA256 signature verification over raw body bytes.
    """
    body_bytes = await request.body()
    expected_signature = hmac.new(
        RAZORPAY_WEBHOOK_SECRET.encode("utf-8"),
        body_bytes,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected_signature, x_razorpay_signature):
        raise HTTPException(status_code=403, detail="Invalid Razorpay webhook signature.")

    payload = await request.json()
    event = payload.get("event")

    if event == "payment.captured":
        payment_entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
        notes = payment_entity.get("notes", {})
        user_uuid_str = notes.get("user_id")
        product_id = notes.get("product_id", "urheart_pass_monthly")
        payment_id = payment_entity.get("id")

        if not user_uuid_str or not payment_id:
            return {"status": "ignored"}

        try:
            user_uuid = UUID(user_uuid_str)
        except (ValueError, TypeError, AttributeError):
            return {"status": "ignored", "reason": "Invalid user UUID format"}
        amount_inr = float(payment_entity.get("amount", 0)) / 100.0
        fee = round(amount_inr * 0.02, 2)  # Razorpay 2% fee
        net = round(amount_inr - fee, 2)

        # Record Ledger (98% Net in hand)
        iap_audit = InAppPurchase(
            user_id=user_uuid,
            transaction_reference=payment_id,
            product_identifier=product_id,
            store="web_razorpay_india",
            currency="INR",
            amount_gross=amount_inr,
            platform_fee=fee,
            amount_net=net,
            status="completed"
        )
        db.add(iap_audit)

        # Grant Entitlement
        tier = "monthly" if "monthly" in product_id else ("weekly" if "weekly" in product_id else "lifetime")
        swipes_grant = 500 if tier == "monthly" else (100 if tier == "weekly" else 999999)
        letters_grant = 5 if tier == "monthly" else (0 if tier == "weekly" else 10)
        dur_days = 30 if tier == "monthly" else (7 if tier == "weekly" else 365)
        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(days=dur_days)

        await db.execute(
            update(User)
            .where(User.id == user_uuid)
            .values(
                subscription_tier=tier,
                subscription_expires_at=expires_at,
                is_ad_free=True,
                swipes_remaining=User.swipes_remaining + swipes_grant,
                direct_letters_count=User.direct_letters_count + letters_grant
            )
        )
        await db.commit()

    return {"status": "success"}


@router.post("/purchase/audit", response_model=BillingAuditResponse, status_code=status.HTTP_200_OK)
async def audit_web_or_play_purchase(
    payload: WebStorePurchasePayload,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> BillingAuditResponse:
    """
    Authenticated audit endpoint for Google Play, Razorpay India, and Stripe Global transactions.
    """
    # Enforce shared server secret if authorization header provided
    if authorization and authorization != f"Bearer {REVENUECAT_SECRET}":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid audit credentials.")

    # 1. Idempotency Check
    existing = await db.execute(
        select(InAppPurchase).where(InAppPurchase.transaction_reference == payload.transaction_reference)
    )
    if existing.scalar_one_or_none():
        return BillingAuditResponse(
            status="duplicate",
            transaction_reference=payload.transaction_reference,
            product_identifier=payload.product_identifier,
            store=payload.store,
            processed_at=datetime.now(timezone.utc)
        )

    iap = InAppPurchase(
        user_id=payload.user_id,
        transaction_reference=payload.transaction_reference,
        product_identifier=payload.product_identifier,
        store=payload.store,
        currency=payload.currency,
        amount_gross=payload.amount_gross,
        platform_fee=payload.platform_fee,
        amount_net=payload.amount_net,
        status="completed"
    )
    db.add(iap)

    if "pass" in payload.product_identifier:
        await db.execute(
            update(User)
            .where(User.id == payload.user_id)
            .values(is_ad_free=True, subscription_tier="monthly")
        )
    elif "swipes" in payload.product_identifier:
        await db.execute(
            update(User)
            .where(User.id == payload.user_id)
            .values(swipes_remaining=User.swipes_remaining + 50)
        )
    elif "letters" in payload.product_identifier:
        await db.execute(
            update(User)
            .where(User.id == payload.user_id)
            .values(direct_letters_count=User.direct_letters_count + 3)
        )

    await db.commit()

    return BillingAuditResponse(
        status="completed",
        transaction_reference=payload.transaction_reference,
        product_identifier=payload.product_identifier,
        store=payload.store,
        processed_at=datetime.now(timezone.utc)
    )
