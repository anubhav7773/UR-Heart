import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient
from jose import jwt

from app.main import app
from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.api.v1.endpoints.auth import MAGIC_LINK_VAULT
from app.core.security import JWT_SECRET_KEY, create_access_token


client = TestClient(app)


@pytest.mark.asyncio
async def test_google_sync_superadmin_elevation():
    """Verify that POST /api/v1/auth/google-sync elevates asiverticals@gmail.com to superadmin."""
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()

    app.dependency_overrides[get_db] = lambda: mock_db

    from unittest.mock import patch
    with patch("app.core.security.verify_firebase_jwt", AsyncMock(return_value={"email": "asiverticals@gmail.com"})):
        try:
            response = client.post(
                "/api/v1/auth/google-sync",
                json={
                    "email": "asiverticals@gmail.com",
                    "user_id": str(uuid.uuid4()),
                    "display_name": "Sanctuary Founder",
                    "id_token": "mock_google_id_token_superadmin"
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "synchronized"
            assert data["email"] == "asiverticals@gmail.com"
            assert data["role"] == "superadmin"
        finally:
            app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_magic_link_superadmin_elevation():
    """Verify that POST /api/v1/auth/verify-magic-link returns superadmin role for asiverticals@gmail.com."""
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()

    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        response = client.post(
            "/api/v1/auth/verify-magic-link",
            json={
                "email": "asiverticals@gmail.com",
                "token": "admin_test_token"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "authenticated"
        assert data["email"] == "asiverticals@gmail.com"
        assert data["role"] == "superadmin"

        # Verify decoded JWT has role="superadmin"
        payload = jwt.decode(data["access_token"], JWT_SECRET_KEY, algorithms=["HS256"])
        assert payload.get("role") == "superadmin"
        assert payload.get("email") == "asiverticals@gmail.com"
    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_superadmin_kyc_and_portal_access():
    """Verify that asiverticals@gmail.com gets 200 on admin endpoints and regular user gets 403."""
    superadmin_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        email="asiverticals@gmail.com",
        full_name="Sanctuary Founder",
        role="superadmin"
    )

    regular_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        email="regular.seeker@urheart.app",
        full_name="Regular Seeker",
        role="user"
    )

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = []
    mock_db.execute.return_value = mock_result
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # 1. Superadmin user access
        app.dependency_overrides[get_current_user] = lambda: superadmin_user
        kyc_resp = client.get("/api/v1/admin/kyc/escalations")
        assert kyc_resp.status_code == 200

        # 2. Regular user access denied
        app.dependency_overrides[get_current_user] = lambda: regular_user
        forbidden_resp = client.get("/api/v1/admin/kyc/escalations")
        assert forbidden_resp.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)
