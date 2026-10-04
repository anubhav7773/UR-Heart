import asyncio
import pytest
import uuid
from unittest.mock import patch, MagicMock, AsyncMock

from app.api.v1.endpoints.notifications import (
    NOTIFICATION_STORE,
    USER_FCM_TOKENS,
    push_notification,
    build_fcm_message,
    channel_for_type,
    _dispatch_fcm_push,
    _deliver,
    set_main_loop,
    probe_fcm_authorization,
    DIALOGUE_CHANNEL_ID,
    PRESENCE_CHANNEL_ID,
    ANDROID_NOTIFICATION_ICON,
)


def test_channel_routing_by_type():
    """Verify notification channels route correctly based on activity type."""
    assert channel_for_type("message") == DIALOGUE_CHANNEL_ID
    assert channel_for_type("like") == DIALOGUE_CHANNEL_ID
    assert channel_for_type("pass") == DIALOGUE_CHANNEL_ID
    assert channel_for_type("match") == DIALOGUE_CHANNEL_ID
    assert channel_for_type("direct_letter") == DIALOGUE_CHANNEL_ID
    assert channel_for_type("bridge_request") == DIALOGUE_CHANNEL_ID
    
    # Streak & presence alerts must route to presence channel
    assert channel_for_type("streak_expiring") == PRESENCE_CHANNEL_ID
    assert channel_for_type("streak_broken") == PRESENCE_CHANNEL_ID
    assert channel_for_type("streak_claimed") == PRESENCE_CHANNEL_ID


def test_build_fcm_message_structure():
    """Verify build_fcm_message configures high priority, Android settings, and metadata."""
    msg = build_fcm_message(
        fcm_token="sample_token_xyz123",
        title="New Resonance ✨",
        body="Someone resonated with your soul",
        data={"target_route": "/resonances", "actor_id": "123"},
        notif_type="like",
        notif_id="notif_test_456",
    )
    assert msg.token == "sample_token_xyz123"
    assert msg.notification.title == "New Resonance ✨"
    assert msg.notification.body == "Someone resonated with your soul"
    assert msg.data["type"] == "like"
    assert msg.data["notif_id"] == "notif_test_456"
    assert msg.data["target_route"] == "/resonances"
    assert msg.android.priority == "high"
    assert msg.android.notification.channel_id == DIALOGUE_CHANNEL_ID
    assert msg.android.notification.icon == ANDROID_NOTIFICATION_ICON
    assert msg.android.notification.tag == "notif_test_456"


@pytest.mark.asyncio
async def test_push_notification_sync_enqueue_and_delivery():
    """Verify push_notification synchronously enqueues and dispatches delivery."""
    user_id = str(uuid.uuid4())
    NOTIFICATION_STORE[user_id] = []
    USER_FCM_TOKENS[user_id] = "mock_fcm_token_999"

    with patch("app.api.v1.endpoints.notifications._dispatch_fcm_push") as mock_dispatch:
        mock_dispatch.return_value = {"ok": True, "message_id": "msg_mock_123"}
        
        push_notification(
            user_id=user_id,
            notif_type="message",
            title="Mindful Chat 💬",
            body="Hello friend",
            data={"match_id": "m1"},
        )
        
        # Verify synchronously placed in store
        assert len(NOTIFICATION_STORE[user_id]) == 1
        entry = NOTIFICATION_STORE[user_id][0]
        assert entry["type"] == "message"
        assert entry["title"] == "Mindful Chat 💬"
        assert entry["body"] == "Hello friend"
        
        # Wait a tick for async delivery task to execute
        await asyncio.sleep(0.05)
        mock_dispatch.assert_called_once()


@pytest.mark.asyncio
async def test_dead_token_purge():
    """Verify that when FCM reports an unregistered token, it is purged."""
    user_id = str(uuid.uuid4())
    dead_token = "dead_token_abc"
    USER_FCM_TOKENS[user_id] = dead_token

    with patch("app.api.v1.endpoints.notifications._dispatch_fcm_push") as mock_dispatch:
        mock_dispatch.return_value = {"ok": False, "error": "UnregisteredError", "token_invalid": True}
        
        entry = {
            "id": "notif_test_purge",
            "type": "like",
            "title": "Test",
            "body": "Test body",
            "data": {},
        }
        await _deliver(user_id, entry)
        
        # RAM cache should be purged
        assert USER_FCM_TOKENS.get(user_id) is None


def test_probe_fcm_authorization_returns_dict():
    """Verify probe_fcm_authorization returns expected keys without raising uncaught exceptions."""
    res = probe_fcm_authorization()
    assert isinstance(res, dict)
    assert "firebase_credentials" in res
    assert "fcm_authorized" in res
