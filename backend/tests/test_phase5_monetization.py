import uuid
from datetime import datetime, date
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.in_app_purchases import InAppPurchase


@pytest.fixture
def mock_monetization_user():
    return User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Monetization Seeker",
        dob=date(1998, 5, 20),
        gender="woman",
        interested_in="all",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="919876543210",
        location_name="Bandra, Mumbai",
        referral_code="SANCTUARY-A9F1B2",
        kyc_status=True,
        subscription_tier="free",
        reward_balance=50,
        swipes_remaining=25,
        direct_letters_count=1,
        is_profile_completed=True,
        night_slumber=False,
        is_incognito=False,
        discreet_mode=False,
        public_encryption_key=None,
        push_notifications_enabled=True,
        role="user",
    )


@pytest.fixture
def mock_db():
    session = AsyncMock()
    session.execute = AsyncMock()
    session.commit = AsyncMock()
    session.add = MagicMock()
    return session


@pytest.mark.asyncio
async def test_spoofed_client_receipt_rejection(mock_monetization_user, mock_db):
    """
    Test 2: Spoofed Client Receipt Rejection (DIS-01 Test)
    Bina store authority ke short / forged receipt token verify karne par 403 Forbidden.
    """
    # Mock no existing transaction
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_current_user] = lambda: mock_monetization_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/billing/verify-purchase",
            json={
                "store": "google_play",
                "product_id": "urheart_pass_lifetime",
                "purchase_token": "fake_token_123",  # < 20 chars
                "transaction_id": "tx_spoof_999",
            },
        )
        assert response.status_code == 403
        data = response.json()
        assert "Store receipt signature rejected" in data["detail"]

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_valid_store_receipt_verification_and_entitlement(mock_monetization_user, mock_db):
    """
    Valid Google Play purchase token grants tier, sets ad-free, and records ledger entry.
    """
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_current_user] = lambda: mock_monetization_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/billing/verify-purchase",
            json={
                "store": "google_play",
                "product_id": "urheart_pass_monthly",
                "purchase_token": "google_play_valid_token_string_exceeding_twenty_chars",
                "transaction_id": "GPA.3392-8192-1928-12345",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "verified"
        assert data["subscription_tier"] == "monthly"
        assert data["product_id"] == "urheart_pass_monthly"
        assert data["expires_at"] is not None

        # Verify db.add was called with InAppPurchase
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_idempotent_duplicate_transaction(mock_monetization_user, mock_db):
    """
    Duplicate transaction ID returns verified status without re-executing ledger insert.
    """
    mock_existing_tx = MagicMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_existing_tx
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_current_user] = lambda: mock_monetization_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/billing/verify-purchase",
            json={
                "store": "google_play",
                "product_id": "urheart_pass_monthly",
                "purchase_token": "google_play_valid_token_string_exceeding_twenty_chars",
                "transaction_id": "GPA.3392-8192-1928-12345",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "verified"
        assert "already recorded" in data["message"]

    app.dependency_overrides.clear()
