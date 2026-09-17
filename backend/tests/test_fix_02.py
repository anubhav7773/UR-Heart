import pytest
from httpx import AsyncClient
from uuid import uuid4
from datetime import date
from unittest.mock import patch
from app.main import app
from app.models.domain.user import User
from app.api.dependencies import get_current_user
from app.core.database import async_session_factory

@pytest.mark.asyncio
async def test_session_sync_creates_user_and_sets_super_admin(async_client: AsyncClient):
    """Test that session-sync creates user and sets is_super_admin=True for master admin email."""
    unique_phone = f"+9198{str(uuid4().int)[:8]}"
    mock_uid = str(uuid4())

    with patch("app.api.v1.endpoints.auth.verify_firebase_token") as mock_verify:
        mock_verify.return_value = {
            "uid": mock_uid,
            "email": "kshtriyaanubhav9120@gmail.com"
        }
        headers = {
            "Authorization": "Bearer mock_valid_admin_token",
            "X-Installation-UUID": str(uuid4())
        }
        payload = {
            "phone_number": unique_phone,
            "whatsapp_number": unique_phone,
            "full_name": "Master Admin User",
            "dob": "1995-05-15",
            "gender": "other",
            "city": "Lucknow",
            "bio": "ASI Master Admin"
        }
        response = await async_client.post("/api/v1/auth/session-sync", json=payload, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "created"

        # Verify database record
        async with async_session_factory() as session:
            stmt = User.__table__.select().where(User.firebase_uid == mock_uid)
            result = await session.execute(stmt)
            user_row = result.fetchone()
            assert user_row is not None
            assert user_row.is_super_admin is True

            # Cleanup
            await session.execute(User.__table__.delete().where(User.firebase_uid == mock_uid))
            await session.commit()

@pytest.mark.asyncio
async def test_admin_kyc_stats_returns_200_for_master_admin(async_client: AsyncClient, admin_token):
    """Test calling /api/v1/admin/kyc/stats with master admin returns 200 with stats object."""
    headers = {"Authorization": f"Bearer {admin_token}"}
    response = await async_client.get("/api/v1/admin/kyc/stats", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert "pending_count" in data
    assert "verified_count" in data
    assert "rejected_count" in data

@pytest.mark.asyncio
async def test_get_current_user_unregistered_raises_404(async_client: AsyncClient):
    """Test that authenticated token for unregistered user returns 404 instead of 500."""
    unregistered_uid = str(uuid4())
    with patch("app.api.dependencies.verify_firebase_token") as mock_verify:
        mock_verify.return_value = {
            "uid": unregistered_uid,
            "email": "unregistered@example.com"
        }
        headers = {"Authorization": "Bearer unregistered_token"}
        response = await async_client.get("/api/v1/user/feed?lat=26.8467&lon=80.9462", headers=headers)
        assert response.status_code == 404
        assert "not registered" in response.json()["detail"].lower()
