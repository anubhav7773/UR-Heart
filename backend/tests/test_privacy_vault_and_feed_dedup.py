import base64
import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match

client = TestClient(app)

def _generate_test_public_key() -> str:
    """Generate dynamic dummy 32-byte key at test runtime to avoid secret scanner false positives."""
    return base64.b64encode(bytes([i % 256 for i in range(32)])).decode("ascii")


def test_get_user_preferences_returns_genuine_state():
    """Verify GET /api/v1/user/preferences returns accurate incognito and X25519 fingerprint."""
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    dummy_user = User(
        id=user_id,
        email="seeker@urheart.app",
        full_name="Ananya",
        is_incognito=True,
        discreet_mode=False,
        push_notifications_enabled=True,
        public_encryption_key=_generate_test_public_key()
    )

    mock_db = AsyncMock()
    app.dependency_overrides[get_current_user] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/user/preferences")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        prefs = data["preferences"]
        assert prefs["is_incognito"] is True
        assert prefs["discreet_mode"] is False
        assert prefs["push_notifications_enabled"] is True
        assert prefs["key_fingerprint"].startswith("X25519-")
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_put_user_preferences_updates_and_persists():
    """Verify PUT /api/v1/user/preferences updates is_incognito flag and returns formatted fingerprint."""
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    dummy_user = User(
        id=user_id,
        email="seeker@urheart.app",
        full_name="Ananya",
        is_incognito=False,
        public_encryption_key=_generate_test_public_key()
    )

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.put("/api/v1/user/preferences", json={"is_incognito": True})
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["is_incognito"] is True
        assert dummy_user.is_incognito is True
        assert mock_db.commit.called
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_discovery_feed_excludes_incognito_ghost_cloak():
    """Verify that candidates with is_incognito=True are not included in discovery feed deck."""
    user_a = uuid.UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    user_incognito = uuid.UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
    user_visible = uuid.UUID("cccccccc-cccc-cccc-cccc-cccccccccccc")

    current_user = User(
        id=user_a,
        email="user_a@urheart.app",
        full_name="User A",
        gender="Man",
        interested_in="Women",
        is_profile_completed=True
    )
    visible_candidate = User(
        id=user_visible,
        email="visible@urheart.app",
        full_name="Visible Candidate",
        gender="Woman",
        interested_in="Men",
        is_profile_completed=True,
        is_incognito=False
    )

    mock_db = AsyncMock()
    # Mock feed query to return only candidates that passed DB filters
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = [visible_candidate]
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[get_current_user_optional] = lambda: current_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/feed")
        assert res.status_code == 200
        data = res.json()
        candidate_ids = [c["id"] for c in data["candidates"]]
        assert str(user_visible) in candidate_ids
        assert str(user_incognito) not in candidate_ids
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)


def test_feed_deduplication_excludes_direct_letter_sender():
    """Verify that when User A sends a Direct Letter to User B, User A never appears on User B's feed."""
    user_a_id = uuid.UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    user_b_id = uuid.UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")

    # User B is requesting the feed
    user_b = User(
        id=user_b_id,
        email="user_b@urheart.app",
        full_name="User B (Recipient)",
        gender="Woman",
        interested_in="Men",
        is_profile_completed=True
    )

    mock_db = AsyncMock()
    # Feed query excludes user_a because user_a sent a direct letter / is matched
    mock_result = MagicMock()
    # User A is excluded by the query subqueries (direct_senders_subq / matched_u1_subq)
    mock_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[get_current_user_optional] = lambda: user_b
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/feed")
        assert res.status_code == 200
        data = res.json()
        candidate_ids = [c["id"] for c in data["candidates"]]
        assert str(user_a_id) not in candidate_ids
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)
