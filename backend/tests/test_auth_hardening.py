import pytest
from httpx import AsyncClient
from unittest.mock import patch
import time

@pytest.mark.asyncio
async def test_missing_auth_header_rejected(async_client: AsyncClient):
    response = await async_client.get("/api/v1/users/profile")
    assert response.status_code == 401
    assert "Not authenticated" in response.text or "missing" in response.text.lower()


@pytest.mark.asyncio
async def test_invalid_jwt_rejected(async_client: AsyncClient):
    headers = {"Authorization": "Bearer invalid.token.structure"}
    response = await async_client.get("/api/v1/users/profile", headers=headers)
    assert response.status_code == 401
    assert "Invalid authentication token" in response.json()["detail"]


@pytest.mark.asyncio
async def test_expired_jwt_rejected(async_client: AsyncClient):
    """Simulates an expired token and ensures 401 is returned."""
    expired_time = int(time.time()) - 100
    mock_payload = {
        "uid": "test-uid-123",
        "email": "user@example.com",
        "exp": expired_time,
        "auth_time": expired_time - 3600
    }
    with patch("app.api.dependencies.verify_firebase_token", return_value=mock_payload):
        headers = {"Authorization": "Bearer mock.expired.jwt"}
        response = await async_client.get("/api/v1/users/profile", headers=headers)
        assert response.status_code == 401
        assert "expired" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_stale_session_rejected(async_client: AsyncClient):
    """Simulates a session older than MAX_SESSION_AGE_SECONDS * 24 and ensures 401 is returned."""
    now = int(time.time())
    mock_payload = {
        "uid": "test-uid-123",
        "email": "user@example.com",
        "exp": now + 3600,
        "auth_time": now - (3600 * 25) # 25 hours ago
    }
    with patch("app.api.dependencies.verify_firebase_token", return_value=mock_payload):
        headers = {"Authorization": "Bearer mock.stale.jwt"}
        response = await async_client.get("/api/v1/users/profile", headers=headers)
        assert response.status_code == 401
        assert "session is too old" in response.json()["detail"].lower()


def test_ephemeral_container_cache_cleaner(tmp_path):
    """Verifies that expired files (>300s) in temporary storage are deleted."""
    import app.services.ephemeral_cleaner as cleaner
    test_dir = tmp_path / "temp_uploads"
    test_dir.mkdir()

    old_file = test_dir / "chunk_old.tmp"
    old_file.write_text("old chunk data")
    # Set mtime to 400 seconds ago
    os_time = time.time() - 400
    import os
    os.utime(old_file, (os_time, os_time))

    new_file = test_dir / "chunk_new.tmp"
    new_file.write_text("recent chunk data")

    with patch.object(cleaner, "TEMP_UPLOAD_DIR", test_dir):
        cleaner.purge_ephemeral_container_cache()

    assert not old_file.exists(), "Old temporary file should have been purged"
    assert new_file.exists(), "Recent temporary file should be preserved"
