import pytest
from uuid import uuid4
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.second_chance import SecondChanceUnlock, SecondChanceDm

client = TestClient(app)

def test_get_missed_connections_14_day_filter_and_bio_obscuring():
    viewer_id = uuid4()
    target_recent_id = uuid4()
    target_unlocked_id = uuid4()

    viewer = User(
        id=viewer_id,
        firebase_uid="fb_viewer_1",
        full_name="Rajesh Kumar",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    recent_row = MagicMock()
    recent_row.id = target_recent_id
    recent_row.full_name = "Sneha Patel"
    recent_row.city = "Ahmedabad"
    recent_row.detected_locality = "Navrangpura"
    recent_row.bio = "Love chai and coding"
    recent_row.streak_count = 3
    recent_row.passed_at = datetime.now(timezone.utc) - timedelta(days=2)

    unlocked_row = MagicMock()
    unlocked_row.id = target_unlocked_id
    unlocked_row.full_name = "Pooja Hegde"
    unlocked_row.city = "Mumbai"
    unlocked_row.detected_locality = "Bandra"
    unlocked_row.bio = "Architect and traveler"
    unlocked_row.streak_count = 10
    unlocked_row.passed_at = datetime.now(timezone.utc) - timedelta(days=5)

    mock_db = AsyncMock()

    # Main query result
    mock_main_res = MagicMock()
    mock_main_res.all.return_value = [recent_row, unlocked_row]

    # Subquery unlocks result: target_unlocked_id is unlocked
    mock_unlock_res = MagicMock()
    mock_unlock_res.scalars.return_value.all.return_value = [target_unlocked_id]

    # Photo results (None for simplicity)
    mock_photo_res = MagicMock()
    mock_photo_res.scalar_one_or_none.return_value = None

    mock_db.execute.side_effect = [mock_main_res, mock_unlock_res, mock_photo_res, mock_photo_res]

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: viewer
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.get(
            "/api/v1/swipes/missed",
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

        # 1. recent_row: NOT unlocked -> bio is None
        assert data[0]["full_name"] == "Sneha Patel"
        assert data[0]["is_unlocked_for_view"] is False
        assert data[0]["bio"] is None

        # 2. unlocked_row: Unlocked -> bio is revealed
        assert data[1]["full_name"] == "Pooja Hegde"
        assert data[1]["is_unlocked_for_view"] is True
        assert data[1]["bio"] == "Architect and traveler"
    finally:
        app.dependency_overrides.clear()


def test_unlock_missed_profile_view():
    viewer_id = uuid4()
    target_id = uuid4()

    viewer = User(
        id=viewer_id,
        firebase_uid="fb_viewer_2",
        full_name="Rajesh Kumar",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    # Check existing unlock: None
    mock_exist_res = MagicMock()
    mock_exist_res.scalar_one_or_none.return_value = None

    # Fetch bio: "Special unlocked bio"
    mock_bio_res = MagicMock()
    mock_bio_res.scalar_one_or_none.return_value = "Special unlocked bio"

    mock_db.execute.side_effect = [mock_exist_res, mock_bio_res]

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: viewer
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.post(
            f"/api/v1/swipes/missed/{target_id}/unlock-view",
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 200
        result = response.json()
        assert result["status"] == "unlocked"
        assert result["bio"] == "Special unlocked bio"
        assert "expires_at" in result
        assert mock_db.add.called
        assert mock_db.commit.called
    finally:
        app.dependency_overrides.clear()


def test_send_missed_connection_dm_anti_leak_rejection():
    viewer_id = uuid4()
    target_id = uuid4()

    viewer = User(
        id=viewer_id,
        firebase_uid="fb_viewer_3",
        full_name="Rajesh Kumar",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: viewer
    app.dependency_overrides[get_db] = override_get_db

    try:
        # Attempt to send phone number in direct DM
        response = client.post(
            f"/api/v1/swipes/missed/{target_id}/send-dm",
            json={"message": "Hey call me at 9876543210"},
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 422
        assert "strictly prohibited" in response.json()["detail"]

        # Attempt to send instagram handle in direct DM
        response2 = client.post(
            f"/api/v1/swipes/missed/{target_id}/send-dm",
            json={"message": "My ig is @rajesh_007"},
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response2.status_code == 422
        assert "strictly prohibited" in response2.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_send_missed_connection_dm_daily_limit_3():
    viewer_id = uuid4()
    target_id = uuid4()

    viewer = User(
        id=viewer_id,
        firebase_uid="fb_viewer_4",
        full_name="Rajesh Kumar",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    # When daily count is already 3
    mock_count_res = MagicMock()
    mock_count_res.scalar_one.return_value = 3
    mock_db.execute.return_value = mock_count_res

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: viewer
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.post(
            f"/api/v1/swipes/missed/{target_id}/send-dm",
            json={"message": "Hey, let's catch up!"},
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 429
        assert "Daily limit reached" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_send_missed_connection_dm_success():
    viewer_id = uuid4()
    target_id = uuid4()

    viewer = User(
        id=viewer_id,
        firebase_uid="fb_viewer_5",
        full_name="Rajesh Kumar",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        kyc_status=True,
    )

    mock_db = AsyncMock()

    # Daily count check: 1 message sent so far
    mock_count_res = MagicMock()
    mock_count_res.scalar_one.return_value = 1

    # Match check: existing match found
    mock_match = MagicMock()
    mock_match.id = uuid4()
    mock_match_res = MagicMock()
    mock_match_res.scalar_one_or_none.return_value = mock_match

    # Swipe check: existing swipe found
    mock_swipe = MagicMock()
    mock_swipe_res = MagicMock()
    mock_swipe_res.scalar_one_or_none.return_value = mock_swipe

    mock_db.execute.side_effect = [mock_count_res, mock_match_res, mock_swipe_res]

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_current_user] = lambda: viewer
    app.dependency_overrides[get_db] = override_get_db

    try:
        response = client.post(
            f"/api/v1/swipes/missed/{target_id}/send-dm",
            json={"message": "Loved your taste in music!"},
            headers={"X-Installation-UUID": "test-uuid"}
        )
        assert response.status_code == 200
        assert response.json()["status"] == "sent"
        assert response.json()["recipient_id"] == str(target_id)
        assert mock_db.commit.called
    finally:
        app.dependency_overrides.clear()
