import pytest
import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from jose import jwt
from app.main import app
from app.core.database import get_db
from app.models.domain.user import User
from app.api.v1.endpoints.auth import MAGIC_LINK_VAULT, EMAIL_VERIFICATION_STATUS
from app.core.security import JWT_SECRET_KEY


client = TestClient(app)


@pytest.mark.asyncio
async def test_auth_login_returns_session_tokens():
    """Verify that POST /api/v1/auth/login generates session JWT and returns user_id."""
    test_email = f"verified_user_{uuid.uuid4().hex[:6]}@example.com"

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()

    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        response = client.post(
            "/api/v1/auth/login",
            json={"email": test_email, "password": "secure_password_123"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "authenticated"
        assert data["email"] == test_email
        assert "access_token" in data
        assert data["access_token"] is not None
        assert "user_id" in data
        assert data["user_id"] is not None

        # Verify decoded JWT payload matches user_id and email
        payload = jwt.decode(data["access_token"], JWT_SECRET_KEY, algorithms=["HS256"])
        assert payload is not None
        assert payload.get("sub") == data["user_id"]
        assert payload.get("email") == test_email

    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_verify_magic_link_browser_handoff_tolerance():
    """Verify that verify-magic-link accepts tokens used in browser tap within expiration."""
    test_token = f"tok_{uuid.uuid4().hex}"
    test_email = f"deep_link_{uuid.uuid4().hex[:6]}@example.com"

    # Simulate browser tap marking token used
    MAGIC_LINK_VAULT[test_token] = {
        "email": test_email,
        "expires_at": datetime.now(timezone.utc) + timedelta(minutes=10),
        "used": True,
    }

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()


    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # App deep link fires with the same token
        response = client.post(
            "/api/v1/auth/verify-magic-link",
            json={"token": test_token, "email": test_email},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "authenticated"
        assert data["email"] == test_email
        assert "access_token" in data
        assert data["access_token"] is not None
    finally:
        app.dependency_overrides.pop(get_db, None)
        MAGIC_LINK_VAULT.pop(test_token, None)
