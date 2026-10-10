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


from app.core.database import get_db
from app.models.domain.user import User
import uuid

def test_web_deletion_request_success():
    """Verify valid email triggers statutory 2-step verification and returns pending_verification (SEC-13 / COMP-01)."""
    mock_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        email="test-incineration@urheart.app",
        full_name="Incineration Target",
    )
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_user
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_db] = lambda: mock_db
    try:
        with patch("app.services.email_service.EmailService.dispatch_account_deletion_confirmation", new=AsyncMock(return_value=True)):
            res = client.post(
                "/api/v1/vault/request-web-deletion",
                json={"email": "test-incineration@urheart.app", "reason": "Moving on"},
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "pending_verification"
            assert "verification link has been dispatched" in data["message"]
    finally:
        app.dependency_overrides.pop(get_db, None)


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
