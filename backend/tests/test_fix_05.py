import io
from uuid import uuid4
from datetime import date, datetime
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto

client = TestClient(app)

# Minimal valid WebP bytes: RIFF....WEBPVP8 ...
MINIMAL_WEBP = (
    b"RIFF\x1a\x00\x00\x00WEBPVP8 \x0e\x00\x00\x00"
    b"\x30\x01\x00\x9d\x01\x2a\x01\x00\x01\x00\x02\x00\x34\x25"
)

def test_get_profile_returns_photos_array():
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_secret_uid_12345",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        full_name="Ananya Sharma",
        dob=date(1998, 4, 15),
        gender="female",
        city="Mumbai",
        bio="Architecture & Design",
        streak_count=5,
        reward_balance=120,
        kyc_status=True,
        is_super_admin=False,
        is_banned=False,
    )

    p1 = UserPhoto(
        user_id=user_id,
        slot_index=1,
        photo_storage_path=f"{user_id}/slot_1.webp",
        blur_hash="LEHLh[WB2yk8pyoJadR*.7kCMdnj",
        ocr_verified=True,
        created_at=datetime.utcnow()
    )
    p3 = UserPhoto(
        user_id=user_id,
        slot_index=3,
        photo_storage_path=f"https://pzrsyxvjbmzqlzlehuxg.supabase.co/storage/v1/object/public/user-photos/{user_id}/slot_3.webp",
        blur_hash="L6PZfSi_.AyE_3t7t7R**0o#DgR4",
        ocr_verified=True,
        created_at=datetime.utcnow()
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.all.return_value = [p1, p3]
    mock_db.execute.return_value = mock_res

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.get(
            "/api/v1/users/profile",
            headers={"Authorization": "Bearer mock_token"}
        )
        assert response.status_code == 200
        data = response.json()

        assert data["id"] == str(user_id)
        assert data["full_name"] == "Ananya Sharma"
        assert data["kyc_status"] is True
        assert "is_super_admin" not in data  # Security data minimization invariant
        assert "photos" in data
        assert len(data["photos"]) == 2
        assert data["photo_count"] == 2

        # Check Slot 1
        assert data["photos"][0]["slot_index"] == 1
        assert "slot_1.webp" in data["photos"][0]["photo_url"]
        assert data["photos"][0]["photo_url"].startswith("http")
        assert data["photos"][0]["blur_hash"] == "LEHLh[WB2yk8pyoJadR*.7kCMdnj"

        # Check Slot 3
        assert data["photos"][1]["slot_index"] == 3
        assert "slot_3.webp" in data["photos"][1]["photo_url"]
        assert data["photos"][1]["blur_hash"] == "L6PZfSi_.AyE_3t7t7R**0o#DgR4"

    finally:
        app.dependency_overrides.clear()


def test_upload_photo_persists_to_database():
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_secret_uid_12345",
        phone_number="+919876543211",
        whatsapp_number="+919876543211",
        full_name="Rohit Verma",
        dob=date(1995, 10, 20),
        gender="male",
        city="Bengaluru",
        bio="Tech entrepreneur",
        streak_count=10,
        reward_balance=250,
        kyc_status=False,
        is_super_admin=False,
        is_banned=False,
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.first.return_value = None
    mock_db.execute.return_value = mock_res
    mock_db.commit = AsyncMock()

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = override_get_db

    try:
        # 1. Upload valid slot 1 photo
        with patch("app.api.v1.endpoints.user.upload_profile_photo_to_storage", return_value=f"https://pzrsyxvjbmzqlzlehuxg.supabase.co/storage/v1/object/public/user-photos/{user_id}/slot_1.webp"):
            response = client.post(
                "/api/v1/user/photos/upload",
                data={
                    "slot_index": 1,
                    "blur_hash": "LEHLh[WB2yk8pyoJadR*.7kCMdnj"
                },
                files={
                    "file": ("slot_1.webp", io.BytesIO(MINIMAL_WEBP), "image/webp")
                },
                headers={"Authorization": "Bearer mock_token"}
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert data["slot_index"] == 1
            assert "slot_1.webp" in data["photo_url"]
            assert data["blur_hash"] == "LEHLh[WB2yk8pyoJadR*.7kCMdnj"
            assert mock_db.commit.called

        # 2. Invalid slot rejection (e.g. slot 0 or slot 6)
        bad_slot_resp = client.post(
            "/api/v1/user/photos/upload",
            data={"slot_index": 6},
            files={"file": ("slot_6.webp", io.BytesIO(MINIMAL_WEBP), "image/webp")},
            headers={"Authorization": "Bearer mock_token"}
        )
        assert bad_slot_resp.status_code == 422

    finally:
        app.dependency_overrides.clear()
