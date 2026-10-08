import hashlib
import hmac
import json
import uuid
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import get_current_user
from app.main import app
from app.models.domain.user import User
from app.models.domain.in_app_purchases import InAppPurchase
from app.services.razorpay_service import RazorpayService

client = TestClient(app)
settings = get_settings()


def create_mock_seeker(user_id=None, email="seeker.razorpay@urheart.in", tier="free"):
    uid = user_id or uuid.uuid4()
    return User(
        id=uid,
        auth_id=uuid.uuid4(),
        email=email,
        full_name="Razorpay Seeker",
        role="user",
        subscription_tier=tier,
        swipes_remaining=10,
        direct_letters_count=0,
        reveal_tokens_count=0,
        dob=date(1998, 5, 20),
        gender="Man",
        interested_in="Woman",
        contact_bridge_encrypted="enc_bridge_rzp",
        referral_code="RZP" + uid.hex[:8].upper()
    )


# ==============================================================================
# 1. UNIT TESTS: RazorpayService Cryptographic Engine
# ==============================================================================

@pytest.mark.asyncio
async def test_razorpay_service_mock_order_creation_when_keys_empty():
    """When API keys are not provided, service gracefully generates simulated order."""
    with patch.object(settings, "RAZORPAY_KEY_ID", ""), patch.object(settings, "RAZORPAY_KEY_SECRET", ""):
        order = await RazorpayService.create_order(
            amount_inr=149.0,
            receipt="RCPT-001",
            notes={"purpose": "1-Month Pass"}
        )
        assert order["amount"] == 14900
        assert order["currency"] == "INR"
        assert order["status"] == "created"
        assert order["id"].startswith("order_sim_")
        assert order["is_simulated"] is True


@pytest.mark.asyncio
async def test_razorpay_service_live_order_creation_http_mock():
    """When API keys are present, service sends authenticated POST request to Razorpay REST API."""
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "id": "order_live_999ABC",
        "entity": "order",
        "amount": 14900,
        "currency": "INR",
        "status": "created"
    }

    with patch.object(settings, "RAZORPAY_KEY_ID", "rzp_live_testkey123"), \
         patch.object(settings, "RAZORPAY_KEY_SECRET", "rzp_sec_testsecret456"), \
         patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_response) as mock_post:

        order = await RazorpayService.create_order(
            amount_inr=149.0,
            receipt="RCPT-LIVE-001",
            notes={"product_id": "urheart_pass_monthly"}
        )

        assert order["id"] == "order_live_999ABC"
        assert order["amount"] == 14900
        assert mock_post.called
        call_kwargs = mock_post.call_args.kwargs
        assert call_kwargs["auth"] == ("rzp_live_testkey123", "rzp_sec_testsecret456")
        assert call_kwargs["json"]["amount"] == 14900
        assert call_kwargs["json"]["currency"] == "INR"


def test_razorpay_signature_verification_valid_and_tampered():
    """Tests exact HMAC-SHA256 signature verification matching Razorpay documentation."""
    test_secret = "sanctuary_sacred_secret_2026"
    order_id = "order_O123456789"
    payment_id = "pay_P987654321"

    # Compute valid signature
    msg = f"{order_id}|{payment_id}".encode("utf-8")
    valid_sig = hmac.new(test_secret.encode("utf-8"), msg, hashlib.sha256).hexdigest()

    with patch.object(settings, "RAZORPAY_KEY_SECRET", test_secret):
        # 1. Valid signature passes
        assert RazorpayService.verify_payment_signature(order_id, payment_id, valid_sig) is True

        # 2. Tampered signature fails
        assert RazorpayService.verify_payment_signature(order_id, payment_id, "forged_signature_000") is False

        # 3. Tampered payment ID fails
        assert RazorpayService.verify_payment_signature(order_id, "pay_TAMPERED", valid_sig) is False


def test_razorpay_webhook_signature_verification():
    """Tests webhook body HMAC-SHA256 signature verification."""
    test_secret = "webhook_secret_key_777"
    raw_payload = b'{"event":"payment.captured","payload":{}}'
    valid_sig = hmac.new(test_secret.encode("utf-8"), raw_payload, hashlib.sha256).hexdigest()

    with patch.object(settings, "RAZORPAY_WEBHOOK_SECRET", test_secret):
        assert RazorpayService.verify_webhook_signature(raw_payload, valid_sig) is True
        assert RazorpayService.verify_webhook_signature(raw_payload, "invalid_sig") is False
        assert RazorpayService.verify_webhook_signature(b"altered_payload", valid_sig) is False


# ==============================================================================
# 2. INTEGRATION TESTS: Store Order Creation & Instant Verification Endpoints
# ==============================================================================

def test_store_create_order_returns_razorpay_details():
    """Store create-order returns proper Razorpay client configuration and order ID for frontend modal."""
    seeker = create_mock_seeker()
    mock_db = AsyncMock()
    mock_db.execute.return_value = MagicMock(scalar_one_or_none=lambda: seeker)

    app.dependency_overrides[get_current_user] = lambda: seeker
    app.dependency_overrides[get_db] = lambda: mock_db

    mock_rzp_order = {
        "id": "order_RZP_integration_123",
        "entity": "order",
        "amount": 14900,
        "currency": "INR",
        "status": "created",
        "receipt": "RCPT-001",
        "notes": {}
    }

    try:
        with patch.object(settings, "RAZORPAY_KEY_ID", "rzp_test_mock123"), \
             patch.object(settings, "RAZORPAY_KEY_SECRET", "rzp_sec_mock456"), \
             patch("app.services.razorpay_service.RazorpayService.create_order", new_callable=AsyncMock, return_value=mock_rzp_order):
            response = client.post(
                "/api/v1/store/create-order",
                json={
                    "product_id": "urheart_pass_monthly",
                    "user_query": seeker.email,
                    "payment_method": "upi",
                    "currency": "INR"
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "order_created"
            assert "order" in data
            assert data["order"]["status"] == "pending_verification"
            assert data["razorpay_order_id"] == "order_RZP_integration_123"
            assert data["razorpay_key_id"] == "rzp_test_mock123"
            assert data["amount_paise"] == 14900
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_verify_razorpay_payment_instant_activation():
    """Instant cryptographic verification of Razorpay payment unlocks passes immediately."""
    from app.api.v1.endpoints import web_store
    seeker = create_mock_seeker()
    test_secret = "secret_for_instant_verify_test"

    order_id = "ORD-UR-TEST01"
    razorpay_order_id = "order_RZP_001"
    razorpay_payment_id = "pay_RZP_001"

    # Bind the order in registry so order binding validation succeeds
    web_store.STORE_ORDER_RAZORPAY_MAP[order_id] = razorpay_order_id
    web_store.WEB_STORE_ORDERS[order_id] = {
        "order_id": order_id,
        "product_id": "urheart_pass_monthly",
        "razorpay_order_id": razorpay_order_id,
        "user_query": seeker.email
    }

    msg = f"{razorpay_order_id}|{razorpay_payment_id}".encode("utf-8")
    valid_sig = hmac.new(test_secret.encode("utf-8"), msg, hashlib.sha256).hexdigest()

    mock_db = AsyncMock()
    mock_purchase = InAppPurchase(
        user_id=seeker.id,
        transaction_reference=order_id,
        product_identifier="urheart_pass_monthly",
        store="web_razorpay_india",
        currency="INR",
        amount_gross=149.0,
        platform_fee=0.0,
        amount_net=149.0,
        status="pending"
    )

    def mock_execute(stmt):
        stmt_str = str(stmt).lower()
        res = MagicMock()
        if "in_app_purchases" in stmt_str:
            res.scalar_one_or_none.return_value = mock_purchase
        elif "users" in stmt_str:
            res.scalar_one_or_none.return_value = seeker
        else:
            res.scalar_one_or_none.return_value = None
        return res

    mock_db.execute = AsyncMock(side_effect=mock_execute)
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch.object(settings, "RAZORPAY_KEY_SECRET", test_secret):
            response = client.post(
                "/api/v1/store/verify-razorpay-payment",
                json={
                    "order_id": order_id,
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_signature": valid_sig
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "completed"
            assert data["product_id"] == "urheart_pass_monthly"
            assert data["subscription_tier"] == "monthly"
            assert "deep_link" in data
            assert f"order_id={order_id}" in data["deep_link"]
            assert f"payment_id={razorpay_payment_id}" in data["deep_link"]

            # Assert DB record updated to completed with unified ledger key
            assert mock_purchase.status == "completed"
            assert mock_purchase.transaction_reference == order_id
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_verify_razorpay_payment_forged_signature_rejection():
    """Fraudulent/tampered Razorpay payment signature is rejected with 400 Bad Request."""
    test_secret = "secret_for_forgery_test"
    mock_db = AsyncMock()
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch.object(settings, "RAZORPAY_KEY_SECRET", test_secret):
            response = client.post(
                "/api/v1/store/verify-razorpay-payment",
                json={
                    "order_id": "ORD-UR-FAKE",
                    "razorpay_order_id": "order_FAKE_001",
                    "razorpay_payment_id": "pay_FAKE_001",
                    "razorpay_signature": "forged_malicious_signature_999"
                }
            )

            assert response.status_code == 400
            assert "Cryptographic verification failed" in response.json()["detail"]
    finally:
        app.dependency_overrides.pop(get_db, None)


# ==============================================================================
# 3. WEBHOOK TESTS: Full Event Processing & Idempotency
# ==============================================================================

def test_razorpay_webhook_payment_captured_grant_entitlement():
    """Webhook payment.captured event processes pass and records ledger split."""
    seeker = create_mock_seeker()
    test_secret = "webhook_secret_prod_test"

    body = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": "pay_live_web_12345",
                    "amount": 14900,
                    "notes": {
                        "user_id": str(seeker.id),
                        "product_id": "urheart_pass_monthly"
                    }
                }
            }
        }
    }
    body_bytes = json.dumps(body).encode("utf-8")
    sig = hmac.new(test_secret.encode("utf-8"), body_bytes, hashlib.sha256).hexdigest()

    mock_db = AsyncMock()
    # No prior purchase in DB
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_res
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch.object(settings, "RAZORPAY_WEBHOOK_SECRET", test_secret):
            response = client.post(
                "/api/v1/billing/webhook/razorpay",
                headers={"x-razorpay-signature": sig, "content-type": "application/json"},
                content=body_bytes
            )

            assert response.status_code == 200
            assert response.json() == {"status": "success"}
            # Verify DB additions and commits occurred
            assert mock_db.add.called
            assert mock_db.commit.called
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_razorpay_webhook_idempotency_prevents_duplicate_grant():
    """Duplicate webhook delivery for already completed purchase returns already_processed without re-granting."""
    seeker = create_mock_seeker()
    test_secret = "webhook_idempotency_secret"
    payment_id = "pay_already_completed_999"

    body = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": payment_id,
                    "amount": 14900,
                    "notes": {
                        "user_id": str(seeker.id),
                        "product_id": "urheart_pass_monthly"
                    }
                }
            }
        }
    }
    body_bytes = json.dumps(body).encode("utf-8")
    sig = hmac.new(test_secret.encode("utf-8"), body_bytes, hashlib.sha256).hexdigest()

    # Existing completed purchase record
    existing_purchase = InAppPurchase(
        user_id=seeker.id,
        transaction_reference=payment_id,
        product_identifier="urheart_pass_monthly",
        store="web_razorpay_india",
        currency="INR",
        amount_gross=149.0,
        platform_fee=2.98,
        amount_net=146.02,
        status="completed"
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = existing_purchase
    mock_db.execute.return_value = mock_res
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch.object(settings, "RAZORPAY_WEBHOOK_SECRET", test_secret):
            response = client.post(
                "/api/v1/billing/webhook/razorpay",
                headers={"x-razorpay-signature": sig, "content-type": "application/json"},
                content=body_bytes
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "already_processed"
            assert data["payment_id"] == payment_id
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_verify_razorpay_payment_mismatched_order_id_rejected():
    """Security check: verifying payment with an arbitrary/mismatched razorpay_order_id must be rejected."""
    from app.api.v1.endpoints import web_store
    seeker = create_mock_seeker()
    test_secret = "mismatch_test_secret"

    order_id = "ORD-UR-BIND-001"
    legit_rzp_order_id = "order_LEGIT_111"
    attacker_rzp_order_id = "order_ATTACKER_999"
    attacker_payment_id = "pay_ATTACKER_999"

    # Register legit binding
    web_store.STORE_ORDER_RAZORPAY_MAP[order_id] = legit_rzp_order_id
    web_store.WEB_STORE_ORDERS[order_id] = {
        "order_id": order_id,
        "product_id": "urheart_pass_lifetime",
        "razorpay_order_id": legit_rzp_order_id,
        "user_query": seeker.email
    }

    # Generate valid signature for attacker order
    msg = f"{attacker_rzp_order_id}|{attacker_payment_id}".encode("utf-8")
    valid_sig = hmac.new(test_secret.encode("utf-8"), msg, hashlib.sha256).hexdigest()

    mock_db = AsyncMock()
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch.object(settings, "RAZORPAY_KEY_SECRET", test_secret):
            response = client.post(
                "/api/v1/store/verify-razorpay-payment",
                json={
                    "order_id": order_id,
                    "razorpay_order_id": attacker_rzp_order_id,
                    "razorpay_payment_id": attacker_payment_id,
                    "razorpay_signature": valid_sig
                }
            )

            # Must be rejected because attacker_rzp_order_id does not match legit_rzp_order_id
            assert response.status_code == 400
            assert "Mismatched Razorpay order ID" in response.json()["detail"]
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_simulated_signature_rejected_in_production():
    """Simulated signatures must be strictly rejected when ENVIRONMENT is production."""
    with patch.object(settings, "ENVIRONMENT", "production"), \
         patch.object(settings, "RAZORPAY_KEY_SECRET", ""):
        # Outside production this might be allowed if keys unset, but in production it MUST return False
        is_valid = RazorpayService.verify_payment_signature(
            razorpay_order_id="order_sim_12345",
            razorpay_payment_id="pay_sim_12345",
            razorpay_signature="sim_sig_valid"
        )
        assert is_valid is False


def test_production_fail_fast_missing_secrets():
    """Production validator must raise ValueError if Razorpay keys or non-default webhook secret are missing."""
    from app.core.config import Settings

    with pytest.raises(ValueError) as exc_info:
        Settings(
            ENVIRONMENT="production",
            JWT_SECRET_KEY="a" * 32,
            FIREBASE_PROJECT_ID="proj",
            SUPABASE_SERVICE_ROLE_KEY="role_key",
            REVENUECAT_WEBHOOK_SECRET="rc_sec",
            SUPERADMIN_SECRET_KEY="super_custom_key",
            RAZORPAY_KEY_ID="",  # Missing
            RAZORPAY_KEY_SECRET="sec",
            RAZORPAY_WEBHOOK_SECRET="rzp_webhook_secret_sanctuary_2026"  # Default
        )
    err = str(exc_info.value)
    assert "RAZORPAY_KEY_ID" in err
    assert "RAZORPAY_WEBHOOK_SECRET" in err

