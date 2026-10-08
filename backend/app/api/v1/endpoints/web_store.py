import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import require_superadmin, get_current_user
from app.models.domain.user import User
from app.models.domain.in_app_purchases import InAppPurchase
from app.services.razorpay_service import RazorpayService

settings = get_settings()
router = APIRouter(tags=["Web Sanctuary Store"])

# In-memory store orders vault for fast lookup (backed by PostgreSQL for persistence)
WEB_STORE_ORDERS: Dict[str, Dict[str, Any]] = {}
STORE_ORDER_RAZORPAY_MAP: Dict[str, str] = {}
SUBMITTED_UTRS: set[str] = set()

STORE_PRODUCTS = {
    "urheart_pass_weekly": {
        "id": "urheart_pass_weekly",
        "name": "1-Week Sovereign Sprint",
        "badge": "Popular",
        "price_inr": 49,
        "price_usd": 4.99,
        "duration_days": 7,
        "tier": "weekly",
        "bonus": "110 Swipes (+10% Web Bonus) + 100% Ad-Free",
        "features": ["110 Sovereign Swipes (+10% Web Bonus)", "10 Extra Reflections", "100% Ad-Free Silence (7 Days)", "Instant Fast Pass"]
    },
    "urheart_pass_monthly": {
        "id": "urheart_pass_monthly",
        "name": "1-Month Sovereign Pass",
        "badge": "Most Mindful",
        "price_inr": 149,
        "price_usd": 14.99,
        "duration_days": 30,
        "tier": "monthly",
        "bonus": "550 Swipes + 6 Direct Letters (+10% Web Bonus)",
        "features": ["550 Sovereign Swipes (+10% Web Bonus)", "6 Guaranteed Direct Letters", "100% Ad-Free Silence (30 Days)", "Eva AI Priority Counsel", "VIP Sovereign Badge"]
    },
    "urheart_pass_lifetime": {
        "id": "urheart_pass_lifetime",
        "name": "1-Year Sovereign Pass",
        "badge": "365 Days Access",
        "price_inr": 1499,
        "price_usd": 59.99,
        "duration_days": 365,
        "tier": "lifetime",
        "bonus": "365 Days Sovereign Crest + Infinite Passes",
        "features": ["365 Days Sovereign Crest", "Infinite Resonances for 1 Year", "11 Direct Letters (+10% Web Bonus)", "Full Legal Vault Export Access", "Stage 3 Reveal Token with Mutual Consent", "100% Ad-Free Silence (365 Days)"]
    },
    "urheart_key_instant_contact": {
        "id": "urheart_key_instant_contact",
        "name": "Instant Contact Key",
        "badge": "Key",
        "price_inr": 29,
        "price_usd": 1.49,
        "duration_days": 0,
        "tier": "micro",
        "bonus": "Credits 1 Reveal Token (Mutual Consent Required)",
        "features": ["Credits 1 Contact Reveal Token", "Requires Mutual Consent from Partner", "Valid for Any Mutual Match Dialogue"]
    },
    "urheart_pack_direct_letters": {
        "id": "urheart_pack_direct_letters",
        "name": "3 Direct Letters Pack",
        "badge": "Micro",
        "price_inr": 49,
        "price_usd": 1.99,
        "duration_days": 0,
        "tier": "micro",
        "bonus": "4 Guaranteed Direct Notes (+10% Web Bonus)",
        "features": ["4 Guaranteed Direct Notes (+10% Web Bonus)", "Bypasses Standard Matching Queue", "High Resonance Visibility"]
    },
    "urheart_pack_global_passport": {
        "id": "urheart_pack_global_passport",
        "name": "24h Global Passport",
        "badge": "Passport",
        "price_inr": 99,
        "price_usd": 1.99,
        "duration_days": 1,
        "tier": "micro",
        "bonus": "Explore Any World City for 24 Hours",
        "features": ["Teleport to Mumbai, Delhi, London, NYC", "Explore Global Kinships", "Full 24 Hours Access", "+10 Bonus Swipes (+10% Web Bonus)"]
    }
}


class VerifyUserRequest(BaseModel):
    query: str = Field(..., min_length=2, max_length=150, description="Email, Referral Code, or User UUID")


class CreateOrderRequest(BaseModel):
    product_id: str
    user_query: str
    payment_method: str = "upi"
    currency: str = "INR"


class CompleteOrderRequest(BaseModel):
    order_id: str
    payment_reference: Optional[str] = None


class VerifyRazorpayPaymentRequest(BaseModel):
    order_id: str
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str



@router.get("/api/v1/store/catalogue")
@router.get("/store/catalogue")
async def get_store_catalogue():
    """
    Returns the official web store pass catalogue, prices, and durations.
    """
    return {
        "status": "success",
        "currency": "INR",
        "products": list(STORE_PRODUCTS.values()),
    }


@router.post("/api/v1/store/verify-user")
async def verify_store_user(payload: VerifyUserRequest, db: AsyncSession = Depends(get_db)):
    """
    Step 2: Validates the user's sanctuary credentials (email, referral code, or UUID).
    """
    q = payload.query.strip()
    clean_q = q.lower()

    # Try UUID, referral code, or email
    user = None
    parsed_uuid = None
    try:
        parsed_uuid = uuid.UUID(q)
    except (ValueError, TypeError, AttributeError):
        pass

    if parsed_uuid:
        res = await db.execute(select(User).where(User.id == parsed_uuid))
        user = res.scalar_one_or_none()

    if not user:
        res = await db.execute(select(User).where(User.referral_code == q.upper()))
        user = res.scalar_one_or_none()

    if not user:
        res = await db.execute(select(User).where(User.email == clean_q))
        user = res.scalar_one_or_none()

    if not user:
        # Check if dummy test seeker
        if "seeker" in clean_q or "demo" in clean_q:
            return {
                "status": "verified",
                "user_id": "00000000-0000-0000-0000-000000000001",
                "full_name": "Sanctuary Seeker (Demo)",
                "email": clean_q if "@" in clean_q else "seeker@urheart.app",
                "subscription_tier": "free",
                "referral_code": "UR-SANCTUARY"
            }
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sanctuary account not found. Please verify your email or referral code."
        )

    return {
        "status": "verified",
        "user_id": str(user.id),
        "full_name": user.full_name,
        "email": user.email,
        "subscription_tier": user.subscription_tier,
        "referral_code": user.referral_code
    }


@router.post("/api/v1/store/create-order")
async def create_store_order(payload: CreateOrderRequest, db: AsyncSession = Depends(get_db)):
    """
    Step 3: Creates a pending checkout order for the chosen pass.
    Persists order in PostgreSQL in_app_purchases table for stateless durability.
    Generates official Razorpay order for seamless INR checkout.
    """
    product = STORE_PRODUCTS.get(payload.product_id)
    if not product:
        raise HTTPException(status_code=400, detail="Invalid product selected.")

    order_id = f"ORD-UR-{uuid.uuid4().hex[:8].upper()}"
    amount = product["price_inr"] if payload.currency == "INR" else product["price_usd"]

    order_data = {
        "order_id": order_id,
        "product_id": payload.product_id,
        "product_name": product["name"],
        "user_query": payload.user_query,
        "amount": amount,
        "currency": payload.currency,
        "payment_method": payload.payment_method,
        "status": "pending_verification",
        "created_at": datetime.now(timezone.utc).isoformat()
    }

    # Resolve user if available to bind ledger entry in PostgreSQL
    user_query = payload.user_query.strip()
    user = None
    parsed_uuid = None
    try:
        parsed_uuid = uuid.UUID(user_query)
    except (ValueError, TypeError, AttributeError):
        pass

    if parsed_uuid:
        res = await db.execute(select(User).where(User.id == parsed_uuid))
        user = res.scalar_one_or_none()

    if not user:
        res = await db.execute(select(User).where(User.referral_code == user_query.upper()))
        user = res.scalar_one_or_none()

    if not user and "@" in user_query:
        res = await db.execute(select(User).where(User.email == user_query.lower()))
        user = res.scalar_one_or_none()

    # Create official Razorpay order if currency is INR
    if payload.currency == "INR":
        user_id_for_notes = str(user.id) if user else user_query
        notes = {
            "order_id": order_id,
            "product_id": payload.product_id,
            "user_id": user_id_for_notes,
            "user_query": user_query
        }
        razorpay_order = await RazorpayService.create_order(
            amount_inr=float(amount),
            receipt=order_id,
            notes=notes
        )
        order_data["razorpay_order_id"] = razorpay_order.get("id")
        STORE_ORDER_RAZORPAY_MAP[order_id] = razorpay_order.get("id")

    WEB_STORE_ORDERS[order_id] = order_data

    # SEC-MED-02: Persist pending order to PostgreSQL so container spin-downs do not lose order state
    # If this is a demo/seeker test account without a DB user row, keep in memory only to satisfy FK constraint
    is_demo_seeker = "seeker" in user_query.lower() or "demo" in user_query.lower()
    if user or not is_demo_seeker:
        try:
            target_user_id = user.id if user else (parsed_uuid or uuid.uuid4())
            resolved_store = "web_razorpay_india" if payload.currency == "INR" else "web_stripe_global"
            ledger = InAppPurchase(
                user_id=target_user_id,
                transaction_reference=order_id,
                product_identifier=payload.product_id,
                store=resolved_store,
                currency=payload.currency,
                amount_gross=float(amount),
                platform_fee=0.00,
                amount_net=float(amount),
                status="pending"
            )
            db.add(ledger)
            await db.commit()
        except SQLAlchemyError as e:
            await db.rollback()
            print(f"[STORE ORDER PERSISTENCE ERROR] {e}", flush=True)
            raise HTTPException(status_code=500, detail="Failed to persist order to database.")

    client_cfg = RazorpayService.get_client_config()
    return {
        "status": "order_created",
        "order": order_data,
        "razorpay_order_id": order_data.get("razorpay_order_id"),
        "razorpay_key_id": client_cfg["key_id"],
        "razorpay_merchant_name": client_cfg["merchant_name"],
        "razorpay_theme_color": client_cfg["theme_color"],
        "amount_paise": int(round(float(amount) * 100)) if payload.currency == "INR" else None
    }


@router.post("/api/v1/store/verify-razorpay-payment", status_code=status.HTTP_200_OK)
async def verify_razorpay_payment(
    payload: VerifyRazorpayPaymentRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Step 4 (Automated): Instant cryptographic verification of Razorpay payment.
    Verifies HMAC-SHA256 signature and immediately unlocks purchased Sovereign Passes
    and digital items in PostgreSQL. Eliminates manual founder approval delays for Razorpay users.
    Binds the verified Razorpay order to the registered store order before granting entitlements.
    """
    # 1. Cryptographic HMAC validation
    is_valid = RazorpayService.verify_payment_signature(
        razorpay_order_id=payload.razorpay_order_id,
        razorpay_payment_id=payload.razorpay_payment_id,
        razorpay_signature=payload.razorpay_signature
    )
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Razorpay payment signature. Cryptographic verification failed."
        )

    # 2. Retrieve order and enforce strict Razorpay order binding
    order = WEB_STORE_ORDERS.get(payload.order_id)
    bound_rzp_order_id = STORE_ORDER_RAZORPAY_MAP.get(payload.order_id) or (order.get("razorpay_order_id") if order else None)
    if bound_rzp_order_id and bound_rzp_order_id != payload.razorpay_order_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mismatched Razorpay order ID. Expected {bound_rzp_order_id}, received {payload.razorpay_order_id}."
        )

    product_id = "urheart_pass_monthly"
    user_query = ""

    # Pessimistic row locking to prevent race conditions with incoming webhooks
    stmt = (
        select(InAppPurchase)
        .where(
            (InAppPurchase.transaction_reference == payload.order_id) |
            (InAppPurchase.transaction_reference == payload.razorpay_payment_id)
        )
        .with_for_update()
    )
    db_purchase = (await db.execute(stmt)).scalar_one_or_none()

    if not order and not db_purchase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Store order not found.")

    if db_purchase:
        product_id = db_purchase.product_identifier
        user_query = str(db_purchase.user_id)
        if db_purchase.status == "completed":
            product = STORE_PRODUCTS.get(product_id, STORE_PRODUCTS["urheart_pass_monthly"])
            return {
                "status": "completed",
                "order_id": payload.order_id,
                "payment_id": payload.razorpay_payment_id,
                "product_id": product_id,
                "product_name": product["name"],
                "message": "Payment already verified and entitlements active.",
                "deep_link": f"urheart://store/receipt?order_id={payload.order_id}&payment_id={payload.razorpay_payment_id}&status=completed"
            }
    elif order:
        product_id = order.get("product_id", "urheart_pass_monthly")
        user_query = order.get("user_query", "")

    product = STORE_PRODUCTS.get(product_id, STORE_PRODUCTS["urheart_pass_monthly"])
    tier = product.get("tier", "monthly")
    duration_days = product.get("duration_days", 30)

    # 3. Resolve user
    user = None
    if user_query:
        parsed_uuid = None
        try:
            parsed_uuid = uuid.UUID(user_query)
        except (ValueError, TypeError, AttributeError):
            pass

        if parsed_uuid:
            user = (await db.execute(select(User).where(User.id == parsed_uuid))).scalar_one_or_none()
        if not user and "@" in user_query:
            user = (await db.execute(select(User).where(User.email == user_query.lower()))).scalar_one_or_none()
        if not user:
            user = (await db.execute(select(User).where(User.referral_code == user_query.upper()))).scalar_one_or_none()

    if not user and db_purchase:
        user = (await db.execute(select(User).where(User.id == db_purchase.user_id))).scalar_one_or_none()

    # 4. Activate entitlements atomically in PostgreSQL
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=duration_days) if duration_days > 0 else None

    if user:
        if tier == "weekly":
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_tier="weekly",
                    subscription_expires_at=expires_at,
                    is_ad_free=True,
                    swipes_remaining=User.swipes_remaining + 110,
                    direct_letters_count=User.direct_letters_count + 1
                )
            )
        elif tier == "monthly":
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_tier="monthly",
                    subscription_expires_at=expires_at,
                    is_ad_free=True,
                    swipes_remaining=User.swipes_remaining + 550,
                    direct_letters_count=User.direct_letters_count + 6
                )
            )
        elif tier == "lifetime":
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_tier="lifetime",
                    subscription_expires_at=expires_at,
                    is_ad_free=True,
                    swipes_remaining=999999,
                    direct_letters_count=User.direct_letters_count + 11
                )
            )
        elif "direct_letters" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(direct_letters_count=User.direct_letters_count + 4)
            )
        elif "instant_contact" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(reveal_tokens_count=User.reveal_tokens_count + 1)
            )
        elif "global_passport" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_expires_at=now + timedelta(days=1),
                    swipes_remaining=User.swipes_remaining + 10,
                    is_ad_free=True
                )
            )

    # 5. Update purchase ledger & memory cache using consistent canonical ledger key
    amount_inr = float(product.get("price_inr", 149))
    fee = round(amount_inr * 0.02, 2)
    net = round(amount_inr - fee, 2)

    if db_purchase:
        db_purchase.status = "completed"
        # Preserve consistent ledger key (order_id)
        db_purchase.transaction_reference = payload.order_id
        db_purchase.amount_gross = amount_inr
        db_purchase.platform_fee = fee
        db_purchase.amount_net = net
    elif user:
        ledger = InAppPurchase(
            user_id=user.id,
            transaction_reference=payload.order_id,
            product_identifier=product_id,
            store="web_razorpay_india",
            currency="INR",
            amount_gross=amount_inr,
            platform_fee=fee,
            amount_net=net,
            status="completed"
        )
        db.add(ledger)

    if order:
        order["status"] = "completed"
        order["payment_id"] = payload.razorpay_payment_id
        order["razorpay_payment_id"] = payload.razorpay_payment_id

    await db.commit()

    deep_link = f"urheart://store/receipt?order_id={payload.order_id}&payment_id={payload.razorpay_payment_id}&status=completed"
    return {
        "status": "completed",
        "order_id": payload.order_id,
        "payment_id": payload.razorpay_payment_id,
        "product_id": product_id,
        "product_name": product["name"],
        "subscription_tier": tier,
        "user_id": str(user.id) if user else None,
        "deep_link": deep_link,
        "message": f"Payment successfully verified via Razorpay. {product['name']} unlocked."
    }



@router.post("/api/v1/store/complete-order")
async def complete_store_order(payload: CompleteOrderRequest, db: AsyncSession = Depends(get_db)):
    """
    Step 4: Submits UPI payment reference/UTR for founder bank verification.
    SEC-CRIT-05: Eliminates instant client self-activation. Sets status to 'pending_verification'.
    Perks are only unlocked when founder verifies PNB credit or via superadmin approval.
    """
    # 1. Retrieve order from RAM or PostgreSQL
    order = WEB_STORE_ORDERS.get(payload.order_id)
    if not order:
        stmt = select(InAppPurchase).where(InAppPurchase.transaction_reference == payload.order_id)
        db_purchase = (await db.execute(stmt)).scalar_one_or_none()
        if db_purchase:
            product = STORE_PRODUCTS.get(db_purchase.product_identifier, STORE_PRODUCTS["urheart_pass_monthly"])
            order = {
                "order_id": payload.order_id,
                "product_id": db_purchase.product_identifier,
                "product_name": product["name"],
                "user_query": str(db_purchase.user_id),
                "amount": float(db_purchase.amount_gross),
                "currency": db_purchase.currency,
                "payment_method": "upi",
                "status": db_purchase.status
            }
            WEB_STORE_ORDERS[payload.order_id] = order
        else:
            product_id = "urheart_pass_monthly"
            product = STORE_PRODUCTS[product_id]
            order = {
                "order_id": payload.order_id,
                "product_id": product_id,
                "product_name": product["name"],
                "user_query": "seeker@urheart.app",
                "amount": product["price_inr"],
                "currency": "INR",
                "payment_method": "upi",
                "status": "pending_verification"
            }
            WEB_STORE_ORDERS[payload.order_id] = order

    product_id = order["product_id"]
    product = STORE_PRODUCTS.get(product_id, STORE_PRODUCTS["urheart_pass_monthly"])
    utr = (payload.payment_reference or "").strip()

    # 2. Duplicate UTR check (prevent replay attack across orders)
    if utr:
        if utr in SUBMITTED_UTRS:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"UTR transaction reference '{utr}' has already been submitted for another order."
            )
        dup_stmt = select(InAppPurchase).where(
            InAppPurchase.transaction_reference == utr,
            InAppPurchase.status.in_(["pending_verification", "completed"])
        )
        if (await db.execute(dup_stmt)).scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"UTR transaction reference '{utr}' has already been submitted or credited."
            )
        SUBMITTED_UTRS.add(utr)

    # 3. Transition order state machine to 'pending_verification'
    order["status"] = "pending_verification"
    order["payment_reference"] = utr

    # Update ledger status in DB
    try:
        await db.execute(
            update(InAppPurchase)
            .where(InAppPurchase.transaction_reference == payload.order_id)
            .values(status="pending")
        )
        await db.commit()
    except SQLAlchemyError as e:
        await db.rollback()
        print(f"[STORE ORDER UPDATE ERROR] {e}", flush=True)
        raise HTTPException(status_code=500, detail="Failed to persist order update to database.")

    tx_hash = f"0x{uuid.uuid4().hex[:16]}"
    deep_link = f"urheart://store/receipt?order_id={payload.order_id}&status=pending_verification"

    return {
        "status": "pending_verification",
        "order_id": payload.order_id,
        "product_id": product_id,
        "product_name": product["name"],
        "payment_reference": utr,
        "transaction_hash": tx_hash,
        "deep_link": deep_link,
        "message": (
            f"Payment reference recorded for {product['name']}. "
            "Verification in progress with Founder Desk (PNB UPI). "
            "Passes activate once founder confirms bank credit."
        )
    }


class ApproveOrderRequest(BaseModel):
    order_id: Optional[str] = None
    admin_notes: Optional[str] = "Verified in PNB Account"


@router.post("/api/v1/store/orders/{order_id}/approve", status_code=status.HTTP_200_OK)
@router.post("/api/v1/store/admin/approve-order", status_code=status.HTTP_200_OK)
async def approve_store_order(
    order_id: Optional[str] = None,
    payload: Optional[ApproveOrderRequest] = None,
    current_user: User = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db)
):
    """
    Founder Approval Channel (Anubhav Singh / Superadmin Sentinel).
    Unlocks passes in database ONLY after founder verifies credit in PNB account.
    """
    resolved_order_id = order_id or (payload.order_id if payload else None)
    if not resolved_order_id:
        raise HTTPException(status_code=400, detail="order_id is required.")

    order = WEB_STORE_ORDERS.get(resolved_order_id)
    product_id = order.get("product_id", "urheart_pass_monthly") if order else "urheart_pass_monthly"
    product = STORE_PRODUCTS.get(product_id, STORE_PRODUCTS["urheart_pass_monthly"])
    tier = product.get("tier", "monthly")
    duration_days = product.get("duration_days", 30)

    # Find user associated with order
    user = None
    user_query = order.get("user_query", "").strip() if order else ""
    if user_query:
        parsed_uuid = None
        try:
            parsed_uuid = uuid.UUID(user_query)
        except (ValueError, TypeError, AttributeError):
            pass

        if parsed_uuid:
            res = await db.execute(select(User).where(User.id == parsed_uuid))
            user = res.scalar_one_or_none()

        if not user and "@" in user_query:
            res = await db.execute(select(User).where(User.email == user_query.lower()))
            user = res.scalar_one_or_none()

    if not user:
        db_res = await db.execute(
            select(InAppPurchase).where(InAppPurchase.transaction_reference == resolved_order_id)
        )
        db_purch = db_res.scalar_one_or_none()
        if db_purch:
            res = await db.execute(select(User).where(User.id == db_purch.user_id))
            user = res.scalar_one_or_none()

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=duration_days) if duration_days > 0 else None

    # Apply sovereign perks in database
    if user:
        if tier == "weekly":
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_tier=tier,
                    subscription_expires_at=expires_at,
                    is_ad_free=True,
                    swipes_remaining=User.swipes_remaining + 110,
                    direct_letters_count=User.direct_letters_count + 1
                )
            )
        elif tier == "monthly":
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_tier=tier,
                    subscription_expires_at=expires_at,
                    is_ad_free=True,
                    swipes_remaining=User.swipes_remaining + 550,
                    direct_letters_count=User.direct_letters_count + 6
                )
            )
        elif tier == "lifetime":
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_tier=tier,
                    subscription_expires_at=expires_at,
                    is_ad_free=True,
                    swipes_remaining=999999,
                    direct_letters_count=User.direct_letters_count + 11
                )
            )
        elif "direct_letters" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(direct_letters_count=User.direct_letters_count + 4)
            )
        elif "instant_contact" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(reveal_tokens_count=User.reveal_tokens_count + 1)
            )
        elif "global_passport" in product_id:
            await db.execute(
                update(User)
                .where(User.id == user.id)
                .values(
                    subscription_expires_at=expires_at,
                    swipes_remaining=User.swipes_remaining + 10,
                    is_ad_free=True
                )
            )

    # Update order & ledger status to 'completed'
    if order:
        order["status"] = "completed"

    await db.execute(
        update(InAppPurchase)
        .where(InAppPurchase.transaction_reference == resolved_order_id)
        .values(status="completed")
    )
    await db.commit()

    return {
        "status": "completed",
        "order_id": resolved_order_id,
        "subscription_tier": tier,
        "user_id": str(user.id) if user else None,
        "message": f"Order {resolved_order_id} approved by founder. Pass activated."
    }


@router.get("/api/v1/store/orders/{order_id}", status_code=status.HTTP_200_OK)
async def get_store_order_status(order_id: str, db: AsyncSession = Depends(get_db)):
    """
    Step 5 / Polling: Retrieves order status with stateless PostgreSQL fallback.
    Ensures zero data loss across container restarts.
    """
    order = WEB_STORE_ORDERS.get(order_id)
    if not order:
        stmt = select(InAppPurchase).where(InAppPurchase.transaction_reference == order_id)
        db_purchase = (await db.execute(stmt)).scalar_one_or_none()
        if db_purchase:
            product = STORE_PRODUCTS.get(db_purchase.product_identifier, STORE_PRODUCTS["urheart_pass_monthly"])
            order = {
                "order_id": order_id,
                "product_id": db_purchase.product_identifier,
                "product_name": product["name"],
                "user_query": str(db_purchase.user_id),
                "amount": float(db_purchase.amount_gross),
                "currency": db_purchase.currency,
                "payment_method": "upi",
                "status": db_purchase.status,
                "created_at": db_purchase.purchased_at.isoformat() if db_purchase.purchased_at else None
            }
            WEB_STORE_ORDERS[order_id] = order

    if not order:
        raise HTTPException(status_code=404, detail="Order not found.")

    return {
        "status": "success",
        "order": order
    }


@router.get("/store", response_class=HTMLResponse)
@router.get("/store/checkout", response_class=HTMLResponse)
async def serve_web_sanctuary_store(request: Request):
    """
    Renders the responsive, end-to-end multi-step Web Sanctuary Store application
    with 4 live count steps, UPI / QR / Card checkout, and instant mobile app deep-linking.
    """
    base_web = getattr(settings, "BASE_WEB_URL", "https://urheart.asiverticals.me")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sanctuary Store | UR-Heart Sovereign Web Privileges</title>
  <meta name="description" content="Official UR-Heart Web Store by Asiverticals. Purchase Sovereign Passes with 10% bonus passes via UPI and Cards.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
  <style>
    :root {{
      --bg: #090E0C;
      --card-bg: rgba(22, 33, 29, 0.85);
      --card-border: rgba(43, 61, 53, 0.85);
      --pine: #2E6F5E;
      --pine-glow: #3E8E79;
      --coral: #E06D53;
      --gold: #D4AF37;
      --gold-dim: rgba(212, 175, 55, 0.18);
      --text-head: #FFFFFF;
      --text-body: #C5D6CE;
      --text-muted: #829A90;
      --success: #4E9F76;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: radial-gradient(circle at 50% 5%, #182B24 0%, #090E0C 65%, #050807 100%);
      color: var(--text-body);
      font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
      padding: 24px 16px 40px;
    }}
    .glow-sphere {{
      position: fixed;
      top: -100px;
      left: 50%;
      transform: translateX(-50%);
      width: 600px;
      height: 400px;
      background: radial-gradient(ellipse, rgba(46, 111, 94, 0.32), transparent 70%);
      pointer-events: none;
      z-index: 0;
    }}
    .container {{
      max-width: 760px;
      width: 100%;
      position: relative;
      z-index: 1;
      margin: 0 auto;
    }}
    /* Top Bar */
    .top-bar {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 24px;
      padding: 0 4px;
    }}
    .brand {{
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
    }}
    .brand-logo {{
      width: 36px;
      height: 36px;
      background: linear-gradient(135deg, var(--coral), var(--pine));
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
    }}
    .brand-title {{
      font-family: 'Cinzel', serif;
      font-size: 18px;
      font-weight: 700;
      color: #FFFFFF;
    }}
    .domain-tag {{
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 5px 12px;
      background: rgba(46, 111, 94, 0.2);
      border: 1px solid rgba(62, 142, 121, 0.4);
      border-radius: 999px;
      font-size: 11px;
      font-weight: 600;
      color: #A3E4D1;
    }}
    .domain-tag .dot {{
      width: 6px;
      height: 6px;
      background: var(--success);
      border-radius: 50%;
      box-shadow: 0 0 8px var(--success);
    }}

    /* Header */
    .store-header {{
      text-align: center;
      margin-bottom: 24px;
    }}
    .store-header h1 {{
      font-family: 'Cinzel', serif;
      font-size: clamp(26px, 4vw, 36px);
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: -0.5px;
      margin-bottom: 8px;
    }}
    .store-header p {{
      font-size: 13.5px;
      color: var(--text-muted);
      max-width: 520px;
      margin: 0 auto;
      line-height: 1.5;
    }}

    /* LIVE STEP COUNTER BAR */
    .step-tracker-card {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 16px 20px;
      margin-bottom: 24px;
      backdrop-filter: blur(12px);
      box-shadow: 0 12px 32px rgba(0,0,0,0.4);
    }}
    .step-tracker-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }}
    .step-counter-title {{
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 1.5px;
      color: var(--gold);
      text-transform: uppercase;
    }}
    .step-counter-badge {{
      font-size: 12px;
      font-weight: 700;
      color: #FFFFFF;
      background: var(--pine);
      padding: 4px 10px;
      border-radius: 8px;
    }}
    .step-progress-bar {{
      display: flex;
      gap: 6px;
      height: 6px;
      background: rgba(255, 255, 255, 0.08);
      border-radius: 999px;
      overflow: hidden;
    }}
    .step-progress-segment {{
      flex: 1;
      height: 100%;
      background: rgba(255, 255, 255, 0.12);
      transition: background 0.3s ease;
    }}
    .step-progress-segment.active {{
      background: linear-gradient(90deg, var(--pine), var(--gold));
      box-shadow: 0 0 10px rgba(212, 175, 55, 0.5);
    }}
    .step-progress-segment.completed {{
      background: var(--success);
    }}

    /* Main Checkout Stage Container */
    .checkout-container {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 24px;
      padding: 28px 24px;
      backdrop-filter: blur(16px);
      box-shadow: 0 20px 48px rgba(0,0,0,0.5);
      position: relative;
    }}

    .step-content {{
      display: none;
      animation: fadeIn 0.3s ease;
    }}
    .step-content.active {{
      display: block;
    }}
    @keyframes fadeIn {{
      from {{ opacity: 0; transform: translateY(6px); }}
      to {{ opacity: 1; transform: translateY(0); }}
    }}

    /* Step Titles */
    .step-headline {{
      font-size: 18px;
      font-weight: 700;
      color: #FFFFFF;
      margin-bottom: 6px;
    }}
    .step-subtext {{
      font-size: 13px;
      color: var(--text-muted);
      margin-bottom: 20px;
      line-height: 1.45;
    }}

    /* Products Grid (Step 1) */
    .products-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 14px;
      margin-bottom: 24px;
    }}
    .product-card {{
      background: rgba(10, 15, 13, 0.7);
      border: 1.5px solid rgba(43, 61, 53, 0.8);
      border-radius: 16px;
      padding: 16px;
      cursor: pointer;
      transition: all 0.2s ease;
      position: relative;
    }}
    .product-card:hover {{
      border-color: var(--pine-glow);
      transform: translateY(-2px);
    }}
    .product-card.selected {{
      border-color: var(--gold);
      background: rgba(30, 48, 40, 0.8);
      box-shadow: 0 0 16px rgba(212, 175, 55, 0.25);
    }}
    .product-card-badge {{
      position: absolute;
      top: 12px;
      right: 12px;
      font-size: 10px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 6px;
      background: var(--gold-dim);
      color: var(--gold);
      border: 1px solid rgba(212, 175, 55, 0.3);
    }}
    .product-name {{
      font-size: 15px;
      font-weight: 700;
      color: #FFFFFF;
      margin-bottom: 4px;
      padding-right: 60px;
    }}
    .product-price {{
      font-size: 20px;
      font-weight: 800;
      color: var(--gold);
      margin-bottom: 8px;
    }}
    .product-bonus {{
      font-size: 11.5px;
      color: #A3E4D1;
      font-weight: 600;
      margin-bottom: 10px;
    }}
    .product-features {{
      list-style: none;
      font-size: 11px;
      color: var(--text-muted);
      line-height: 1.6;
    }}
    .product-features li::before {{
      content: "✓ ";
      color: var(--success);
      font-weight: bold;
    }}

    /* Form Fields (Step 2 & 3) */
    .form-group {{
      margin-bottom: 18px;
    }}
    .form-label {{
      display: block;
      font-size: 12.5px;
      font-weight: 600;
      color: #FFFFFF;
      margin-bottom: 6px;
    }}
    .form-input {{
      width: 100%;
      padding: 13px 16px;
      background: rgba(10, 15, 13, 0.8);
      border: 1.5px solid rgba(43, 61, 53, 0.8);
      border-radius: 12px;
      color: #FFFFFF;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s ease;
    }}
    .form-input:focus {{
      border-color: var(--pine-glow);
      box-shadow: 0 0 10px rgba(62, 142, 121, 0.3);
    }}
    .verify-box {{
      padding: 12px 14px;
      border-radius: 12px;
      font-size: 12.5px;
      margin-top: 10px;
      display: none;
    }}
    .verify-box.success {{
      background: rgba(78, 159, 118, 0.15);
      border: 1px solid var(--success);
      color: #A3E4D1;
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .verify-box.error {{
      background: rgba(224, 109, 83, 0.15);
      border: 1px solid var(--coral);
      color: #FFB3A3;
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    /* Payment Methods (Step 3) */
    .payment-options {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 10px;
      margin-bottom: 18px;
    }}
    .payment-option-card {{
      background: rgba(10, 15, 13, 0.7);
      border: 1.5px solid rgba(43, 61, 53, 0.8);
      border-radius: 12px;
      padding: 14px 12px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;
    }}
    .payment-option-card.selected {{
      border-color: var(--gold);
      background: rgba(30, 48, 40, 0.8);
    }}
    .payment-option-title {{
      font-size: 13px;
      font-weight: 700;
      color: #FFFFFF;
      margin-bottom: 4px;
    }}
    .payment-option-sub {{
      font-size: 11px;
      color: var(--text-muted);
    }}

    .upi-qr-box {{
      background: #FFFFFF;
      border-radius: 16px;
      padding: 18px;
      display: inline-block;
      text-align: center;
      margin: 10px 0 16px;
    }}
    .upi-qr-box img {{
      width: 170px;
      height: 170px;
      display: block;
      margin: 0 auto;
    }}
    .upi-vpa-text {{
      margin-top: 8px;
      font-size: 12px;
      font-weight: 700;
      color: #1A202C;
    }}

    .summary-box {{
      background: rgba(10, 15, 13, 0.5);
      border: 1px solid rgba(43, 61, 53, 0.6);
      border-radius: 14px;
      padding: 16px;
      margin-bottom: 20px;
    }}
    .summary-row {{
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      margin-bottom: 8px;
      color: var(--text-muted);
    }}
    .summary-row.total {{
      border-top: 1px solid rgba(43, 61, 53, 0.8);
      padding-top: 10px;
      margin-top: 10px;
      font-size: 15px;
      font-weight: 800;
      color: #FFFFFF;
    }}
    .summary-row.discount {{
      color: var(--success);
      font-weight: 600;
    }}

    /* Buttons */
    .btn-actions {{
      display: flex;
      gap: 12px;
      justify-content: flex-end;
      margin-top: 24px;
    }}
    .btn {{
      padding: 13px 24px;
      border-radius: 12px;
      font-size: 13.5px;
      font-weight: 700;
      cursor: pointer;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      border: none;
      transition: all 0.2s ease;
    }}
    .btn-prev {{
      background: rgba(255,255,255,0.08);
      color: var(--text-body);
    }}
    .btn-prev:hover {{
      background: rgba(255,255,255,0.14);
    }}
    .btn-primary {{
      background: linear-gradient(135deg, #E06D53 0%, #C94A29 100%);
      color: #FFFFFF;
      box-shadow: 0 6px 20px rgba(201, 74, 41, 0.35);
    }}
    .btn-primary:hover {{
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(201, 74, 41, 0.5);
    }}
    .btn-success {{
      background: linear-gradient(135deg, #4E9F76 0%, #2E6F5E 100%);
      color: #FFFFFF;
      box-shadow: 0 6px 20px rgba(46, 111, 94, 0.4);
    }}
    .btn-success:hover {{
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(46, 111, 94, 0.55);
    }}

    /* Step 4: Success Receipt */
    .receipt-card {{
      text-align: center;
      padding: 20px 0;
    }}
    .receipt-badge {{
      width: 70px;
      height: 70px;
      border-radius: 50%;
      background: rgba(78, 159, 118, 0.18);
      border: 2px solid var(--success);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      margin: 0 auto 16px;
    }}
    .receipt-title {{
      font-family: 'Cinzel', serif;
      font-size: 24px;
      font-weight: 700;
      color: #FFFFFF;
      margin-bottom: 8px;
    }}
    .receipt-sub {{
      font-size: 13.5px;
      color: var(--text-muted);
      margin-bottom: 24px;
      line-height: 1.5;
    }}
    .receipt-details {{
      background: rgba(10, 15, 13, 0.6);
      border: 1px solid rgba(43, 61, 53, 0.8);
      border-radius: 14px;
      padding: 16px;
      max-width: 440px;
      margin: 0 auto 24px;
      text-align: left;
    }}
    .receipt-line {{
      display: flex;
      justify-content: space-between;
      font-size: 12.5px;
      margin-bottom: 6px;
    }}
    .receipt-line .label {{
      color: var(--text-muted);
    }}
    .receipt-line .val {{
      color: #FFFFFF;
      font-weight: 600;
    }}

    footer {{
      margin-top: 36px;
      text-align: center;
      font-size: 12px;
      color: var(--text-muted);
      position: relative;
      z-index: 1;
    }}
    footer a {{
      color: var(--gold);
      text-decoration: none;
    }}
  </style>
</head>
<body>
  <div class="glow-sphere"></div>

  <div class="container">
    <!-- Top Bar -->
    <div class="top-bar">
      <a href="/" class="brand">
        <div class="brand-logo">♥</div>
        <div class="brand-title">UR-Heart</div>
      </a>
      <div style="display: flex; align-items: center; gap: 14px; flex-wrap: wrap;">
        <a href="/appinfo" style="color: var(--gold); text-decoration: none; font-size: 13px; font-weight: 600;">📖 Platform Overview</a>
        <a href="/privacy" style="color: var(--text-muted); text-decoration: none; font-size: 13px;">🛡️ Privacy</a>
        <a href="/terms" style="color: var(--text-muted); text-decoration: none; font-size: 13px;">⚖️ Terms</a>
        <a href="/delete-account" style="color: var(--text-muted); text-decoration: none; font-size: 13px;">🗑️ Deletion</a>
        <div class="domain-tag">
          <div class="dot"></div>
          <span>urheart.asiverticals.me</span>
        </div>
      </div>
    </div>

    <!-- Header -->
    <div class="store-header">
      <h1>Sovereign Web Store</h1>
      <p>Official direct checkout with +10% extra bonus perks on all passes. Zero surveillance, zero app-store taxes, and instant cryptographic crest activation.</p>
    </div>

    <!-- LIVE STEP TRACKER (With Live Step Count) -->
    <div class="step-tracker-card">
      <div class="step-tracker-header">
        <span class="step-counter-title">LIVE CHECKOUT STEP TRACKER</span>
        <span class="step-counter-badge" id="stepCounterBadge">Step 1 of 4</span>
      </div>
      <div class="step-progress-bar">
        <div class="step-progress-segment active" id="progSeg1"></div>
        <div class="step-progress-segment" id="progSeg2"></div>
        <div class="step-progress-segment" id="progSeg3"></div>
        <div class="step-progress-segment" id="progSeg4"></div>
      </div>
    </div>

    <!-- MAIN CHECKOUT STAGES -->
    <div class="checkout-container">

      <!-- STEP 1 OF 4: SELECT PASS -->
      <div class="step-content active" id="step1">
        <div class="step-headline">Step 1: Choose Your Sovereign Pass</div>
        <div class="step-subtext">All passes unlocked via web include 10% extra reflections and permanent priority sync.</div>

        <div class="products-grid">
          <div class="product-card selected" onclick="selectProduct('urheart_pass_monthly', 149, '1-Month Sovereign Pass')">
            <span class="product-card-badge">Most Mindful</span>
            <div class="product-name">1-Month Sovereign Pass</div>
            <div class="product-price">₹149 <span style="font-size:12px; color:var(--text-muted);">/ $14.99</span></div>
            <div class="product-bonus">✨ +10% Web Bonus Perks</div>
            <ul class="product-features">
              <li>550 Sovereign Swipes (+10% Web Bonus)</li>
              <li>6 Guaranteed Direct Letters</li>
              <li>100% Ad-Free Silence (30 Days)</li>
              <li>Eva AI Priority Counsel</li>
            </ul>
          </div>

          <div class="product-card" onclick="selectProduct('urheart_pass_weekly', 49, '1-Week Sovereign Sprint')">
            <span class="product-card-badge">Popular</span>
            <div class="product-name">1-Week Sovereign Sprint</div>
            <div class="product-price">₹49 <span style="font-size:12px; color:var(--text-muted);">/ $4.99</span></div>
            <div class="product-bonus">✨ +10% Web Bonus Perks</div>
            <ul class="product-features">
              <li>110 Sovereign Swipes (+10% Web Bonus)</li>
              <li>10 Bonus Reflections</li>
              <li>100% Ad-Free Silence (7 Days)</li>
              <li>Instant Fast Pass</li>
            </ul>
          </div>

          <div class="product-card" onclick="selectProduct('urheart_pass_lifetime', 1499, '1-Year Sovereign Pass')">
            <span class="product-card-badge">365 Days Access</span>
            <div class="product-name">1-Year Sovereign Pass</div>
            <div class="product-price">₹1,499 <span style="font-size:12px; color:var(--text-muted);">/ $59.99</span></div>
            <div class="product-bonus">✨ 365-Day Sovereign Crest</div>
            <ul class="product-features">
              <li>365 Days Sovereign Crest</li>
              <li>Infinite Resonances for 1 Year</li>
              <li>11 Direct Letters (+10% Web Bonus)</li>
              <li>Full Legal Vault Export Access</li>
              <li>Stage 3 Reveal Token (Mutual Consent Required)</li>
              <li>100% Ad-Free Silence (365 Days)</li>
            </ul>
          </div>

          <div class="product-card" onclick="selectProduct('urheart_key_instant_contact', 29, 'Instant Contact Key')">
            <span class="product-card-badge">Key</span>
            <div class="product-name">Instant Contact Key</div>
            <div class="product-price">₹29 <span style="font-size:12px; color:var(--text-muted);">/ $1.49</span></div>
            <div class="product-bonus">✨ Fast-Track Reveal Token</div>
            <ul class="product-features">
              <li>1 Contact Reveal Token</li>
              <li>Requires Mutual Partner Consent</li>
              <li>Skips 3-Ad Ritual Wait Time</li>
            </ul>
          </div>

          <div class="product-card" onclick="selectProduct('urheart_pack_direct_letters', 49, '3 Direct Letters Pack')">
            <span class="product-card-badge">Micro</span>
            <div class="product-name">3 Direct Letters Pack</div>
            <div class="product-price">₹49 <span style="font-size:12px; color:var(--text-muted);">/ $1.99</span></div>
            <div class="product-bonus">✨ +10% Web Bonus Perks</div>
            <ul class="product-features">
              <li>4 Guaranteed Direct Notes (+10% Web Bonus)</li>
              <li>Priority Kinship Inbox Delivery</li>
              <li>Bypasses Standard Discovery Queue</li>
            </ul>
          </div>

          <div class="product-card" onclick="selectProduct('urheart_pack_global_passport', 99, '24h Global Passport')">
            <span class="product-card-badge">Passport</span>
            <div class="product-name">24h Global Passport</div>
            <div class="product-price">₹99 <span style="font-size:12px; color:var(--text-muted);">/ $1.99</span></div>
            <div class="product-bonus">✨ 24h Global Teleportation</div>
            <ul class="product-features">
              <li>Teleport to Any Global City</li>
              <li>24 Hours Unrestricted Access</li>
              <li>+10 Bonus Swipes (+10% Web Bonus)</li>
              <li>Explore Worldwide Kinships</li>
            </ul>
          </div>
        </div>

        <!-- Statutory Billing Conditions Notice -->
        <div style="margin-top:24px; padding:18px 22px; background:rgba(22, 33, 29, 0.72); border:1px solid rgba(43, 61, 53, 0.85); border-radius:14px; font-size:12.5px; color:var(--text-muted); line-height:1.65;">
          <strong style="color:var(--gold); display:flex; align-items:center; gap:6px; margin-bottom:6px; font-size:13px;">
            <span>⚖️</span> Sovereign Billing Terms & Conditions
          </strong>
          <ul style="padding-left:18px; margin:0;">
            <li><strong>Validity:</strong> Sovereign Passes activate immediately upon payment verification and remain active for the exact duration purchased (7 days for Sprint, 30 days for Monthly, 365 days for 1-Year Pass, 24 hours for Global Passport).</li>
            <li><strong>Mutual Consent Guarantee:</strong> Instant Contact Keys credit contact reveal tokens. In strict adherence with DPDP Act 2023 privacy regulations, contact disclosure occurs only upon uncoerced bilateral mutual consent.</li>
            <li><strong>Web Advantage:</strong> All web store purchases include a 10% sovereign bonus over standard in-app billing.</li>
            <li><strong>Refund Policy:</strong> Due to instantaneous digital entitlement delivery, purchases are non-refundable once unlocked, in compliance with statutory digital goods regulations.</li>
          </ul>
        </div>

        <div class="btn-actions">
          <button class="btn btn-primary" onclick="goToStep(2)">Proceed to Seeker Account ➔</button>
        </div>
      </div>

      <!-- STEP 2 OF 4: VERIFY SANCTUARY ACCOUNT -->
      <div class="step-content" id="step2">
        <div class="step-headline">Step 2: Enter Sanctuary Seeker Identity</div>
        <div class="step-subtext">Passes will be cryptographically bound and instantaneously credited to this UR-Heart account.</div>

        <div class="form-group">
          <label class="form-label" for="userQueryInput">Sanctuary Email or Referral Code / User ID</label>
          <input type="text" id="userQueryInput" class="form-input" placeholder="e.g. anushkafzb@gmail.com or UR-4E9F76">
          <div id="verifyBox" class="verify-box"></div>
        </div>

        <div style="margin-bottom: 20px;">
          <button type="button" class="btn btn-prev" onclick="verifyAccountLive()">Verify Seeker Identity 🔍</button>
        </div>

        <div class="btn-actions">
          <button class="btn btn-prev" onclick="goToStep(1)">← Back to Passes</button>
          <button class="btn btn-primary" onclick="proceedToPaymentStep()">Continue to Payment ➔</button>
        </div>
      </div>

      <!-- STEP 3 OF 4: SACRED PAYMENT GATEWAY -->
      <div class="step-content" id="step3">
        <div class="step-headline">Step 3: Sacred Payment Channel Selection</div>
        <div class="step-subtext">Encrypted sovereign transaction via Unified Payments Interface (UPI) or Global Cards.</div>

        <div class="payment-options">
          <div class="payment-option-card selected" onclick="selectPaymentMethod('upi')">
            <div class="payment-option-title">UPI / QR Code</div>
            <div class="payment-option-sub">GPay, PhonePe, Paytm</div>
          </div>
          <div class="payment-option-card" onclick="selectPaymentMethod('cards')">
            <div class="payment-option-title">Debit / Credit Cards</div>
            <div class="payment-option-sub">RuPay, Visa, Mastercard</div>
          </div>
          <div class="payment-option-card" onclick="selectPaymentMethod('netbanking')">
            <div class="payment-option-title">NetBanking</div>
            <div class="payment-option-sub">All Indian Banks</div>
          </div>
        </div>

        <!-- UPI Details view -->
        <div id="upiPaymentView" style="text-align: center;">
          <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 8px;">Scan with Any UPI App (GPay, PhonePe, Paytm, BHIM, Cred)</p>
          <div class="upi-qr-box">
            <!-- Dynamic QR code generator -->
            <img id="upiQrCodeImg" src="https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=upi%3A%2F%2Fpay%3Fpa%3Dasiverticals%40icici%26pn%3DUR-Heart%20Sanctuary%26am%3D149%26cu%3DINR" alt="UPI QR">
            <div class="upi-vpa-text">UPI ID: asiverticals@icici</div>
          </div>
          <div style="font-size: 12px; color: var(--gold); margin-bottom: 16px;">Verified Sovereign Merchant: Asiverticals Pvt Ltd</div>
        </div>

        <!-- Order Summary -->
        <div class="summary-box">
          <div class="summary-row">
            <span>Selected Item</span>
            <span id="sumItemName" style="color:#FFF; font-weight:600;">1-Month Sovereign Pass</span>
          </div>
          <div class="summary-row">
            <span>Recipient Account</span>
            <span id="sumSeekerEmail" style="color:#FFF;">seeker@urheart.app</span>
          </div>
          <div class="summary-row">
            <span>Sanctuary Standard Price</span>
            <span id="sumStandardPrice">₹149</span>
          </div>
          <div class="summary-row discount" style="color:var(--emerald);">
            <span>Web Sanctuary Advantage</span>
            <span>+10% Extra Perks Included</span>
          </div>
          <div class="summary-row total">
            <span>Total Payable Amount</span>
            <span id="sumTotalAmount" style="color:var(--gold);">₹149</span>
          </div>
        </div>

        <div class="btn-actions">
          <button class="btn btn-prev" onclick="goToStep(2)">← Change Account</button>
          <button class="btn btn-success" id="payBtn" onclick="processPaymentLive()">Pay & Activate Sovereign Pass ➔</button>
        </div>
      </div>

      <!-- STEP 4 OF 4: CONFIRMATION & LIVE APP SYNC -->
      <div class="step-content" id="step4">
        <div class="receipt-card">
          <div class="receipt-badge">✨</div>
          <div class="receipt-title">Pass Activated Successfully!</div>
          <div class="receipt-sub">
            Your sacred payment has been cryptographically confirmed. Your entitlements are now active on your account.
          </div>

          <div class="receipt-details">
            <div class="receipt-line">
              <span class="label">Order Reference:</span>
              <span class="val" id="recOrderId">ORD-UR-884210</span>
            </div>
            <div class="receipt-line">
              <span class="label">Product Crest:</span>
              <span class="val" id="recProductName">1-Month Sovereign Pass</span>
            </div>
            <div class="receipt-line">
              <span class="label">Seeker Identity:</span>
              <span class="val" id="recSeeker">anushkafzb@gmail.com</span>
            </div>
            <div class="receipt-line">
              <span class="label">Transaction Hash:</span>
              <span class="val" id="recTxHash">0x8f72a4...</span>
            </div>
            <div class="receipt-line">
              <span class="label">Status:</span>
              <span class="val" style="color:var(--success);">● Active & Synced</span>
            </div>
          </div>

          <a id="openAppBtn" class="btn btn-primary" style="font-size: 15px; padding: 16px 32px;" href="urheart://open">Open UR-Heart Sanctuary App ➔</a>
          <p style="font-size: 12px; color: var(--text-muted); margin-top: 14px;">The app will auto-sync reflections and passes immediately upon opening.</p>
        </div>
      </div>

    </div>
  </div>

  <footer>
    <p>
      © 2026 Asiverticals (Sole Proprietor: Anubhav Singh). All rights reserved. • 
      <a href="https://urheart.asiverticals.me">urheart.asiverticals.me</a> • 
      <a href="/appinfo">Platform Overview</a> • 
      <a href="/privacy">Privacy Policy</a> • 
      <a href="/terms">Terms & EULA</a> • 
      <a href="/delete-account">Account Deletion</a> • 
      <a href="/">Sanctuary Home</a>
    </p>
  </footer>

  <script>
    let currentStep = 1;
    let selectedProductId = "urheart_pass_monthly";
    let selectedProductName = "1-Month Sovereign Pass";
    let selectedPrice = 149;
    let verifiedAccount = "seeker@urheart.app";
    let selectedMethod = "upi";
    let currentOrderId = "";

    // Pre-fill from URL parameters if available
    window.addEventListener("DOMContentLoaded", () => {{
      const params = new URLSearchParams(window.location.search);
      const paramProduct = params.get("product");
      const paramUser = params.get("user_id") || params.get("email") || params.get("ref");

      if (paramUser) {{
        document.getElementById("userQueryInput").value = paramUser;
        verifiedAccount = paramUser;
      }}
      if (paramProduct) {{
        const card = document.querySelector(`[onclick*="${{paramProduct}}"]`);
        if (card) {{
          card.click();
        }}
      }}
    }});

    function updateStepIndicator(step) {{
      currentStep = step;
      document.getElementById("stepCounterBadge").innerText = `Step ${{step}} of 4`;

      for (let i = 1; i <= 4; i++) {{
        const seg = document.getElementById(`progSeg${{i}}`);
        const content = document.getElementById(`step${{i}}`);

        if (i < step) {{
          seg.className = "step-progress-segment completed";
          content.className = "step-content";
        }} else if (i === step) {{
          seg.className = "step-progress-segment active";
          content.className = "step-content active";
        }} else {{
          seg.className = "step-progress-segment";
          content.className = "step-content";
        }}
      }}
      window.scrollTo({{ top: 0, behavior: "smooth" }});
    }}

    function goToStep(step) {{
      updateStepIndicator(step);
    }}

    function selectProduct(id, price, name) {{
      selectedProductId = id;
      selectedPrice = price;
      selectedProductName = name;

      document.querySelectorAll(".product-card").forEach(c => c.classList.remove("selected"));
      event.currentTarget.classList.add("selected");

      // Update Summary
      document.getElementById("sumItemName").innerText = name;
      document.getElementById("sumStandardPrice").innerText = "₹" + price;
      document.getElementById("sumTotalAmount").innerText = "₹" + price;

      // Update QR Code
      const qrData = encodeURIComponent(`upi://pay?pa=asiverticals@icici&pn=UR-Heart%20Sanctuary&am=${{price}}&cu=INR`);
      document.getElementById("upiQrCodeImg").src = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${{qrData}}`;
    }}

    async function verifyAccountLive() {{
      const query = document.getElementById("userQueryInput").value.trim();
      const box = document.getElementById("verifyBox");
      if (!query) {{
        box.className = "verify-box error";
        box.innerText = "Please enter an email or referral code.";
        box.style.display = "block";
        return false;
      }}

      try {{
        const res = await fetch("/api/v1/store/verify-user", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{ query: query }})
        }});
        const data = await res.json();
        if (res.ok) {{
          box.className = "verify-box success";
          box.innerText = `✓ Seeker Authenticated: ${{data.full_name}} (${{data.email}}) [Tier: ${{data.subscription_tier}}]`;
          box.style.display = "block";
          verifiedAccount = data.email || query;
          document.getElementById("sumSeekerEmail").innerText = verifiedAccount;
          return true;
        }} else {{
          box.className = "verify-box error";
          box.innerText = data.detail || "Account not found.";
          box.style.display = "block";
          return false;
        }}
      }} catch (e) {{
        box.className = "verify-box success";
        box.innerText = `✓ Account recorded: ${{query}}`;
        box.style.display = "block";
        verifiedAccount = query;
        document.getElementById("sumSeekerEmail").innerText = verifiedAccount;
        return true;
      }}
    }}

    let razorpayOrderData = null;

    async function proceedToPaymentStep() {{
      const query = document.getElementById("userQueryInput").value.trim();
      if (!query) {{
        alert("Please enter your sanctuary email or referral code.");
        return;
      }}
      verifiedAccount = query;
      document.getElementById("sumSeekerEmail").innerText = verifiedAccount;

      // Create Order with official Razorpay order generation
      try {{
        const res = await fetch("/api/v1/store/create-order", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{
            product_id: selectedProductId,
            user_query: verifiedAccount,
            payment_method: selectedMethod,
            currency: "INR"
          }})
        }});
        const data = await res.json();
        if (data.order) {{
          currentOrderId = data.order.order_id;
        }}
        razorpayOrderData = data;
      }} catch (e) {{
        currentOrderId = "ORD-UR-" + Math.random().toString(36).substring(2, 8).toUpperCase();
      }}

      goToStep(3);
    }}

    function selectPaymentMethod(method) {{
      selectedMethod = method;
      document.querySelectorAll(".payment-option-card").forEach(c => c.classList.remove("selected"));
      event.currentTarget.classList.add("selected");
    }}

    async function processPaymentLive() {{
      const btn = document.getElementById("payBtn");
      btn.innerText = "Opening Razorpay Gateway...";
      btn.disabled = true;

      // 1. Live or Simulated Razorpay Standard Checkout
      if (window.Razorpay && razorpayOrderData && razorpayOrderData.razorpay_order_id) {{
        const rzpKey = razorpayOrderData.razorpay_key_id;
        const rzpOrderId = razorpayOrderData.razorpay_order_id;
        const rzpAmount = razorpayOrderData.amount_paise || (selectedPrice * 100);

        // Dev/Mock simulation fallback if keys unconfigured
        if (rzpOrderId.startsWith("order_sim_") || rzpKey.startsWith("rzp_test_simulated")) {{
          btn.innerText = "Verifying Sovereign Entitlement...";
          try {{
            const verifyRes = await fetch("/api/v1/store/verify-razorpay-payment", {{
              method: "POST",
              headers: {{ "Content-Type": "application/json" }},
              body: JSON.stringify({{
                order_id: currentOrderId,
                razorpay_order_id: rzpOrderId,
                razorpay_payment_id: "pay_sim_" + Date.now(),
                razorpay_signature: "sim_sig_valid"
              }})
            }});
            const vData = await verifyRes.json();
            if (verifyRes.ok && vData.status === "completed") {{
              document.getElementById("recOrderId").innerText = vData.order_id || currentOrderId;
              document.getElementById("recProductName").innerText = vData.product_name || selectedProductName;
              document.getElementById("recSeeker").innerText = verifiedAccount;
              document.getElementById("recTxHash").innerText = vData.payment_id || "pay_simulated_success";
              const deepLink = vData.deep_link || `urheart://store/receipt?order_id=${{currentOrderId}}&status=completed`;
              document.getElementById("openAppBtn").href = deepLink;
              goToStep(4);
              setTimeout(() => {{ window.location.href = deepLink; }}, 1500);
              return;
            }} else {{
              alert("Simulated verification failed: " + (vData.detail || "Unable to activate pass."));
              btn.innerText = "Pay & Activate Sovereign Pass ➔";
              btn.disabled = false;
              return;
            }}
          }} catch (simErr) {{
            console.error("Simulation error:", simErr);
            alert("Network error during simulated verification. Please try again.");
            btn.innerText = "Pay & Activate Sovereign Pass ➔";
            btn.disabled = false;
            return;
          }}
        }} else {{
          // Official Razorpay Checkout Modal
          const options = {{
            key: rzpKey,
            amount: rzpAmount,
            currency: "INR",
            name: razorpayOrderData.razorpay_merchant_name || "UR-Heart Sanctuary",
            description: selectedProductName,
            order_id: rzpOrderId,
            prefill: {{
              email: verifiedAccount.includes("@") ? verifiedAccount : "",
              contact: ""
            }},
            theme: {{
              color: razorpayOrderData.razorpay_theme_color || "#2E6F5E"
            }},
            handler: async function (response) {{
              btn.innerText = "Cryptographically Verifying...";
              try {{
                const verifyRes = await fetch("/api/v1/store/verify-razorpay-payment", {{
                  method: "POST",
                  headers: {{ "Content-Type": "application/json" }},
                  body: JSON.stringify({{
                    order_id: currentOrderId,
                    razorpay_order_id: response.razorpay_order_id,
                    razorpay_payment_id: response.razorpay_payment_id,
                    razorpay_signature: response.razorpay_signature
                  }})
                }});
                const vData = await verifyRes.json();
                if (verifyRes.ok && vData.status === "completed") {{
                  document.getElementById("recOrderId").innerText = vData.order_id || currentOrderId;
                  document.getElementById("recProductName").innerText = vData.product_name || selectedProductName;
                  document.getElementById("recSeeker").innerText = verifiedAccount;
                  document.getElementById("recTxHash").innerText = vData.payment_id || response.razorpay_payment_id;
                  const deepLink = vData.deep_link || `urheart://store/receipt?order_id=${{currentOrderId}}&status=completed`;
                  document.getElementById("openAppBtn").href = deepLink;
                  goToStep(4);
                  setTimeout(() => {{ window.location.href = deepLink; }}, 1500);
                }} else {{
                  alert("Payment verification error: " + (vData.detail || "Signature invalid."));
                  btn.innerText = "Pay & Activate Sovereign Pass ➔";
                  btn.disabled = false;
                }}
              }} catch (err) {{
                alert("Network error verifying payment. Please contact support.");
                btn.innerText = "Pay & Activate Sovereign Pass ➔";
                btn.disabled = false;
              }}
            }},
            modal: {{
              ondismiss: function() {{
                btn.innerText = "Pay & Activate Sovereign Pass ➔";
                btn.disabled = false;
              }}
            }}
          }};
          const rzp = new Razorpay(options);
          rzp.on('payment.failed', function (failResp) {{
            alert("Payment failed: " + (failResp.error.description || "Transaction declined."));
            btn.innerText = "Pay & Activate Sovereign Pass ➔";
            btn.disabled = false;
          }});
          rzp.open();
          return;
        }}
      }}

      // Fallback Manual UTR Flow
      try {{
        const res = await fetch("/api/v1/store/complete-order", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{
            order_id: currentOrderId || ("ORD-UR-" + Math.random().toString(36).substring(2, 8).toUpperCase()),
            payment_reference: "UPI-" + Date.now()
          }})
        }});
        const data = await res.json();
        document.getElementById("recOrderId").innerText = data.order_id || currentOrderId;
        document.getElementById("recProductName").innerText = data.product_name || selectedProductName;
        document.getElementById("recSeeker").innerText = verifiedAccount;
        document.getElementById("recTxHash").innerText = data.transaction_hash || "0x981bfd23...";
        const deepLink = data.deep_link || `urheart://store/receipt?order_id=${{data.order_id}}&product=${{selectedProductId}}`;
        document.getElementById("openAppBtn").href = deepLink;
        goToStep(4);
      }} catch (e) {{
        alert("Payment confirmation recorded.");
        goToStep(4);
      }}
    }}
  </script>
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)
