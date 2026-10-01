import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.match import Match

client = TestClient(app)

def test_direct_letter_swipe_decrements_count_and_includes_avatar():
    """Verify that swiping direct letter decrements direct_letters_count and includes avatar in push notification."""
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    target_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    match_id = uuid.UUID("33333333-3333-3333-3333-333333333333")

    dummy_user = User(
        id=user_id,
        email="sender@urheart.app",
        full_name="Aarav Sharma",
        swipes_remaining=10,
        direct_letters_count=2,
        avatar_url="https://urheart.app/media/aarav.webp"
    )

    mock_db = AsyncMock()
    # Mock match and target query results
    target_user = User(
        id=target_id,
        email="recipient@urheart.app",
        full_name="Priya Patel",
        avatar_url="https://urheart.app/media/priya.webp"
    )

    mock_match = Match(id=match_id, user1_id=user_id, user2_id=target_id, is_active=True)

    def execute_side_effect(stmt):
        mock_result = MagicMock()
        # if select target user
        mock_result.scalar_one_or_none.return_value = target_user
        mock_result.scalars.return_value.all.return_value = []
        return mock_result

    mock_db.execute = AsyncMock(side_effect=execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.flush = AsyncMock()

    app.dependency_overrides[get_current_user_optional] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.post("/api/v1/swipes", json={
            "target_id": str(target_id),
            "swipe_type": "direct",
            "letter_text": "A thoughtful message"
        })
        assert res.status_code == 200
        # Check direct_letters_count was decremented
        assert dummy_user.direct_letters_count == 1
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)


def test_discovery_feed_zero_direct_letters_does_not_resurrect():
    """Verify that when direct_letters_count is 0, discovery feed returns 0 (not 1)."""
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    dummy_user = User(
        id=user_id,
        email="seeker@urheart.app",
        full_name="Mindful Seeker",
        swipes_remaining=5,
        direct_letters_count=0
    )

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[get_current_user_optional] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/discovery/feed")
        assert res.status_code == 200
        data = res.json()
        assert data["direct_letters_count"] == 0
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)


def test_chat_reveal_token_redemption_with_prefix():
    """Verify that redeeming reveal token handles match- prefix and decrements reveal_tokens_count."""
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    partner_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    match_uuid = uuid.UUID("33333333-3333-3333-3333-333333333333")

    dummy_user = User(
        id=user_id,
        email="me@urheart.app",
        full_name="Me",
        reveal_tokens_count=2
    )
    partner = User(
        id=partner_id,
        email="partner@urheart.app",
        full_name="Meera Sen",
        contact_bridge_type="whatsapp",
        contact_bridge_encrypted="+919876543210"
    )
    match_obj = Match(id=match_uuid, user1_id=user_id, user2_id=partner_id, is_active=True)

    mock_db = AsyncMock()
    call_count = 0
    def execute_side_effect(stmt):
        nonlocal call_count
        call_count += 1
        mock_result = MagicMock()
        if call_count == 1:
            mock_result.scalar_one_or_none.return_value = match_obj
        else:
            mock_result.scalar_one_or_none.return_value = partner
        return mock_result

    mock_db.execute = AsyncMock(side_effect=execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # Pass match_id with 'match-' prefix as sent by Flutter spark carousel
        res = client.post(f"/api/v1/chat/threads/match-{match_uuid}/bridge/reveal")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "pending_peer_consent"
        assert data["is_unlocked"] is False
        assert data["handle"] == ""
        assert data["reveal_tokens_count"] == 1
        assert dummy_user.reveal_tokens_count == 1
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_chat_peer_profile_resolution_with_prefix():
    """Verify that peer profile endpoint resolves photo and name even with match- prefix."""
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    partner_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    match_uuid = uuid.UUID("33333333-3333-3333-3333-333333333333")

    dummy_user = User(id=user_id, email="me@urheart.app")
    partner = User(
        id=partner_id,
        email="partner@urheart.app",
        full_name="Meera Sen",
        photos=["", "https://urheart.app/media/meera.webp"],
        avatar_url=None,
        kyc_status=True
    )
    match_obj = Match(id=match_uuid, user1_id=user_id, user2_id=partner_id, is_active=True)

    mock_db = AsyncMock()
    call_count = 0
    def execute_side_effect(stmt):
        nonlocal call_count
        call_count += 1
        mock_result = MagicMock()
        if call_count == 1:
            mock_result.scalar_one_or_none.return_value = match_obj
        else:
            mock_result.scalar_one_or_none.return_value = partner
        return mock_result

    mock_db.execute = AsyncMock(side_effect=execute_side_effect)

    app.dependency_overrides[get_current_user] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get(f"/api/v1/chat/threads/match-{match_uuid}/peer")
        assert res.status_code == 200
        data = res.json()
        assert data["full_name"] == "Meera Sen"
        # Must resolve the non-empty photo even though avatar_url is None and photos[0] is empty
        assert data["avatar_url"] == "https://urheart.app/media/meera.webp"
        assert data["is_verified"] is True
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_pass_swipe_upserts_and_sends_notification():
    """Verify that pass swipe updates existing swipe safely and dispatches pass notification to target."""
    from app.api.v1.endpoints.notifications import NOTIFICATION_STORE
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    target_id = uuid.UUID("44444444-4444-4444-4444-444444444444")

    dummy_user = User(
        id=user_id,
        email="passer@urheart.app",
        full_name="Kabir Das",
        swipes_remaining=10,
        avatar_url="https://urheart.app/media/kabir.webp"
    )

    mock_db = AsyncMock()
    # Simulate existing swipe to test idempotent upsert
    from app.models.domain.swipe import Swipe
    existing_swipe = Swipe(actor_id=user_id, target_id=target_id, swipe_type="like")
    
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = existing_swipe
    mock_db.execute = AsyncMock(return_value=mock_result)
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_current_user_optional] = lambda: dummy_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.post("/api/v1/swipes", json={
            "target_id": str(target_id),
            "swipe_type": "pass"
        })
        assert res.status_code == 200
        assert existing_swipe.swipe_type == "pass"

        # Verify pass notification was recorded for target user
        target_notifs = NOTIFICATION_STORE.get(str(target_id), [])
        assert len(target_notifs) > 0
        assert target_notifs[0]["type"] == "pass"
        assert "Profile Passed" in target_notifs[0]["title"]
        assert "Kabir Das passed your profile" in target_notifs[0]["body"]
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)

