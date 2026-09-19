"""
Tests for FIX-11: Privacy Controls, Blocked Users & DPDP Section 11 Account Erasure.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4
from datetime import datetime, timezone
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.models.domain.user import User
from app.models.domain.blocked_user import BlockedUser
from app.models.domain.user_photo import UserPhoto


def _make_mock_user(**overrides):
    user = MagicMock(spec=User)
    user.id = overrides.get("id", uuid4())
    user.firebase_uid = overrides.get("firebase_uid", "test_firebase_uid")
    user.full_name = overrides.get("full_name", "Test User")
    user.city = overrides.get("city", "Delhi")
    user.phone_number = "+919876543210"
    user.whatsapp_number = "+919876543210"
    user.bio = "Test bio"
    user.streak_count = 5
    user.reward_balance = 10
    user.is_incognito = overrides.get("is_incognito", False)
    user.hide_distance = overrides.get("hide_distance", False)
    user.deleted_at = None
    user.updated_at = datetime.now(timezone.utc)
    return user


@pytest.fixture
def mock_user():
    return _make_mock_user()


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.commit = AsyncMock()
    return db


@pytest.mark.asyncio
async def test_get_blocked_users_empty_list(mock_user, mock_db):
    """GET /api/v1/safety/blocked returns empty list when no blocked users exist."""
    mock_result = MagicMock()
    mock_result.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_result)

    with patch("app.api.v1.endpoints.safety.get_current_user", return_value=mock_user), \
         patch("app.api.v1.endpoints.safety.get_db", return_value=mock_db):

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                "/api/v1/safety/blocked",
                headers={"Authorization": "Bearer test_token"}
            )

    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_unblock_user_not_found(mock_user, mock_db):
    """DELETE /api/v1/safety/unblock/{id} returns 404 when block record doesn't exist."""
    mock_result = MagicMock()
    mock_result.rowcount = 0
    mock_db.execute = AsyncMock(return_value=mock_result)

    target_id = str(uuid4())

    with patch("app.api.v1.endpoints.safety.get_current_user", return_value=mock_user), \
         patch("app.api.v1.endpoints.safety.get_db", return_value=mock_db):

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.delete(
                f"/api/v1/safety/unblock/{target_id}",
                headers={"Authorization": "Bearer test_token"}
            )

    assert response.status_code == 404
    assert "Block record not found" in response.json()["detail"]


@pytest.mark.asyncio
async def test_update_privacy_settings_incognito(mock_user, mock_db):
    """PATCH /api/v1/safety/privacy-settings updates incognito and hide_distance flags."""
    mock_db.execute = AsyncMock()

    with patch("app.api.v1.endpoints.safety.get_current_user", return_value=mock_user), \
         patch("app.api.v1.endpoints.safety.get_db", return_value=mock_db):

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.patch(
                "/api/v1/safety/privacy-settings",
                json={"is_incognito": True, "hide_distance": True},
                headers={"Authorization": "Bearer test_token"}
            )

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "updated"
    assert data["is_incognito"] is True
    assert data["hide_distance"] is True


@pytest.mark.asyncio
async def test_erase_account_dpdp_section_11(mock_user, mock_db):
    """POST /api/v1/safety/erase-account returns statutory erasure confirmation."""
    mock_db.execute = AsyncMock()

    with patch("app.api.v1.endpoints.safety.get_current_user", return_value=mock_user), \
         patch("app.api.v1.endpoints.safety.get_db", return_value=mock_db), \
         patch("app.api.v1.endpoints.safety.purge_user_storage_assets", new_callable=AsyncMock), \
         patch("app.api.v1.endpoints.safety.record_legal_audit_event", new_callable=AsyncMock):

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/api/v1/safety/erase-account",
                headers={"Authorization": "Bearer test_token"}
            )

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "erased"
    assert "Section 11 DPDP Act 2023" in data["message"]


@pytest.mark.asyncio
async def test_privacy_settings_reject_extra_fields(mock_user, mock_db):
    """PATCH /api/v1/safety/privacy-settings rejects payloads with extra fields."""

    with patch("app.api.v1.endpoints.safety.get_current_user", return_value=mock_user), \
         patch("app.api.v1.endpoints.safety.get_db", return_value=mock_db):

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.patch(
                "/api/v1/safety/privacy-settings",
                json={"is_incognito": True, "hide_distance": False, "is_admin": True},
                headers={"Authorization": "Bearer test_token"}
            )

    assert response.status_code == 422
