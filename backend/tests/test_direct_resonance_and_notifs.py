import pytest
import uuid
from datetime import datetime, date
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.swipe import Swipe
from app.models.domain.match import Match
from app.models.domain.message import Message

from app.api.v1.endpoints.chat_api import (
    _clean_match_uuid,
    encrypt_message_storage,
    decrypt_message_storage,
)
from app.api.v1.endpoints.notifications import (
    NOTIFICATION_STORE,
    push_notification,
    mark_notifications_read,
    MarkReadRequest,
)

client = TestClient(app)


def test_clean_match_uuid_prefixes():
    """Verify that _clean_match_uuid handles match-, conn_, spark_, and raw UUIDs."""
    test_uuid = uuid.uuid4()
    
    assert _clean_match_uuid(str(test_uuid)) == test_uuid
    assert _clean_match_uuid(f"match-{test_uuid}") == test_uuid
    assert _clean_match_uuid(f"conn_{test_uuid}") == test_uuid
    assert _clean_match_uuid(f"spark_{test_uuid}") == test_uuid
    assert _clean_match_uuid(f"match_{test_uuid}") == test_uuid


def test_encryption_decryption_with_prefixes():
    """Verify that encryption and decryption derive identical key material across prefix formats."""
    raw_uuid = str(uuid.uuid4())
    plain_text = "Hello intentional friend. This is a direct sacred letter."

    # Encrypt with clean UUID
    cipher1 = encrypt_message_storage(plain_text, raw_uuid)
    assert cipher1.startswith("enc_v1:")

    # Decrypt with conn_ prefixed ID
    decrypted_conn = decrypt_message_storage(cipher1, f"conn_{raw_uuid}")
    assert decrypted_conn == plain_text

    # Decrypt with match- prefixed ID
    decrypted_match = decrypt_message_storage(cipher1, f"match-{raw_uuid}")
    assert decrypted_match == plain_text


@pytest.mark.asyncio
async def test_notification_mark_read_and_deduplication():
    """Verify that mark-read marks notification as is_read: True and updates unread count."""
    user_id = str(uuid.uuid4())
    
    # Push two notifications
    push_notification(user_id, "message", "Test Message 1", "Hello")
    push_notification(user_id, "direct_letter", "Direct Letter", "Letter text")
    
    items = NOTIFICATION_STORE[user_id]
    assert len(items) == 2
    assert all(not n["is_read"] for n in items)

    mock_user = MagicMock()
    mock_user.id = uuid.UUID(user_id)
    mock_db = AsyncMock()

    # Mark first notification as read
    target_id = items[0]["id"]
    res = await mark_notifications_read(MarkReadRequest(notification_id=target_id), current_user=mock_user, db=mock_db)
    
    assert res["status"] == "success"
    assert res["unread_count"] == 1
    assert items[0]["is_read"] is True
    assert items[1]["is_read"] is False

    # Mark all read
    res_all = await mark_notifications_read(MarkReadRequest(), current_user=mock_user, db=mock_db)
    assert res_all["unread_count"] == 0
    assert all(n["is_read"] for n in items)

    # Cleanup store
    NOTIFICATION_STORE.pop(user_id, None)


def test_resonances_and_threads_peer_endpoints():
    """Verify that /chat/threads/{id}/peer alias exists and returns peer data."""
    my_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    peer_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    match_id = uuid.UUID("33333333-3333-3333-3333-333333333333")

    current_user = User(
        id=my_id,
        email="me@urheart.app",
        full_name="Anubhav Seeker",
    )
    peer_user = User(
        id=peer_id,
        email="peer@urheart.app",
        full_name="Meera Sen",
        avatar_url="https://urheart.app/media/meera.webp",
        bio="Mindful architecture",
    )
    match_record = Match(
        id=match_id,
        user1_id=my_id,
        user2_id=peer_id,
        is_active=True,
    )

    mock_db = AsyncMock()

    def execute_side_effect(stmt):
        stmt_str = str(stmt)
        res = MagicMock()
        if "matches" in stmt_str:
            res.scalar_one_or_none.return_value = match_record
        elif "users" in stmt_str:
            res.scalar_one_or_none.return_value = peer_user
        else:
            res.scalar_one_or_none.return_value = None
            res.scalars.return_value.all.return_value = []
            res.all.return_value = []
        return res

    mock_db.execute = AsyncMock(side_effect=execute_side_effect)

    app.dependency_overrides[get_current_user] = lambda: current_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # Test 1: GET /api/v1/chat/threads/{match_id}/peer with conn_ prefix
        res_thread = client.get(f"/api/v1/chat/threads/conn_{match_id}/peer")
        assert res_thread.status_code == 200, res_thread.text
        data = res_thread.json()
        assert data["full_name"] == "Meera Sen"
        assert data["avatar_url"] == "https://urheart.app/media/meera.webp"

        # Test 2: GET /api/v1/chat/matches/{match_id}/peer with match- prefix
        res_match = client.get(f"/api/v1/chat/matches/match-{match_id}/peer")
        assert res_match.status_code == 200, res_match.text
        assert res_match.json()["full_name"] == "Meera Sen"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_fcm_token_registration_and_unregistration():
    """Verify that registering a token disassociates it from prior users and unregister removes it."""
    from app.api.v1.endpoints.notifications import USER_FCM_TOKENS, RegisterTokenRequest, register_device_token, unregister_device_token

    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    test_token = f"fcm_test_token_{uuid.uuid4().hex}"

    mock_user1 = MagicMock()
    mock_user1.id = user1_id
    mock_user2 = MagicMock()
    mock_user2.id = user2_id

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=MagicMock())

    # 1. Register token for user 1
    req1 = RegisterTokenRequest(fcm_token=test_token)
    res1 = await register_device_token(req1, current_user=mock_user1, db=mock_db)
    assert res1["status"] == "success"
    assert USER_FCM_TOKENS.get(str(user1_id)) == test_token

    # 2. Register same token for user 2 -> must be removed from user 1
    req2 = RegisterTokenRequest(fcm_token=test_token)
    res2 = await register_device_token(req2, current_user=mock_user2, db=mock_db)
    assert res2["status"] == "success"
    assert USER_FCM_TOKENS.get(str(user1_id)) is None
    assert USER_FCM_TOKENS.get(str(user2_id)) == test_token

    # 3. Unregister token for user 2
    res_unreg = await unregister_device_token(None, current_user=mock_user2, db=mock_db)
    assert res_unreg["status"] == "success"
    assert USER_FCM_TOKENS.get(str(user2_id)) is None


@pytest.mark.asyncio
async def test_streak_engine_evaluation_logic():
    """Verify StreakEngine.evaluate_all_active_streaks runs without errors."""
    from app.services.streak_engine import StreakEngine
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_res)

    # Should execute smoothly with empty or active streaks
    evaluated = await StreakEngine.evaluate_all_active_streaks(mock_db)
    assert isinstance(evaluated, int)
    assert evaluated >= 0

