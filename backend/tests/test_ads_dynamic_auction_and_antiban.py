import uuid
from datetime import date
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User


@pytest.fixture
def mock_auction_user():
    return User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Auction Seeker",
        dob=date(1999, 12, 12),
        gender="man",
        interested_in="all",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="919876543210",
        location_name="Connaught Place, New Delhi",
        referral_code="SANCTUARY-AUCTION",
        kyc_status=True,
        subscription_tier="free",
        reward_balance=50,
        swipes_remaining=20,
        direct_letters_count=2,
        reveal_tokens_count=0,
        is_profile_completed=True,
        night_slumber=True,
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
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    return session


@pytest.mark.asyncio
async def test_morning_harvest_10s_ad_awards_swipes(mock_auction_user, mock_db):
    """
    Test provider auction 10s short ad:
    Ad provider serves 10s ad -> 10 Swipes awarded.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_auction_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/ads/claim-reward",
            json={
                "ad_type": "morning_harvest_unlock",
                "duration_seconds": 10,
                "network": "admob",
                "rest_hours": 0.0,
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        # 20 initial + 10 = 30
        assert mock_auction_user.swipes_remaining == 30
        assert "Swipes credited" in data["message"]

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_morning_harvest_20s_ad_awards_direct_letter(mock_auction_user, mock_db):
    """
    Test provider auction 20s medium ad:
    Ad provider serves 20s ad -> 1 Direct Letter (DM) awarded.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_auction_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/ads/claim-reward",
            json={
                "ad_type": "morning_harvest_unlock",
                "duration_seconds": 20,
                "network": "unity",
                "rest_hours": 0.0,
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        # 2 initial + 1 = 3
        assert mock_auction_user.direct_letters_count == 3
        assert "Direct Letter credited" in data["message"]

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_morning_harvest_30s_ad_advances_reveal_token(mock_auction_user, mock_db):
    """
    Test provider auction 30s premium ad:
    Ad provider serves 30s ad -> advances reveal token progression (1/3).
    """
    mock_result = MagicMock()
    mock_result.scalar.return_value = 1
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_current_user] = lambda: mock_auction_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/ads/claim-reward",
            json={
                "ad_type": "morning_harvest_unlock",
                "duration_seconds": 30,
                "network": "applovin",
                "rest_hours": 0.0,
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        assert data["whatsapp_progress"] == 1
        assert "towards Reveal Token" in data["message"]

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_morning_harvest_with_rest_multiplier(mock_auction_user, mock_db):
    """
    Test rest quality multiplier: 8+ hours of restful slumber earns 2.0x swipes multiplier.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_auction_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/ads/claim-reward",
            json={
                "ad_type": "morning_harvest_unlock",
                "duration_seconds": 10,
                "network": "meta",
                "rest_hours": 8.5,
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        # 10 * 2.0 = 20 swipes credited, so 20 initial + 20 = 40
        assert mock_auction_user.swipes_remaining == 40
        assert "+20 Swipes" in data["message"]

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_antiban_rapid_claim_throttling(mock_auction_user, mock_db):
    """
    Test Anti-Bot security:
    Calling claim endpoint with sub-second rapid repeated requests is rejected with HTTP 429.
    """
    app.dependency_overrides[get_current_user] = lambda: mock_auction_user
    app.dependency_overrides[get_db] = lambda: mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # First request succeeds
        resp1 = await client.post(
            "/api/v1/ads/claim-reward",
            json={"ad_type": "quick_reflection"},
        )
        assert resp1.status_code == 200

        # Immediate follow-up call (< 2s) triggers anti-bot throttling
        resp2 = await client.post(
            "/api/v1/ads/claim-reward",
            json={"ad_type": "quick_reflection"},
        )
        assert resp2.status_code == 429
        assert "Mindful pacing required" in resp2.json()["detail"]

    app.dependency_overrides.clear()
