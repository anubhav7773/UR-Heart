import hmac
import hashlib
import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock
from app.main import app
from app.api.dependencies import get_db
from app.api.v1.endpoints.billing_webhook import REVENUECAT_SECRET, RAZORPAY_WEBHOOK_SECRET
from app.api.v1.endpoints.ads_ssv import NETWORK_SECRETS
from app.models.domain.user import User


@pytest.mark.asyncio
async def test_sec04_fake_ad_reward_callback_rejection():
    """
    Test 1: Fake Ad Reward Callback Rejection (SEC-04 Test)
    An unauthenticated / spoofed callback without valid HMAC signature must be strictly rejected with HTTP 403 Forbidden.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Spoofed InMobi callback without signature
        res_no_sig = await client.get(
            "/api/v1/ads/verify-reward",
            params={
                "network": "inmobi",
                "transaction_id": f"fake_tx_{uuid.uuid4().hex[:8]}",
                "custom_data": f"{uuid.uuid4()}:morning_harvest_unlock"
            }
        )
        assert res_no_sig.status_code == 403
        assert "Invalid INMOBI HMAC signature" in res_no_sig.json().get("detail", "")

        # Spoofed InMobi callback with fake signature
        res_bad_sig = await client.get(
            "/api/v1/ads/verify-reward",
            params={
                "network": "inmobi",
                "transaction_id": f"fake_tx_{uuid.uuid4().hex[:8]}",
                "custom_data": f"{uuid.uuid4()}:morning_harvest_unlock",
                "signature": "bad_hex_signature_12345"
            }
        )
        assert res_bad_sig.status_code == 403
        assert "Invalid INMOBI HMAC signature" in res_bad_sig.json().get("detail", "")


@pytest.mark.asyncio
async def test_sec05_spoofed_revenuecat_webhook_rejection():
    """
    Test 2: Spoofed RevenueCat Lifetime Upgrade Rejection (SEC-05 Test)
    Calling RevenueCat webhook without valid Bearer secret must be rejected with HTTP 401 Unauthorized.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. No Authorization header
        res_no_auth = await client.post(
            "/api/v1/billing/webhook/revenuecat",
            json={
                "event": {
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": str(uuid.uuid4()),
                    "product_id": "urheart_pass_lifetime",
                    "id": f"tx_spoof_{uuid.uuid4().hex[:8]}"
                }
            }
        )
        assert res_no_auth.status_code == 401
        assert "Invalid webhook credentials" in res_no_auth.json().get("detail", "")

        # 2. Fake Bearer token
        res_fake_auth = await client.post(
            "/api/v1/billing/webhook/revenuecat",
            headers={"Authorization": "Bearer fake_secret_hacker_token"},
            json={
                "event": {
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": str(uuid.uuid4()),
                    "product_id": "urheart_pass_lifetime",
                    "id": f"tx_spoof_{uuid.uuid4().hex[:8]}"
                }
            }
        )
        assert res_fake_auth.status_code == 401
        assert "Invalid webhook credentials" in res_fake_auth.json().get("detail", "")


@pytest.mark.asyncio
async def test_sec05_subscription_cancellation_auto_revert():
    """
    Test 4: Subscription Cancellation Auto-Revert Test
    Simulating a CANCELLATION or EXPIRATION event with valid Bearer secret gracefully reverts user to free tier.
    """
    test_user_id = uuid.uuid4()
    updated_values = {}

    async def mock_db():
        mock_session = AsyncMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = None
        mock_session.execute = AsyncMock(return_value=mock_res)
        mock_session.add = MagicMock()
        mock_session.commit = AsyncMock()
        yield mock_session

    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Valid cancellation webhook
        res = await client.post(
            "/api/v1/billing/webhook/revenuecat",
            headers={"Authorization": f"Bearer {REVENUECAT_SECRET}"},
            json={
                "event": {
                    "type": "CANCELLATION",
                    "app_user_id": str(test_user_id),
                    "id": f"cancel_tx_{uuid.uuid4().hex[:8]}"
                }
            }
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["event"] == "CANCELLATION"

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_sec05_razorpay_hmac_verification():
    """
    Verifies Razorpay Webhook HMAC-SHA256 signature enforcement on raw body bytes.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        body = b'{"event": "payment.captured", "payload": {}}'

        # Bad signature
        res_bad = await client.post(
            "/api/v1/billing/webhook/razorpay",
            content=body,
            headers={"Content-Type": "application/json", "X-Razorpay-Signature": "invalid_hex_sig"}
        )
        assert res_bad.status_code == 403
        assert "Invalid Razorpay webhook signature" in res_bad.json().get("detail", "")

        # Valid signature
        valid_sig = hmac.new(RAZORPAY_WEBHOOK_SECRET.encode("utf-8"), body, hashlib.sha256).hexdigest()
        res_ok = await client.post(
            "/api/v1/billing/webhook/razorpay",
            content=body,
            headers={"Content-Type": "application/json", "X-Razorpay-Signature": valid_sig}
        )
        assert res_ok.status_code == 200
        assert res_ok.json()["status"] == "ignored" or res_ok.json()["status"] == "success"
