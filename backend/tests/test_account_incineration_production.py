import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.services.data_incinerator_service import DataIncineratorService

client = TestClient(app)


def test_web_deletion_request_validation():
    """Verify invalid emails are rejected cleanly."""
    res = client.post("/api/v1/vault/request-web-deletion", json={"email": "invalid-email-format"})
    assert res.status_code == 422


def test_web_deletion_request_success():
    """Verify valid email triggers multi-platform incineration and returns 200."""
    with patch.object(
        DataIncineratorService,
        "incinerate_user",
        new=AsyncMock(return_value={
            "email": "test-incineration@urheart.app",
            "firebase_purged": True,
            "supabase_auth_purged": True,
            "storage_purged_files": ["users/test_uid/moments/slot_1.webp"],
            "database_purged": True,
        }),
    ) as mock_incinerate:
        res = client.post(
            "/api/v1/vault/request-web-deletion",
            json={"email": "test-incineration@urheart.app", "reason": "Moving on"},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "audit" in data
        assert data["audit"]["firebase_purged"] is True
        assert data["audit"]["storage_purged_files"] == ["users/test_uid/moments/slot_1.webp"]
        mock_incinerate.assert_awaited_once()


@pytest.mark.asyncio
async def test_data_incinerator_service_idempotence():
    """Verify DataIncineratorService executes cleanly even with non-existent user."""
    with patch("app.services.firebase_auth_service.FirebaseAuthService.delete_user_account", return_value=True):
        res = await DataIncineratorService.incinerate_user(
            email="nonexistent-clean-user@urheart.app",
            firebase_uid="nonexistent_fb_uid_123",
        )
        assert res["email"] == "nonexistent-clean-user@urheart.app"
        assert res["firebase_purged"] is True
        assert isinstance(res["storage_purged_files"], list)
