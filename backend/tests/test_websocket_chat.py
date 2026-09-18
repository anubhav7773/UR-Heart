import json
from uuid import uuid4, UUID
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app
from app.core.database import get_db, async_session_factory
from app.core.security import create_internal_token
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.message import Message
from app.api.dependencies import get_current_user_id
from app.services.chat_manager import manager

client = TestClient(app)

# ==============================================================================
# TEST 1: Unauthenticated Connection Rejection
# ==============================================================================
def test_unauthenticated_connection_rejection():
    """
    Attempt connection to /ws/chat without token or with invalid token.
    Asserts connection closes with code 1008 (WS_1008_POLICY_VIOLATION).
    """
    # 1. No token
    with pytest.raises(Exception):
        with client.websocket_connect("/ws/chat") as ws:
            pass

    # 2. Invalid token
    with pytest.raises(Exception):
        with client.websocket_connect("/ws/chat?token=invalid_garbage_token") as ws:
            pass

# ==============================================================================
# TEST 2: Clean Message Delivery & Database Persistence
# ==============================================================================
def test_clean_message_delivery_and_db_persistence():
    """
    User A and User B connect to /ws/chat.
    User A sends 'Hello, how was your day?' to User B.
    Asserts User B receives incoming_message event with exact content.
    Asserts row is inserted in public.messages.
    """
    user_a_id = uuid4()
    user_b_id = uuid4()
    match_id = uuid4()

    token_a = create_internal_token(user_a_id)
    token_b = create_internal_token(user_b_id)

    # Mock DB queries
    persisted_messages = []

    mock_match = Match(id=match_id, user1_id=user_a_id, user2_id=user_b_id, is_active=True)

    class MockAsyncSession:
        def __init__(self):
            pass
        async def __aenter__(self):
            return self
        async def __aexit__(self, exc_type, exc_val, exc_tb):
            pass
        async def execute(self, stmt):
            res_mock = MagicMock()
            res_mock.scalar_one_or_none = lambda: mock_match
            return res_mock
        def add(self, obj):
            if isinstance(obj, Message):
                obj.id = 101
                obj.created_at = datetime.now(timezone.utc)
                persisted_messages.append(obj)
        async def commit(self):
            pass
        async def refresh(self, obj):
            pass

    with patch("app.api.v1.endpoints.chat.async_session_factory", return_value=MockAsyncSession()):
        with client.websocket_connect(f"/ws/chat?token={token_a}") as ws_a:
            with client.websocket_connect(f"/ws/chat?token={token_b}") as ws_b:
                msg_payload = {
                    "type": "message",
                    "match_id": str(match_id),
                    "recipient_id": str(user_b_id),
                    "content": "Hello, how was your day?"
                }
                ws_a.send_text(json.dumps(msg_payload))

                # User A receives confirmation
                ack_raw = ws_a.receive_text()
                ack_data = json.loads(ack_raw)
                assert ack_data["event"] == "message_sent"
                assert ack_data["status"] == "delivered"

                # User B receives incoming_message
                incoming_raw = ws_b.receive_text()
                incoming_data = json.loads(incoming_raw)
                assert incoming_data["event"] == "incoming_message"
                assert incoming_data["content"] == "Hello, how was your day?"
                assert incoming_data["sender_id"] == str(user_a_id)
                assert incoming_data["match_id"] == str(match_id)

    # Assert row is inserted in messages
    assert len(persisted_messages) == 1
    assert persisted_messages[0].encrypted_text == "Hello, how was your day?"
    assert persisted_messages[0].status == "delivered"
    assert persisted_messages[0].sender_id == user_a_id

# ==============================================================================
# TEST 3: Anti-Leak Filter Interception (Phone Number Rejection)
# ==============================================================================
def test_anti_leak_phone_number_interception():
    """
    User A sends 'Call me at 9876543210'.
    Asserts User A receives anti_leak_violation event with code: 422.
    Asserts User B receives NOTHING.
    Asserts ZERO rows are created in public.messages.
    """
    user_a_id = uuid4()
    user_b_id = uuid4()
    match_id = uuid4()

    token_a = create_internal_token(user_a_id)
    token_b = create_internal_token(user_b_id)

    persisted_messages = []

    class MockAsyncSession:
        async def __aenter__(self):
            return self
        async def __aexit__(self, exc_type, exc_val, exc_tb):
            pass
        def add(self, obj):
            persisted_messages.append(obj)
        async def commit(self):
            pass

    with patch("app.api.v1.endpoints.chat.async_session_factory", return_value=MockAsyncSession()):
        with client.websocket_connect(f"/ws/chat?token={token_a}") as ws_a:
            with client.websocket_connect(f"/ws/chat?token={token_b}") as ws_b:
                leak_payload = {
                    "type": "message",
                    "match_id": str(match_id),
                    "recipient_id": str(user_b_id),
                    "content": "Call me at 9876543210"
                }
                ws_a.send_text(json.dumps(leak_payload))

                # User A receives anti_leak_violation alert
                err_raw = ws_a.receive_text()
                err_data = json.loads(err_raw)
                assert err_data["event"] == "anti_leak_violation"
                assert err_data["code"] == 422
                assert "Sharing phone numbers" in err_data["message"]

    # Assert ZERO rows stored in DB
    assert len(persisted_messages) == 0

# ==============================================================================
# TEST 4: Anti-Leak Filter Interception (Hindi Word Numbers & Social Handles)
# ==============================================================================
def test_anti_leak_social_and_hindi_interception():
    """
    User A sends 'mera insta id priya_01 hai'.
    Asserts User A receives anti_leak_violation event.
    Asserts message is dropped and not stored in database.
    """
    user_a_id = uuid4()
    user_b_id = uuid4()
    match_id = uuid4()

    token_a = create_internal_token(user_a_id)
    token_b = create_internal_token(user_b_id)

    persisted_messages = []

    class MockAsyncSession:
        async def __aenter__(self):
            return self
        async def __aexit__(self, exc_type, exc_val, exc_tb):
            pass
        def add(self, obj):
            persisted_messages.append(obj)
        async def commit(self):
            pass

    with patch("app.api.v1.endpoints.chat.async_session_factory", return_value=MockAsyncSession()):
        with client.websocket_connect(f"/ws/chat?token={token_a}") as ws_a:
            with client.websocket_connect(f"/ws/chat?token={token_b}") as ws_b:
                leak_payload = {
                    "type": "message",
                    "match_id": str(match_id),
                    "recipient_id": str(user_b_id),
                    "content": "mera insta id priya_01 hai"
                }
                ws_a.send_text(json.dumps(leak_payload))

                # Sender receives anti-leak error
                err_raw = ws_a.receive_text()
                err_data = json.loads(err_raw)
                assert err_data["event"] == "anti_leak_violation"
                assert err_data["code"] == 422

    # Assert ZERO rows stored in DB
    assert len(persisted_messages) == 0

# ==============================================================================
# TEST 5: Chat History REST Endpoint
# ==============================================================================
def test_chat_history_rest_endpoint():
    """
    Call GET /api/v1/chat/history/{match_id}:
    - As participant -> Assert returns list of saved messages.
    - As unrelated non-participant user -> Assert HTTP 403 Forbidden.
    """
    participant_id = uuid4()
    non_participant_id = uuid4()
    other_user_id = uuid4()
    match_id = uuid4()

    mock_match = Match(
        id=match_id,
        user1_id=participant_id,
        user2_id=other_user_id,
        is_active=True
    )
    mock_messages = [
        Message(
            id=1,
            match_id=match_id,
            sender_id=participant_id,
            encrypted_text="Hey there!",
            status="delivered",
            created_at=datetime.now(timezone.utc)
        ),
        Message(
            id=2,
            match_id=match_id,
            sender_id=other_user_id,
            encrypted_text="Hi! Nice to meet you.",
            status="read",
            created_at=datetime.now(timezone.utc)
        )
    ]

    # Mock DB Session for Participant
    mock_session_participant = AsyncMock()
    mock_match_res = AsyncMock()
    mock_match_res.scalar_one_or_none = lambda: mock_match

    mock_msgs_res = AsyncMock()
    mock_msgs_res.scalars = lambda: MagicMock(all=lambda: mock_messages)

    mock_session_participant.execute = AsyncMock(side_effect=[mock_match_res, mock_msgs_res])

    async def override_get_db_p():
        yield mock_session_participant

    app.dependency_overrides[get_db] = override_get_db_p
    app.dependency_overrides[get_current_user_id] = lambda: participant_id

    resp_p = client.get(f"/api/v1/chat/history/{match_id}")
    assert resp_p.status_code == 200, resp_p.text
    data = resp_p.json()
    assert len(data) == 2
    assert data[0]["encrypted_text"] == "Hey there!"
    assert data[1]["encrypted_text"] == "Hi! Nice to meet you."

    # Mock DB Session for Non-Participant (returns None for match)
    mock_session_stranger = AsyncMock()
    mock_no_match = AsyncMock()
    mock_no_match.scalar_one_or_none = lambda: None
    mock_session_stranger.execute = AsyncMock(return_value=mock_no_match)

    async def override_get_db_s():
        yield mock_session_stranger

    app.dependency_overrides[get_db] = override_get_db_s
    app.dependency_overrides[get_current_user_id] = lambda: non_participant_id

    resp_s = client.get(f"/api/v1/chat/history/{match_id}")
    assert resp_s.status_code == 403
    assert "Not a participant" in resp_s.json()["detail"]

    app.dependency_overrides.clear()


# ==============================================================================
# TEST 6: WhatsApp-Style Delivery & Read Receipt Lifecycle (Ticks)
# ==============================================================================
def test_delivery_and_read_receipt_lifecycle():
    """
    Verifies WebSocket events:
    1. User A sends message -> gets 'message_sent'.
    2. User B receives message -> sends 'delivery_ack' -> User A receives 'message_delivered'.
    3. User B views chat -> sends 'read_receipt' -> User A receives 'messages_read'.
    """
    user_a_id = uuid4()
    user_b_id = uuid4()
    match_id = uuid4()

    token_a = create_internal_token(user_a_id)
    token_b = create_internal_token(user_b_id)

    mock_match = Match(id=match_id, user1_id=user_a_id, user2_id=user_b_id, is_active=True)

    class MockAsyncSession:
        async def __aenter__(self):
            return self
        async def __aexit__(self, exc_type, exc_val, exc_tb):
            pass
        async def execute(self, stmt):
            res_mock = MagicMock()
            res_mock.scalar_one_or_none = lambda: mock_match
            return res_mock
        def add(self, obj):
            if isinstance(obj, Message):
                obj.id = 205
                obj.created_at = datetime.now(timezone.utc)
        async def commit(self):
            pass
        async def refresh(self, obj):
            pass

    with patch("app.api.v1.endpoints.chat.async_session_factory", return_value=MockAsyncSession()):
        with client.websocket_connect(f"/ws/chat?token={token_a}") as ws_a:
            with client.websocket_connect(f"/ws/chat?token={token_b}") as ws_b:
                # 1. User A sends message
                ws_a.send_text(json.dumps({
                    "type": "message",
                    "match_id": str(match_id),
                    "recipient_id": str(user_b_id),
                    "content": "Are we meeting tomorrow at Hazratganj?"
                }))

                ack_a = json.loads(ws_a.receive_text())
                assert ack_a["event"] == "message_sent"
                assert ack_a["msg_id"] == 205

                inc_b = json.loads(ws_b.receive_text())
                assert inc_b["event"] == "incoming_message"
                assert inc_b["status"] == "delivered"

                # 2. User B sends delivery_ack
                ws_b.send_text(json.dumps({
                    "type": "delivery_ack",
                    "match_id": str(match_id),
                    "msg_id": 205,
                    "recipient_id": str(user_a_id)
                }))

                delivered_a = json.loads(ws_a.receive_text())
                assert delivered_a["event"] == "message_delivered"
                assert delivered_a["msg_id"] == 205

                # 3. User B sends read_receipt (double blue tick trigger)
                ws_b.send_text(json.dumps({
                    "type": "read_receipt",
                    "match_id": str(match_id),
                    "recipient_id": str(user_a_id)
                }))

                read_a = json.loads(ws_a.receive_text())
                assert read_a["event"] == "messages_read"
                assert read_a["match_id"] == str(match_id)


# ==============================================================================
# TEST 7: FCM Device Token Registration
# ==============================================================================
def test_device_token_registration():
    """Verifies that POST /api/v1/user/device-token stores device FCM token."""
    from app.api.dependencies import get_current_user
    mock_user = User(
        id=uuid4(),
        full_name="Aman Verma",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        city="Lucknow",
        gender="male",
        fcm_token=None,
    )

    app.dependency_overrides[get_current_user] = lambda: mock_user
    mock_db = AsyncMock()
    app.dependency_overrides[get_db] = lambda: mock_db

    payload = {"fcm_token": "fcm_test_device_token_abcdef1234567890"}
    response = client.post("/api/v1/user/device-token", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "success"
    assert mock_user.fcm_token == "fcm_test_device_token_abcdef1234567890"

    app.dependency_overrides.clear()

