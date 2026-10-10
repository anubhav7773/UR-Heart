import os
import hmac
import hashlib
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)
from uuid import UUID
from fastapi import APIRouter, Request, HTTPException, status, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, or_

from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.in_app_purchases import InAppPurchase
from app.schemas.billing_schemas import (
    BillingAuditResponse,
    RevenueCatWebhookPayload,
    WebStorePurchasePayload,
)

router = APIRouter(prefix="/billing", tags=["Billing & Store Webhooks"])

REVENUECAT_SECRET = os.getenv("REVENUECAT_WEBHOOK_SECRET", "")
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
                swipes_remaining=10
            )
        )
        await db.commit()

    return {"status": "success", "event": event_type}


from app.services.razorpay_service import RazorpayService


@router.post("/webhook/razorpay", status_code=status.HTTP_200_OK)
async def process_razorpay_webhook(
    request: Request,
    x_razorpay_signature: str = Header(...),
    db: AsyncSession = Depends(get_db)
):
    """
    Authenticates Sanctuary Web Store payments (India Corridor).
    Enforces HMAC-SHA256 signature verification over raw body bytes.
    Handles all 6 products with strict idempotency and zero lost orders.
    """
    body_bytes = await request.body()
    if not RazorpayService.verify_webhook_signature(body_bytes, x_razorpay_signature):
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

        user_uuid = None
        target_email = None
        try:
            user_uuid = UUID(user_uuid_str)
        except (ValueError, TypeError, AttributeError):
            q = notes.get("user_query") or user_uuid_str
            if q and "@" in q:
                target_email = q.strip().lower()

        if not user_uuid and target_email:
            res = await db.execute(select(User).where(User.email == target_email))
            found_user = res.scalar_one_or_none()
            if found_user:
                user_uuid = found_user.id

        if not user_uuid:
            # Guest checkout: Record in pending_web_entitlements so it auto-claims upon login/signup
            if target_email:
                store_order_id = notes.get("order_id") or payment_entity.get("receipt") or f"ORD-RZP-{payment_id}"
                from sqlalchemy import text
                chk_pending_guest = (await db.execute(text("""
                    SELECT id, status FROM public.pending_web_entitlements
                    WHERE order_id = :order_id OR payment_reference = :payment_id
                """), {"order_id": store_order_id, "payment_id": payment_id})).fetchone()
                if chk_pending_guest and chk_pending_guest[1] == "claimed":
                    return {"status": "already_processed", "email": target_email, "payment_id": payment_id}

                stmt = text("""
                    INSERT INTO public.pending_web_entitlements 
                    (order_id, email, product_identifier, payment_reference, amount_gross, currency, status)
                    VALUES (:order_id, :email, :prod_id, :pay_ref, :amt, :curr, 'paid_pending_claim')
                    ON CONFLICT (order_id) DO NOTHING
                """)
                currency = (payment_entity.get("currency") or "INR").upper()
                amount_val = float(payment_entity.get("amount", 0)) / 100.0
                await db.execute(stmt, {
                    "order_id": store_order_id,
                    "email": target_email,
                    "prod_id": product_id,
                    "pay_ref": payment_id,
                    "amt": amount_val,
                    "curr": currency
                })
                await db.commit()
                return {"status": "pending_claim_recorded", "email": target_email, "payment_id": payment_id}
            return {"status": "ignored", "reason": "Invalid user UUID format"}

        # Single canonical ledger key matching verify endpoint + row locking
        store_order_id = notes.get("order_id") or payment_entity.get("receipt")
        rzp_order_id = payment_entity.get("order_id")
        conditions = [InAppPurchase.transaction_reference == payment_id]
        if store_order_id:
            conditions.append(InAppPurchase.transaction_reference == store_order_id)
        if rzp_order_id:
            conditions.append(InAppPurchase.transaction_reference == rzp_order_id)

        existing_check = await db.execute(
            select(InAppPurchase).where(or_(*conditions)).with_for_update()
        )
        existing_purchase = existing_check.scalar_one_or_none()
        if existing_purchase and existing_purchase.status == "completed":
            return {"status": "already_processed", "payment_id": payment_id}

        # Check pending entitlements to prevent double-grant with auto-claim or verify endpoint
        from sqlalchemy import text
        chk_pending_stmt = text("""
            SELECT id, status FROM public.pending_web_entitlements
            WHERE (order_id = :order_id OR payment_reference = :payment_id)
            FOR UPDATE
        """)
        pending_row = (await db.execute(chk_pending_stmt, {
            "order_id": store_order_id or payment_id,
            "payment_id": payment_id
        })).fetchone()

        if pending_row and pending_row[1] == "claimed":
            return {"status": "already_processed", "reason": "claimed_via_web_or_app", "payment_id": payment_id}

        currency = (payment_entity.get("currency") or "INR").upper()
        amount_val = float(payment_entity.get("amount", 0)) / 100.0
        fee_rate = 0.03 if currency != "INR" else 0.02
        fee = round(amount_val * fee_rate, 2)
        net = round(amount_val - fee, 2)

        canonical_key = store_order_id or payment_id
        store_type = "web_razorpay_india" if currency == "INR" else "web_razorpay_international"

        # Record Ledger using unified canonical key
        if existing_purchase:
            existing_purchase.status = "completed"
            existing_purchase.transaction_reference = canonical_key
            existing_purchase.currency = currency
            existing_purchase.store = store_type
            existing_purchase.amount_gross = amount_val
            existing_purchase.platform_fee = fee
            existing_purchase.amount_net = net
        else:
            iap_audit = InAppPurchase(
                user_id=user_uuid,
                transaction_reference=canonical_key,
                product_identifier=product_id,
                store=store_type,
                currency=currency,
                amount_gross=amount_val,
                platform_fee=fee,
                amount_net=net,
                status="completed"
            )
            db.add(iap_audit)

        # Mark pending entitlement as claimed so subsequent app login does not double-grant
        if pending_row and pending_row[1] == "paid_pending_claim":
            await db.execute(
                text("UPDATE public.pending_web_entitlements SET status = 'claimed', claimed_by_user_id = :uid, claimed_at = NOW() WHERE id = :id"),
                {"uid": user_uuid, "id": pending_row[0]}
            )

        # Grant Entitlement based on product type
        now = datetime.now(timezone.utc)
        if "direct_letters" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user_uuid)
                .values(direct_letters_count=User.direct_letters_count + 4)
            )
        elif "instant_contact" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user_uuid)
                .values(reveal_tokens_count=User.reveal_tokens_count + 1)
            )
        elif "global_passport" in product_id:
            expires_at = now + timedelta(days=1)
            await db.execute(
                update(User)
                .where(User.id == user_uuid)
                .values(
                    subscription_expires_at=expires_at,
                    swipes_remaining=User.swipes_remaining + 10,
                    is_ad_free=True
                )
            )
        else:
            tier = "monthly" if "monthly" in product_id else ("weekly" if "weekly" in product_id else "lifetime")
            swipes_grant = 550 if tier == "monthly" else (110 if tier == "weekly" else 999999)
            letters_grant = 6 if tier == "monthly" else (1 if tier == "weekly" else 11)
            dur_days = 30 if tier == "monthly" else (7 if tier == "weekly" else 365)
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
    # MANDATORY CONSTANT-TIME AUTHENTICATION CHECK (SEC-01 / PAY-01):
    # Requires shared server secret regardless of whether header is supplied
    if not REVENUECAT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server audit webhook secret unconfigured."
        )
    expected_header = f"Bearer {REVENUECAT_SECRET}"
    if not authorization or not hmac.compare_digest(authorization.strip(), expected_header):
        logger.warning("Unauthorized access attempt to purchase audit endpoint.")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing audit credentials."
        )

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
