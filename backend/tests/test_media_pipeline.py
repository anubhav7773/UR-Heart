import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_presigned_url_generation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/media/presigned-url",
            json={
                "user_id": "test-user-123",
                "slot_number": 1,
                "content_type": "image/webp"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "upload_url" in data
        assert "public_file_key" in data
        assert data["public_file_key"] == "users/test-user-123/photos/slot_1.webp"


@pytest.mark.asyncio
async def test_direct_media_upload_stream():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        dummy_bytes = b"RIFF....WEBPVP8 ...test_image_data..."
        response = await ac.put(
            "/api/v1/media/upload/test-user-123/1",
            content=dummy_bytes,
            headers={"Content-Type": "image/webp"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["file_key"] == "users/test-user-123/photos/slot_1.webp"
        assert data["bytes_received"] == len(dummy_bytes)


@pytest.mark.asyncio
async def test_feed_discovery_includes_live_quota():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/api/v1/discovery/feed?limit=5")
        assert response.status_code == 200
        data = response.json()
        assert "candidates" in data
        assert "swipes_remaining" in data
        assert "direct_letters_count" in data
