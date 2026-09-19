import pytest
from datetime import date
from uuid import uuid4
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.api.dependencies import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match

client = TestClient(app)

@pytest.fixture
def mock_current_user():
    user = User(
        id=uuid4(),
        firebase_uid="test_current_user_uid",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        full_name="Aman Sharma",
        dob=date(1998, 5, 15),
        gender="male",
        city="Lucknow",
        bio="Test Bio",
        is_banned=False,
    )
    return user

@pytest.fixture
def mock_candidate_user():
    user = User(
        id=uuid4(),
        firebase_uid="test_candidate_user_uid",
        phone_number="+919876543211",
        whatsapp_number="+919876543211",
        full_name="Priya Singh",
        dob=date(2001, 8, 20),
        gender="female",
        city="Lucknow",
        bio="Lover of chai and books",
        is_banned=False,
        streak_count=5,
        kyc_status=True,
    )
    return user

def test_get_discovery_feed(mock_current_user, mock_candidate_user):
    """Verifies that GET /api/v1/feed returns formatted candidate profiles with coarse distance and resolved HTTPS CDN photo URLs."""
    app.dependency_overrides[get_current_user] = lambda: mock_current_user

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.mappings.return_value.all.return_value = [
        {
            "user_id": mock_candidate_user.id,
            "full_name": mock_candidate_user.full_name,
            "city": mock_candidate_user.city,
            "detected_locality": "Hazratganj",
            "distance_km": 5,
            "gender": mock_candidate_user.gender,
            "bio": mock_candidate_user.bio,
            "streak_count": mock_candidate_user.streak_count,
            "photos": [
                {
                    "slot_index": 1,
                    "photo_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
                    "blur_hash": "LEHLh[WB2yk8pyoJadR*.7kCMdnj",
                },
                {
                    "slot_index": 2,
                    "photo_storage_path": f"{mock_candidate_user.id}/slot_2.webp",
                    "blur_hash": "LEHLh[WB2yk8pyoJadR*.7kCMdnj",
                }
            ],
        }
    ]

    mock_db.execute.return_value = mock_res
    app.dependency_overrides[get_db] = lambda: mock_db

    response = client.get("/api/v1/feed?lat=26.8467&lon=80.9462")
    assert response.status_code == 200
    candidates = response.json()
    assert isinstance(candidates, list)
    assert len(candidates) == 1
    candidate = candidates[0]
    assert candidate["full_name"] == "Priya Singh"
    assert candidate["gender"] == "female"
    assert len(candidate["photos"]) == 2
    assert "distance_km" in candidate
    # Strict Geo-Privacy: Zero Coordinate Leakage
    assert "latitude" not in candidate
    assert "longitude" not in candidate
    # CDN resolution verification
    assert candidate["photos"][0]["photo_url"].startswith("https://")
    assert candidate["photos"][1]["photo_url"].startswith("https://")
    assert candidate["photos"][1]["photo_storage_path"].startswith("https://")
    assert "slot_2.webp" in candidate["photos"][1]["photo_url"]

    app.dependency_overrides.clear()


def test_swipe_like_mutual_match(mock_current_user, mock_candidate_user):
    """Verifies mutual like triggers is_match=True and creates a Match record."""
    app.dependency_overrides[get_current_user] = lambda: mock_current_user

    mock_db = AsyncMock()

    # 1. Target user check
    target_res = MagicMock()
    target_res.scalar_one_or_none.return_value = mock_candidate_user

    # 2. Existing swipe check
    existing_swipe_res = MagicMock()
    existing_swipe_res.scalar_one_or_none.return_value = None

    # 3. Reciprocal swipe check (target user already liked current user!)
    reciprocal_swipe = Swipe(
        actor_id=mock_candidate_user.id,
        target_id=mock_current_user.id,
        swipe_type="like",
    )
    reciprocal_res = MagicMock()
    reciprocal_res.scalar_one_or_none.return_value = reciprocal_swipe

    # 4. Existing match check
    match_res = MagicMock()
    match_res.scalar_one_or_none.return_value = None

    mock_db.execute.side_effect = [
        target_res,
        existing_swipe_res,
        reciprocal_res,
        match_res,
    ]
    app.dependency_overrides[get_db] = lambda: mock_db

    payload = {
        "target_user_id": str(mock_candidate_user.id),
        "swipe_type": "like",
    }
    response = client.post("/api/v1/feed/swipe", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["is_match"] is True
    assert "match" in data["message"].lower()

    app.dependency_overrides.clear()

def test_swipe_direct_dm_token_decrement(mock_current_user, mock_candidate_user):
    """Verifies direct_dm swipe decrements reward_balance and returns remaining tokens."""
    mock_current_user.reward_balance = 3
    app.dependency_overrides[get_current_user] = lambda: mock_current_user

    mock_db = AsyncMock()
    target_res = MagicMock()
    target_res.scalar_one_or_none.return_value = mock_candidate_user

    existing_swipe_res = MagicMock()
    existing_swipe_res.scalar_one_or_none.return_value = None

    reciprocal_res = MagicMock()
    reciprocal_res.scalar_one_or_none.return_value = None

    mock_db.execute.side_effect = [target_res, existing_swipe_res, reciprocal_res]
    app.dependency_overrides[get_db] = lambda: mock_db

    payload = {
        "target_user_id": str(mock_candidate_user.id),
        "swipe_type": "direct_dm",
    }
    response = client.post("/api/v1/feed/swipe", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["is_match"] is False
    assert data["remaining_dm_tokens"] == 2
    assert mock_current_user.reward_balance == 2

    app.dependency_overrides.clear()


def test_reset_my_swipes(mock_current_user):
    """Verifies that POST /api/v1/feed/reset-my-swipes clears swipes and returns 200."""
    app.dependency_overrides[get_current_user] = lambda: mock_current_user

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.rowcount = 4
    mock_db.execute.return_value = mock_result
    app.dependency_overrides[get_db] = lambda: mock_db

    response = client.post("/api/v1/feed/reset-my-swipes")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "Successfully reset 4 swipes" in data["message"]
    assert data["actor_id"] == str(mock_current_user.id)
    assert mock_db.commit.called

    app.dependency_overrides.clear()
