import pytest
from uuid import uuid4
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto

client = TestClient(app)

def test_delete_slot_1_hero_photo_rejected():
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_test_hero_delete",
        full_name="Ananya Sharma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.delete(
            "/api/v1/user/photos/1",
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 400
        assert "Primary hero photo" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()

def test_delete_empty_photo_slot_returns_404():
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_test_empty_slot",
        full_name="Ananya Sharma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_res

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.delete(
            "/api/v1/user/photos/3",
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 404
        assert "already empty" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()

def test_delete_secondary_photo_success():
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_test_secondary_slot",
        full_name="Ananya Sharma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    photo = UserPhoto(
        user_id=user_id,
        slot_index=2,
        photo_storage_path=f"{user_id}/slot_2.webp",
        blur_hash="LEHLh[WB2yk8pyoJadR*.7kCMdnj",
        ocr_verified=True,
        created_at=datetime.now(timezone.utc)
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = photo
    mock_db.execute.return_value = mock_res

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = override_get_db

    try:
        with patch("app.api.v1.endpoints.user.supabase_storage_client") as mock_storage:
            mock_storage.storage.from_.return_value.remove.return_value = []
            response = client.delete(
                "/api/v1/user/photos/2",
                headers={"X-Installation-UUID": "test-uuid"}
            )
            assert response.status_code == 200
            assert response.json()["status"] == "success"
            assert mock_db.delete.called
            assert mock_db.commit.called
    finally:
        app.dependency_overrides.clear()
