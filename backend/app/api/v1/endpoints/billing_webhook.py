from datetime import datetime, timezone
from typing import Any, Dict, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.domain.in_app_purchase import InAppPurchase
from app.models.domain.user import User
from app.schemas.billing_schemas import (
    BillingAuditResponse,
    RevenueCatWebhookPayload,
    WebStorePurchasePayload,
)

router = APIRouter(prefix="/billing", tags=["Billing & Store Webhooks"])


@router.post("/webhook/revenuecat", status_code=status.HTTP_200_OK)
async def revenuecat_webhook(
    payload: RevenueCatWebhookPayload,
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Idempotent RevenueCat lifecycle webhook handler.
    Updates User subscription tier and logs to in_app_purchases.
    """
    event = payload.event
    event_type = event.get("type", "UNKNOWN")
    app_user_id_str = event.get("app_user_id", "")
    product_id = event.get("product_id", "urheart_pass_monthly")
    transaction_id = event.get("id") or event.get("transaction_id") or f"rc_{int(datetime.now().timestamp())}"

    try:
        user_uuid = UUID(app_user_id_str)
    except Exception:
        # Acknowledge 200 OK so RevenueCat does not loop retries for anonymous pings
        return {"status": "ignored", "reason": "non_uuid_user"}

    # Idempotency check against existing transactions
    existing = await db.execute(
        select(InAppPurchase).where(InAppPurchase.transaction_reference == transaction_id)
    )
    if existing.scalar_one_or_none():
        return {"status": "duplicate", "transaction_reference": transaction_id}

    tier = "monthly" if "monthly" in product_id else ("weekly" if "weekly" in product_id else "lifetime")
    is_active = event_type in ("INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "NON_RENEWING_PURCHASE")

    # Record purchase transaction
    iap = InAppPurchase(
        user_id=user_uuid,
        transaction_reference=transaction_id,
        product_identifier=product_id,
        store="google_play",
        currency=event.get("currency", "USD"),
        amount_gross=float(event.get("price_in_purchased_currency", 4.99)),
        platform_fee=float(event.get("takehome_percentage", 0.15) * float(event.get("price_in_purchased_currency", 4.99))),
        amount_net=float(event.get("price_in_purchased_currency", 4.99) * 0.85),
        status="completed" if is_active else "refunded",
    )
    db.add(iap)

    # Update User Entitlements
    if is_active:
        await db.execute(
            update(User)
            .where(User.id == user_uuid)
            .values(
                subscription_tier=tier,
                is_ad_free=True
            )
        )
    await db.commit()

    return {"status": "processed", "event_type": event_type, "user_id": str(user_uuid)}


@router.post("/purchase/audit", response_model=BillingAuditResponse, status_code=status.HTTP_200_OK)
async def audit_web_or_play_purchase(
    payload: WebStorePurchasePayload,
    db: AsyncSession = Depends(get_db)
) -> BillingAuditResponse:
    """
    Direct audit endpoint for Google Play, Razorpay India, and Stripe Global transactions.
    Enforces gross, fee, and net splits under DPDP and accounting mandates.
    """
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

    # If purchasing pass or keys, credit appropriate resources
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

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        return BillingAuditResponse(
            status="duplicate",
            transaction_reference=payload.transaction_reference,
            product_identifier=payload.product_identifier,
            store=payload.store,
            processed_at=datetime.now(timezone.utc)
        )

    return BillingAuditResponse(
        status="completed",
        transaction_reference=payload.transaction_reference,
        product_identifier=payload.product_identifier,
        store=payload.store,
        processed_at=datetime.now(timezone.utc)
    )
