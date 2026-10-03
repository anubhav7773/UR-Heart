import pytest
import uuid
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.swipe import Swipe

client = TestClient(app)


def test_get_seeker_profile_success():
    """Verify that GET /api/v1/profile/{user_id} returns live profile with resonance & photos."""
    viewer_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    target_id = uuid.UUID("22222222-2222-2222-2222-222222222222")

    current_user = User(
        id=viewer_id,
        email="viewer@urheart.app",
        full_name="Aarav Sharma",
        gender="male",
        dob=date(1998, 5, 20),
        bio="Mindful presence.",
        location_name="Saket, Ayodhya",
        latitude=26.79,
        longitude=82.20
    )

    target_user = User(
        id=target_id,
        email="target@urheart.app",
        full_name="Sakshi Verma",
        gender="female",
        dob=date(2000, 3, 15),
        bio="Architecture student passionate about contemplative design.",
        profession="Architect",
        education="B.Arch, IIT Roorkee",
        location_name="Rambabu Lane, Ayodhya",
        latitude=26.80,
        longitude=82.21,
        kyc_status=True,
        streak_count=5,
        photos=["https://urheart.app/media/sakshi1.webp", "https://urheart.app/media/sakshi2.webp"],
        avatar_url="https://urheart.app/media/sakshi_avatar.webp"
    )

    mock_db = AsyncMock()

    def execute_side_effect(stmt):
        stmt_str = str(stmt).lower()
        mock_res = MagicMock()
        if "from public.users" in stmt_str or "users" in stmt_str:
            mock_res.scalar_one_or_none.return_value = target_user
        else:
            mock_res.scalar_one_or_none.return_value = None
        mock_res.scalars.return_value.all.return_value = []
        return mock_res

    mock_db.execute = AsyncMock(side_effect=execute_side_effect)

    app.dependency_overrides[get_current_user] = lambda: current_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get(f"/api/v1/profile/{target_id}")
        assert res.status_code == 200
        data = res.json()
        assert data["id"] == str(target_id)
        assert data["full_name"] == "Sakshi Verma"
        assert data["age"] >= 24
        assert data["is_kyc_verified"] is True
        assert data["profession"] == "Architect"
        assert "photos" in data
        assert len(data["photos"]) >= 2
        assert "resonance_score" in data
        assert data["resonance_score"] >= 60
        assert "interests" in data
        assert isinstance(data["interests"], list)
    finally:
        app.dependency_overrides.clear()


def test_get_seeker_profile_invalid_uuid():
    """Verify that an invalid UUID string yields a 400 bad request."""
    current_user = User(id=uuid.uuid4(), email="test@urheart.app", full_name="Tester")
    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: current_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/profile/invalid-not-a-uuid")
        assert res.status_code == 400
        assert "Invalid user ID format" in res.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_get_passed_profiles_pass_vault():
    """Verify that GET /api/v1/swipes/passed returns the candidate list from PostgreSQL."""
    viewer_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    target_id = uuid.UUID("33333333-3333-3333-3333-333333333333")

    current_user = User(
        id=viewer_id,
        email="viewer@urheart.app",
        full_name="Aarav Sharma",
        gender="male",
        dob=date(1998, 5, 20)
    )

    passed_user = User(
        id=target_id,
        email="passed@urheart.app",
        full_name="Ananya Roy",
        gender="female",
        dob=date(1999, 8, 12),
        bio="Writer and slow living enthusiast.",
        profession="Author",
        location_name="Civil Lines, Ayodhya",
        kyc_status=True,
        avatar_url="https://urheart.app/media/ananya.webp"
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.all.return_value = [(passed_user, datetime.now(timezone.utc))]
    mock_db.execute = AsyncMock(return_value=mock_res)

    app.dependency_overrides[get_current_user] = lambda: current_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/swipes/passed")
        assert res.status_code == 200
        payload = res.json()
        assert "passed_candidates" in payload
        assert len(payload["passed_candidates"]) == 1
        cand = payload["passed_candidates"][0]
        assert cand["id"] == str(target_id)
        assert cand["full_name"] == "Ananya Roy"
        assert cand["is_kyc_verified"] is True
        assert "resonance_score" in cand
        assert "avatar_url" in cand
    finally:
        app.dependency_overrides.clear()


def test_restore_passed_profile_endpoint():
    """Verify DELETE /api/v1/swipes/pass/{target_id} properly handles un-passing a seeker."""
    viewer_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    target_id = uuid.UUID("33333333-3333-3333-3333-333333333333")

    current_user = User(id=viewer_id, email="viewer@urheart.app", full_name="Aarav Sharma")
    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_current_user_optional] = lambda: current_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.delete(f"/api/v1/swipes/pass/{target_id}")
        assert res.status_code == 200
        assert res.json()["status"] == "revisited"
    finally:
        app.dependency_overrides.clear()
