import os
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app
from app.services.chat_sanitizer import inspect_chat_message
from app.core.config import get_settings

settings = get_settings()


@pytest.mark.asyncio
async def test_uptimerobot_head_keep_alive():
    """
    Exit Criteria 1: UptimeRobot HEAD Keep-Alive Test.
    Must return HTTP 200 OK with zero-length response body.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Test HEAD
        head_response = await client.head("/api/v1/health")
        assert head_response.status_code == 200
        assert len(head_response.content) == 0, f"Expected 0 bytes, got {len(head_response.content)}"

        # Test GET
        get_response = await client.get("/api/v1/health")
        assert get_response.status_code == 200
        data = get_response.json()
        assert data["status"] == "active"
        assert "uptime_seconds" in data
        assert data["engine"] == "FastAPI-Async-Sleepless"


def test_nlp_filter_specifications():
    """
    Exit Criteria 2: NLP Filter Test.
    Tests phone number, transliteration, and mindful allowed chat.
    """
    # Indian Phone Blocked
    assert inspect_chat_message("call me on 9876543210")[0] is False
    assert inspect_chat_message("phone: +91 98200 12345")[0] is False

    # Transliteration Blocked
    assert inspect_chat_message("mera no hai nau aath saat")[0] is False
    assert inspect_chat_message("contact at nine eight seven six five four three two one zero")[0] is False

    # Social Handles & Links Blocked
    assert inspect_chat_message("hit me up on @insta_user")[0] is False
    assert inspect_chat_message("check out https://wa.me/919999999999")[0] is False

    # Mindful Chat Allowed
    assert inspect_chat_message("I love reading quiet books")[0] is True
    assert inspect_chat_message("The sunset at Marine Drive today was truly peaceful")[0] is True


@pytest.mark.asyncio
async def test_superadmin_kyc_forbidden_for_non_admin():
    """
    Exit Criteria 3: Superadmin Security Gate Test.
    Any non-superadmin token must strictly receive HTTP 403 Forbidden.
    """
    from unittest.mock import AsyncMock
    from app.api.dependencies import get_current_user, get_db
    from app.models.domain.user import User
    import uuid

    fake_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Attacker",
        email="hacker@evil.com"
    )

    async def mock_user():
        return fake_user

    async def mock_db():
        yield AsyncMock()

    app.dependency_overrides[get_current_user] = mock_user
    app.dependency_overrides[get_db] = mock_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = {
            "Authorization": "Bearer fake_token",
            "x-installation-uuid": "test-uuid-device-1234"
        }
        response = await client.get("/api/v1/admin/kyc/pending-queue", headers=headers)
        assert response.status_code == 403
        data = response.json()
        assert "Sanctuary Sovereign privileges" in data.get("message", "")

    app.dependency_overrides.clear()
