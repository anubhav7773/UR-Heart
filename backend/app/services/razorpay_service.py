import hashlib
import hmac
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import httpx
from fastapi import HTTPException, status

from app.core.config import get_settings

settings = get_settings()


class RazorpayService:
    """
    Production-Grade Asynchronous Razorpay Service for India Corridor.
    Handles order creation, payment signature verification, and webhook authenticity.
    Supports SBI Insta Plus and all verified Indian bank account settlements via standard keys.
    """

    RAZORPAY_API_URL = "https://api.razorpay.com/v1"

    @classmethod
    def is_configured(cls) -> bool:
        """Checks if live or test Razorpay API credentials are provided in settings."""
        return bool(settings.RAZORPAY_KEY_ID and settings.RAZORPAY_KEY_SECRET)

    @classmethod
    def get_client_config(cls) -> Dict[str, str]:
        """Returns client-safe configuration for standard Razorpay checkout modal."""
        return {
            "key_id": settings.RAZORPAY_KEY_ID or "rzp_test_simulated",
            "merchant_name": settings.RAZORPAY_MERCHANT_NAME or "UR-Heart Sanctuary",
            "theme_color": settings.RAZORPAY_THEME_COLOR or "#2E6F5E",
            "is_live": bool(settings.RAZORPAY_KEY_ID.startswith("rzp_live_") if settings.RAZORPAY_KEY_ID else False)
        }

    @classmethod
    async def create_order(
        cls,
        amount: float = 0.0,
        currency: str = "INR",
        receipt: str = "",
        notes: Optional[Dict[str, Any]] = None,
        amount_inr: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Creates an official Razorpay order in INR, USD, or any supported ISO currency.
        Amounts are converted to integer subunits (paise for INR, cents for USD).
        Calls Razorpay REST API asynchronously with basic auth (key_id, key_secret).
        Falls back to resilient simulated order in development/mock environments.
        """
        resolved_amount = amount_inr if amount_inr is not None else amount
        currency_code = (currency or "INR").upper()
        amount_subunits = int(round(resolved_amount * 100))
        sanitized_notes = {str(k): str(v) for k, v in (notes or {}).items()}
        env = (settings.ENVIRONMENT or "").lower()

        if not cls.is_configured():
            # Development / CI / Mock fallback mode
            sim_order_id = f"order_sim_{uuid.uuid4().hex[:14]}"
            return {
                "id": sim_order_id,
                "entity": "order",
                "amount": amount_subunits,
                "amount_paid": 0,
                "amount_due": amount_subunits,
                "currency": currency_code,
                "receipt": receipt[:40],
                "status": "created",
                "attempts": 0,
                "notes": sanitized_notes,
                "created_at": int(datetime.now(timezone.utc).timestamp()),
                "is_simulated": True
            }

        auth = (settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
        payload = {
            "amount": amount_subunits,
            "currency": currency_code,
            "receipt": receipt[:40],
            "notes": sanitized_notes
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(
                    f"{cls.RAZORPAY_API_URL}/orders",
                    auth=auth,
                    json=payload,
                    headers={"Accept": "application/json"}
                )

                if res.status_code in (200, 201):
                    return res.json()

                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Razorpay order creation failed ({res.status_code}): {res.text}"
                )
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to communicate with Razorpay API: {exc}"
            )

    @classmethod
    def verify_payment_signature(
        cls,
        razorpay_order_id: str,
        razorpay_payment_id: str,
        razorpay_signature: str
    ) -> bool:
        """
        Cryptographically verifies standard Razorpay payment signature:
        HMAC-SHA256 of `${razorpay_order_id}|${razorpay_payment_id}` using RAZORPAY_KEY_SECRET.
        Guarantees that payment succeeded on Razorpay and was not spoofed by client.
        Simulated signatures are strictly permitted ONLY outside of production.
        """
        if not razorpay_order_id or not razorpay_payment_id or not razorpay_signature:
            return False

        secret = settings.RAZORPAY_KEY_SECRET
        env = (settings.ENVIRONMENT or "").lower()

        # Strictly reject simulated signatures in production
        if env in ("production", "prod"):
            if razorpay_signature in ("sim_sig_valid", "simulated_success_sig"):
                return False
            if not secret:
                return False
        else:
            # Allow simulated signatures only outside production (testing / local dev)
            if razorpay_order_id.startswith("order_sim_") and razorpay_signature in ("sim_sig_valid", "simulated_success_sig"):
                return True

        if not secret:
            return False

        message = f"{razorpay_order_id}|{razorpay_payment_id}".encode("utf-8")
        generated_signature = hmac.new(
            secret.encode("utf-8"),
            message,
            hashlib.sha256
        ).hexdigest()

        return hmac.compare_digest(generated_signature, razorpay_signature.strip())

    @classmethod
    def verify_webhook_signature(
        cls,
        body_bytes: bytes,
        signature_header: str
    ) -> bool:
        """
        Verifies Razorpay Webhook authenticity using RAZORPAY_WEBHOOK_SECRET.
        HMAC-SHA256 signature calculated over raw request payload bytes.
        """
        if not body_bytes or not signature_header:
            return False

        webhook_secret = settings.RAZORPAY_WEBHOOK_SECRET or ""
        if not webhook_secret:
            return False

        generated_signature = hmac.new(
            webhook_secret.encode("utf-8"),
            body_bytes,
            hashlib.sha256
        ).hexdigest()

        return hmac.compare_digest(generated_signature, signature_header.strip())
