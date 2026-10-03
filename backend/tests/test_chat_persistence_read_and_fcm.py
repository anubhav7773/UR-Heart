import pytest
import uuid
from datetime import datetime
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import get_current_user
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.message import Message

client = TestClient(app)


def test_message_model_has_client_id():
    """Verify that Message domain model contains client_id column."""
    assert hasattr(Message, "client_id")
    msg = Message(
        match_id=uuid.uuid4(),
        sender_id=uuid.uuid4(),
        encrypted_text="test",
        status="delivered",
        client_id="client-msg-uuid-12345"
    )
    assert msg.client_id == "client-msg-uuid-12345"
    assert msg.status == "delivered"


def test_user_model_has_fcm_token():
    """Verify that User domain model contains fcm_token column."""
    assert hasattr(User, "fcm_token")
    u = User(
        email="test@example.com",
        fcm_token="sample_device_fcm_token_123456789"
    )
    assert u.fcm_token == "sample_device_fcm_token_123456789"


@pytest.mark.asyncio
async def test_send_chat_message_with_client_id():
    """Verify send_chat_message saves message with client_id and auto-increment identity."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()
    client_msg_id = str(uuid.uuid4())

    mock_user = User(
        id=user1_id,
        email="user1@example.com",
        full_name="Seeker One"
    )
    mock_match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True
    )

    mock_db = AsyncMock()

    # scalar_one_or_none returns:
    # 1. match lookup: mock_match
    # 2. block check: None
    # 3. deduplication check: None
    mock_db.execute.side_effect = [
        MagicMock(scalar_one_or_none=MagicMock(return_value=mock_match)),
        MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
        MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
    ]

    async def mock_refresh(instance):
        instance.id = 42
        instance.created_at = datetime.utcnow()

    mock_db.refresh = mock_refresh

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch("app.services.chat_manager.manager.send_direct_message", new_callable=AsyncMock):
            with patch("app.api.v1.endpoints.notifications.push_notification"):
                response = client.post(
                    f"/api/v1/chat/threads/{match_id}/messages",
                    json={
                        "match_id": str(match_id),
                        "text": "Hello mindful companion",
                        "client_id": client_msg_id,
                        "id": client_msg_id
                    }
                )

                assert response.status_code == 201
                data = response.json()
                assert data["status"] == "sent"
                assert data["id"] == "42"
                assert data["client_id"] == client_msg_id
                assert data["text"] == "Hello mindful companion"

                # Verify Message was added to db with client_id and NOT with id=UUID
                added_msgs = [call.args[0] for call in mock_db.add.call_args_list if isinstance(call.args[0], Message)]
                assert len(added_msgs) == 1
                saved_msg = added_msgs[0]
                assert saved_msg.client_id == client_msg_id
                # The Message constructor must NOT have been passed an explicit id override
                assert saved_msg.match_id == match_id
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_mark_thread_messages_as_read():
    """Verify POST /threads/{match_id}/read marks partner messages as read."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()

    mock_user = User(
        id=user1_id,
        email="user1@example.com",
        full_name="Reader User"
    )
    mock_match = Match(
        id=match_id,
        user1_id=user2_id,
        user2_id=user1_id,
        is_active=True
    )

    mock_db = AsyncMock()
    mock_update_result = MagicMock(rowcount=3)
    mock_db.execute.side_effect = [
        mock_update_result,
        MagicMock(scalar_one_or_none=MagicMock(return_value=mock_match))
    ]

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch("app.services.chat_manager.manager.send_direct_message", new_callable=AsyncMock) as mock_ws:
            response = client.post(f"/api/v1/chat/threads/{match_id}/read")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert data["updated_count"] == 3

            # Verify WebSocket read receipt was dispatched to partner (user2_id)
            mock_ws.assert_called_once()
            args = mock_ws.call_args[0]
            assert args[0] == str(user2_id)
            assert args[1]["type"] == "read_receipt"
            assert args[1]["status"] == "read"
    finally:
        app.dependency_overrides.clear()


def test_register_fcm_token_endpoint():
    """Verify POST /api/v1/notifications/register-token updates user fcm_token."""
    user_id = uuid.uuid4()
    mock_user = User(
        id=user_id,
        email="user@example.com",
        fcm_token=None
    )

    mock_db = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        test_token = "fcm_device_token_abc123_xyz"
        response = client.post(
            "/api/v1/notifications/register-token",
            json={"fcm_token": test_token}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert mock_user.fcm_token == test_token
    finally:
        app.dependency_overrides.clear()
