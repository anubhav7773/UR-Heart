import uuid
import base64
import pytest
from datetime import datetime, date
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User


@pytest.fixture
def mock_phase1_user():
    return User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Phase 1 Seeker",
        dob=date(2000, 1, 1),
        gender="non_binary",
        interested_in="all",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="919876543210",
        location_name="Bandra, Mumbai",
        referral_code="PHASE1_REF",
        kyc_status=True,
        subscription_tier="free",
        reward_balance=100,
        swipes_remaining=25,
        is_profile_completed=False,
        night_slumber=False,
        is_incognito=False,
        discreet_mode=False,
        public_encryption_key=None,
        push_notifications_enabled=True,
        role="user",
    )


@pytest.fixture
def mock_db_session():
    session = AsyncMock()
    session.execute = AsyncMock()
    session.commit = AsyncMock()
    session.refresh = AsyncMock()
    return session


@pytest.mark.asyncio
async def test_dis03_profile_update_and_get(mock_phase1_user, mock_db_session):
    """
    Test 1: Profile Update Persistence (DIS-03 & DUM-17 Fix)
    Tests PUT /api/v1/profile/me and GET /api/v1/profile/me
    """
    app.dependency_overrides[get_current_user] = lambda: mock_phase1_user
    app.dependency_overrides[get_db] = lambda: mock_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. GET /api/v1/profile/me
        get_res = await client.get("/api/v1/profile/me")
        assert get_res.status_code == 200
        get_data = get_res.json()
        assert get_data["full_name"] == "Phase 1 Seeker"
        assert get_data["is_profile_completed"] is False
        assert "contact_bridge_masked" in get_data

        # 2. PUT /api/v1/profile/me
        update_payload = {
            "bio": "Quiet mornings and slow conversations.",
            "profession": "Architect",
            "education": "CEPT University",
            "location_name": "Bandra West, Mumbai",
            "preferred_age_min": 21,
            "preferred_age_max": 30
        }
        put_res = await client.put("/api/v1/profile/me", json=update_payload)
        assert put_res.status_code == 200
        put_data = put_res.json()
        assert put_data["status"] == "success"
        assert mock_db_session.execute.called
        assert mock_db_session.commit.called

        # 3. Invalid age range returns 422
        bad_age_payload = {
            "preferred_age_min": 35,
            "preferred_age_max": 20
        }
        bad_res = await client.put("/api/v1/profile/me", json=bad_age_payload)
        assert bad_res.status_code == 422


@pytest.mark.asyncio
async def test_dis04_preferences_update(mock_phase1_user, mock_db_session):
    """
    Test 2: User Preferences Update (DIS-04 Fix)
    Tests PUT /api/v1/user/preferences (No 404 error)
    """
    app.dependency_overrides[get_current_user] = lambda: mock_phase1_user
    app.dependency_overrides[get_db] = lambda: mock_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        pref_payload = {
            "is_incognito": True,
            "discreet_mode": True,
            "push_notifications_enabled": False
        }
        res = await client.put("/api/v1/user/preferences", json=pref_payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["updated_preferences"]["is_incognito"] is True
        assert data["updated_preferences"]["discreet_mode"] is True
        assert data["updated_preferences"]["push_notifications_enabled"] is False
        assert mock_db_session.execute.called
        assert mock_db_session.commit.called


@pytest.mark.asyncio
async def test_dis13_slumber_mode_sync(mock_phase1_user, mock_db_session):
    """
    Test 3: Night Slumber Mode Sync (DIS-13 Fix)
    Tests PATCH /api/v1/profile/slumber-mode
    """
    app.dependency_overrides[get_current_user] = lambda: mock_phase1_user
    app.dependency_overrides[get_db] = lambda: mock_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.patch(
            "/api/v1/profile/slumber-mode",
            json={"is_slumber_active": True}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["night_slumber"] is True
        assert mock_db_session.execute.called
        assert mock_db_session.commit.called


@pytest.mark.asyncio
async def test_dis05_crypto_key_registration(mock_phase1_user, mock_db_session):
    """
    Test 4: X25519 Public Key Registration (DIS-05 Fix)
    Tests POST /api/v1/crypto/rotate-key
    """
    app.dependency_overrides[get_current_user] = lambda: mock_phase1_user
    app.dependency_overrides[get_db] = lambda: mock_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 32 random bytes encoded in Base64 (44 chars)
        raw_key = b"X" * 32
        valid_b64_key = base64.b64encode(raw_key).decode("ascii")

        res = await client.post(
            "/api/v1/crypto/rotate-key",
            json={"public_key_base64": valid_b64_key}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "key_fingerprint" in data
        assert mock_db_session.execute.called

        # Invalid key length (not 32 bytes) must fail with 422
        bad_key = base64.b64encode(b"too_short").decode("ascii")
        res_bad = await client.post(
            "/api/v1/crypto/rotate-key",
            json={"public_key_base64": bad_key}
        )
        assert res_bad.status_code == 422


@pytest.mark.asyncio
async def test_dis10_nominee_flexible_schema(mock_phase1_user, mock_db_session):
    """
    Test 5: Nominee Flexible Schema (DIS-10 Fix)
    Tests POST /api/v1/vault/nominee with client fallback keys {'name', 'phone', 'relationship'}
    """
    app.dependency_overrides[get_current_user] = lambda: mock_phase1_user
    app.dependency_overrides[get_db] = lambda: mock_db_session

    # Mock DB query for existing nominee
    mock_db_result = MagicMock()
    mock_db_result.scalar_one_or_none.return_value = None
    mock_db_session.execute.return_value = mock_db_result

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        client_payload = {
            "name": "Ananya Sharma",
            "phone": "+919876543210",
            "relationship": "Sister"
        }
        res = await client.post("/api/v1/vault/nominee", json=client_payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert mock_db_session.commit.called


@pytest.mark.asyncio
async def test_dis11_grievance_flexible_schema(mock_phase1_user, mock_db_session):
    """
    Test 6: Grievance Flexible Schema (DIS-11 Fix)
    Tests POST /api/v1/vault/grievance with client keys
    """
    app.dependency_overrides[get_current_user] = lambda: mock_phase1_user
    app.dependency_overrides[get_db] = lambda: mock_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        grievance_payload = {
            "category": "harassment",
            "evidence": "Inappropriate unsolicited contact attempt."
        }
        res = await client.post("/api/v1/vault/grievance", json=grievance_payload)
        assert res.status_code == 201
        data = res.json()
        assert data["status"] == "acknowledged"
        assert "dossier_reference_id" in data
        assert mock_db_session.commit.called
