import uuid
import pytest
from datetime import date, datetime, timezone
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.in_app_purchase import InAppPurchase
from app.api.v1.endpoints import web_store, ads_ssv

client = TestClient(app)

def create_mock_user(user_id=None, email="seeker@urheart.in", role="user", tier="free"):
    uid = user_id or uuid.uuid4()
    return User(
        id=uid,
        auth_id=uuid.uuid4(),
        email=email,
        full_name="Mindful Seeker",
        role=role,
        subscription_tier=tier,
        dob=date(2000, 1, 1),
        gender="Man",
        interested_in="Woman",
        contact_bridge_encrypted="enc_bridge",
        referral_code="REF" + uid.hex[:8].upper()
    )

def create_superadmin_user(user_id=None, email="asiverticals@gmail.com"):
    uid = user_id or uuid.uuid4()
    return User(
        id=uid,
        auth_id=uuid.uuid4(),
        email=email,
        full_name="Anubhav Singh",
        role="superadmin",
        subscription_tier="sovereign",
        dob=date(1995, 1, 1),
        gender="Man",
        interested_in="Woman",
        contact_bridge_encrypted="enc_bridge",
        referral_code="ADM" + uid.hex[:8].upper()
    )


# ==============================================================================
# 1. TEST SEC-CRIT-03: Dummy Token Billing Self-Assertion Neutralization
# ==============================================================================
def test_dummy_token_billing_rejection():
    """
    CRITERIA 1 (SEC-CRIT-03):
    Sending an arbitrary 20+ character numeric dummy string ('12345678901234567890')
    must be rejected with HTTP 403 Forbidden, and user subscription_tier must not change.
    """
    user = create_mock_user()
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None  # No replay in DB
    mock_res.scalars.return_value.all.return_value = []
    mock_db.execute.return_value = mock_res

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        payload = {
            "store": "google_play",
            "product_id": "com.urheart.pass.lifetime",
            "purchase_token": "12345678901234567890",
            "transaction_id": "GPA.1234-5678-9012-34567"
        }

        response = client.post(
            "/api/v1/billing/verify-purchase",
            headers={"Authorization": "Bearer mock_token"},
            json=payload
        )

        assert response.status_code == 403, f"Expected 403 Forbidden, got {response.status_code}: {response.text}"
        detail = response.json()["detail"].lower()
        assert "cryptographic" in detail or "store receipt" in detail or "invalid" in detail
        # Ensure tier was not escalated
        assert user.subscription_tier == "free"
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


# ==============================================================================
# 2. TEST SEC-CRIT-05: Fake UPI Order Bypass & Founder PNB Shield
# ==============================================================================
def test_fake_upi_order_pending_and_founder_approval():
    """
    CRITERIA 2 (SEC-CRIT-05):
    - Client completing UPI order must result in 'pending_verification'.
    - Sovereign perks must NOT be activated prematurely.
    - Duplicate UTR must be rejected with 409 Conflict.
    - Only founder superadmin can approve and unlock sovereign pass.
    """
    user = create_mock_user()
    admin = create_superadmin_user()
    web_store.SUBMITTED_UTRS.clear()

    mock_db = AsyncMock()
    def mock_db_execute(stmt):
        res = MagicMock()
        stmt_str = str(stmt).lower()
        if "users" in stmt_str:
            res.scalar_one_or_none.return_value = user
        else:
            res.scalar_one_or_none.return_value = None
        return res

    mock_db.execute = AsyncMock(side_effect=mock_db_execute)

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # 1. Create order
        create_res = client.post(
            "/api/v1/store/create-order",
            json={
                "product_id": "urheart_pass_lifetime",
                "user_query": str(user.id),
                "payment_method": "upi",
                "currency": "INR"
            }
        )
        assert create_res.status_code == 200, f"Create order failed: {create_res.text}"
        order_dict = create_res.json()["order"]
        order_id = order_dict["order_id"]
        assert order_dict["status"] == "pending_verification"

        # 2. Complete order with 12-digit UTR
        utr = "987654321098"
        comp_res = client.post(
            "/api/v1/store/complete-order",
            json={"order_id": order_id, "payment_reference": utr}
        )
        assert comp_res.status_code == 200, f"Complete order failed: {comp_res.text}"
        comp_data = comp_res.json()
        # Status MUST be pending_verification, NOT completed
        assert comp_data["status"] == "pending_verification"
        assert comp_data["order_id"] == order_id
        assert user.subscription_tier == "free"  # No sovereign entitlement unlocked yet

        # 3. Duplicate UTR Replay Prevention
        # Attempt to submit another order with the EXACT same UTR
        dup_create = client.post(
            "/api/v1/store/create-order",
            json={
                "product_id": "urheart_pass_lifetime",
                "user_query": str(user.id),
                "payment_method": "upi",
                "currency": "INR"
            }
        )
        dup_order_id = dup_create.json()["order"]["order_id"]
        dup_comp = client.post(
            "/api/v1/store/complete-order",
            json={"order_id": dup_order_id, "payment_reference": utr}
        )
        assert dup_comp.status_code == 409
        assert "already been" in dup_comp.json()["detail"].lower()

        # 4. Non-superadmin cannot approve order
        non_admin_approve = client.post(
            f"/api/v1/store/orders/{order_id}/approve",
            headers={"Authorization": "Bearer mock_token"}
        )
        assert non_admin_approve.status_code == 403

        # 5. Superadmin Founder Approval Unlocks Sovereign Perks
        app.dependency_overrides[get_current_user] = lambda: admin

        approve_res = client.post(
            f"/api/v1/store/orders/{order_id}/approve",
            headers={"Authorization": "Bearer admin_token"}
        )
        assert approve_res.status_code == 200, f"Approve failed: {approve_res.text}"
        approve_data = approve_res.json()
        assert approve_data["status"] == "completed"
        assert approve_data["order_id"] == order_id
        assert approve_data["subscription_tier"] == "lifetime"
        assert "approved by founder" in approve_data["message"].lower()
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


# ==============================================================================
# 3. TEST SEC-HIGH-04: Unsigned Ad Reward Spoof Test
# ==============================================================================
def test_unsigned_ad_reward_spoof_rejection():
    """
    CRITERIA 3 (SEC-HIGH-04):
    Forged AdMob SSV callback or missing/invalid ECDSA/HMAC signature must be rejected
    with HTTP 403 Forbidden, and swipe quotas must not be incremented.
    """
    user = create_mock_user()
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None  # No existing tx
    mock_db.execute.return_value = mock_res

    app.dependency_overrides[get_db] = lambda: mock_db

    # Part A: AdMob ECDSA forged signature rejection
    with patch("app.api.v1.endpoints.ads_ssv.get_admob_public_keys", new=AsyncMock(return_value={"keys": []})):
        forged_admob_query = {
            "network": "admob",
            "ad_unit": "ca-app-pub-3940256099942544/5224354917",
            "reward_amount": "5",
            "reward_item": "swipes",
            "timestamp": "1720000000",
            "transaction_id": "tx_spoofed_attack_999",
            "custom_data": f"{user.id}:quick_reflection:none",
            "signature": "MEQCIAfakeInvalidECDSASignatureForAdMobBypass1234567890=",
            "key_id": "1234567"
        }

        response_admob = client.get("/api/v1/ads/verify-reward", params=forged_admob_query)
        assert response_admob.status_code == 403, f"Expected 403 Forbidden, got {response_admob.status_code}: {response_admob.text}"
        detail = response_admob.json()["detail"].lower()
        assert "ecdsa" in detail or "verification failed" in detail

    # Part B: Non-Google network forged HMAC signature rejection
    forged_unity_query = {
        "network": "unity",
        "ad_unit": "rewardedVideo",
        "reward_amount": "5",
        "reward_item": "swipes",
        "timestamp": "1720000000",
        "transaction_id": "tx_unity_attack_888",
        "custom_data": f"{user.id}:quick_reflection:none",
        "signature": "invalidhmacsignature999999999999999999999999999999999999"
    }

    response_unity = client.get("/api/v1/ads/verify-reward", params=forged_unity_query)
    assert response_unity.status_code == 403, f"Expected 403 Forbidden, got {response_unity.status_code}: {response_unity.text}"
    detail_unity = response_unity.json()["detail"].lower()
    assert "hmac" in detail_unity or "invalid" in detail_unity

    app.dependency_overrides.pop(get_db, None)


# ==============================================================================
# 4. TEST SEC-MED-02: Stateless Database Persistence across Restarts
# ==============================================================================
def test_stateless_persistence_across_restarts():
    """
    CRITERIA 4 (SEC-MED-02):
    When an order is created, simulating a container restart (clearing in-memory dictionary)
    must not cause data loss. The pending order must be seamlessly retrieved from the DB ledger.
    """
    user = create_mock_user()
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = user
    mock_db.execute.return_value = mock_res

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # 1. Create order
        create_res = client.post(
            "/api/v1/store/create-order",
            json={
                "product_id": "urheart_pass_lifetime",
                "user_query": str(user.id),
                "payment_method": "upi",
                "currency": "INR"
            }
        )
        assert create_res.status_code == 200
        order_id = create_res.json()["order"]["order_id"]

        # 2. Simulate container reboot / spin-down by wiping in-memory dictionary
        web_store.WEB_STORE_ORDERS.clear()
        assert order_id not in web_store.WEB_STORE_ORDERS

        # 3. Setup mock DB ledger return for fallback query
        mock_iap_record = InAppPurchase(
            id=101,
            user_id=user.id,
            store="web_store",
            transaction_reference=order_id,
            product_identifier="urheart_pass_lifetime",
            status="pending_verification",
            amount_gross=799.0,
            platform_fee=0.0,
            amount_net=799.0,
            purchased_at=datetime.now(timezone.utc)
        )
        ledger_res = MagicMock()
        ledger_res.scalar_one_or_none.return_value = mock_iap_record
        mock_db.execute.return_value = ledger_res

        # 4. Query order status via GET endpoint
        get_res = client.get(
            f"/api/v1/store/orders/{order_id}",
            headers={"Authorization": "Bearer mock_token"}
        )
        assert get_res.status_code == 200, f"Get order failed: {get_res.text}"
        res_data = get_res.json()
        assert res_data["order"]["order_id"] == order_id
        assert res_data["order"]["status"] == "pending_verification"
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)
