import uuid
from datetime import datetime, date
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User


@pytest.fixture
def mock_user():
    return User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Tester Seeker",
        dob=date(2000, 1, 1),
        gender="man",
        interested_in="all",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="919999988888",
        location_name="Connaught Place, New Delhi",
        referral_code="SANCTUARY-P99999",
        kyc_status=True,
        subscription_tier="free",
        reward_balance=50,
        swipes_remaining=25,
        direct_letters_count=1,
        reveal_tokens_count=0,
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
async def test_web_store_catalogue_specifications():
    """
    Test Problem 2 requirements:
    1. Lifetime pass duration is strictly 365 days (1-Year Sovereign Pass)
    2. Global passport duration is 1 day (24h) and price is ₹99 ($1.99)
    3. Instant contact key requires mutual consent and grants token
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/store/catalogue")
        assert resp.status_code == 200
        data = resp.json()
        assert data["currency"] == "INR"

        products = {p["id"]: p for p in data["products"]}

        # 1. Lifetime pass
        lifetime = products["urheart_pass_lifetime"]
        assert lifetime["duration_days"] == 365
        assert "365 Days" in lifetime["name"] or "1-Year" in lifetime["name"]

        # 2. Global passport
        passport = products["urheart_pack_global_passport"]
        assert passport["duration_days"] == 1
        assert passport["price_inr"] == 99
        assert "24h" in passport["name"]

        # 3. Instant contact key
        contact_key = products["urheart_key_instant_contact"]
        assert any("mutual consent" in str(feat).lower() for feat in contact_key["features"])


@pytest.mark.asyncio
async def test_billing_verification_lifetime_pass_365_days(mock_user, mock_db):
    """
    Verify that purchasing urheart_pass_lifetime sets duration to 365 days.
    """
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/billing/verify-purchase",
            json={
                "store": "google_play",
                "product_id": "urheart_pass_lifetime",
                "purchase_token": "google_play_valid_token_string_exceeding_twenty_chars",
                "transaction_id": "GPA.9999-1111-2222-33333",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["subscription_tier"] == "lifetime"
        # Check expires_at roughly 365 days ahead
        expires_at = datetime.fromisoformat(data["expires_at"].replace("Z", "+00:00"))
        delta = (expires_at - datetime.now(expires_at.tzinfo)).days
        assert 364 <= delta <= 366

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_billing_verification_instant_contact_key_credits_token(mock_user, mock_db):
    """
    Verify that purchasing urheart_key_instant_contact credits reveal_tokens_count instead of unilateral unlock.
    """
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/billing/verify-purchase",
            json={
                "store": "google_play",
                "product_id": "urheart_key_instant_contact",
                "purchase_token": "google_play_valid_token_string_exceeding_twenty_chars",
                "transaction_id": "GPA.8888-2222-3333-44444",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "verified"
        assert "Instant Contact Reveal Token credited" in data["message"]
        assert mock_user.reveal_tokens_count == 1

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_night_slumber_preference_update_and_persistence(mock_user, mock_db):
    """
    Test Problem 3: Night slumber preference can be toggled and read back via /api/v1/user/preferences.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Update night_slumber to True
        resp = await client.put(
            "/api/v1/user/preferences",
            json={"night_slumber": True},
        )
        assert resp.status_code == 200
        assert mock_user.night_slumber is True
        data = resp.json()
        assert data["night_slumber"] is True

        # 2. Get preferences
        get_resp = await client.get("/api/v1/user/preferences")
        assert get_resp.status_code == 200
        get_data = get_resp.json()
        assert get_data["preferences"]["night_slumber"] is True

    app.dependency_overrides.clear()
