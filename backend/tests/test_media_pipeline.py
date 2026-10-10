import uuid
from unittest.mock import AsyncMock, MagicMock
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.security import get_current_user, get_current_active_user
from app.core.database import get_db
from app.models.domain.user import User


@pytest.fixture
def mock_media_user():
    user_id = uuid.UUID("12345678-1234-5678-1234-567812345678")
    return User(
        id=user_id,
        auth_id=uuid.uuid4(),
        full_name="Media Seeker",
        email="media@urheart.app",
        gender="Man",
        interested_in="Women",
        is_profile_completed=True,
        swipes_remaining=25,
        direct_letters_count=3,
    )


@pytest.mark.asyncio
async def test_presigned_url_generation(mock_media_user):
    # 1. Unauthenticated request is rejected with 401 Unauthorized
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        unauth_resp = await ac.post(
            "/api/v1/media/presigned-url",
            json={"slot_number": 1, "content_type": "image/webp"}
        )
        assert unauth_resp.status_code == 401

    # 2. Authenticated request succeeds and binds to caller UUID
    app.dependency_overrides[get_current_user] = lambda: mock_media_user
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.post(
                "/api/v1/media/presigned-url",
                json={
                    "user_id": str(mock_media_user.id),
                    "slot_number": 1,
                    "content_type": "image/webp"
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert "upload_url" in data
            assert "public_file_key" in data
            assert data["public_file_key"] == f"users/{mock_media_user.id}/photos/slot_1.webp"
    finally:
        app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.asyncio
async def test_direct_media_upload_stream(mock_media_user):
    user_id_str = str(mock_media_user.id)
    transport = ASGITransport(app=app)

    # 1. Unauthenticated upload rejected with 401
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        dummy_bytes = b"RIFF....WEBPVP8 ...test_image_data..."
        unauth_resp = await ac.put(
            f"/api/v1/media/upload/{user_id_str}/1",
            content=dummy_bytes,
            headers={"Content-Type": "image/webp"}
        )
        assert unauth_resp.status_code == 401

    # 2. Authenticated upload succeeds
    app.dependency_overrides[get_current_user] = lambda: mock_media_user
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.put(
                f"/api/v1/media/upload/{user_id_str}/1",
                content=dummy_bytes,
                headers={"Content-Type": "image/webp"}
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert data["file_key"] == f"users/{user_id_str}/photos/slot_1.webp"
            assert data["bytes_received"] == len(dummy_bytes)
    finally:
        app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.asyncio
async def test_feed_discovery_includes_live_quota(mock_media_user):
    transport = ASGITransport(app=app)

    # 1. Unauthenticated discovery feed request rejected with 401 (VULN-FEED-01)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        unauth_resp = await ac.get("/api/v1/discovery/feed?limit=5")
        assert unauth_resp.status_code == 401

    # 2. Authenticated request returns quota metrics
    cand = User(
        id=uuid.uuid4(),
        full_name="Candidate",
        email="cand@urheart.app",
        gender="Woman",
        interested_in="Men",
        is_profile_completed=True,
    )
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.all.return_value = [cand]
    mock_db.execute = AsyncMock(return_value=mock_res)

    app.dependency_overrides[get_current_active_user] = lambda: mock_media_user
    app.dependency_overrides[get_db] = lambda: mock_db
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.get("/api/v1/discovery/feed?limit=5")
            assert response.status_code == 200
            data = response.json()
            assert "candidates" in data
            assert "swipes_remaining" in data
            assert "direct_letters_count" in data
    finally:
        app.dependency_overrides.pop(get_current_active_user, None)
        app.dependency_overrides.pop(get_db, None)
