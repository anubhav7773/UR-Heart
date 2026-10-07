import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch, MagicMock
import pytest

from app.models.domain.match import Match
from app.models.domain.user import User
from app.services.mindful_closure import MindfulClosureService, MINDFUL_CLOSURE_TEMPLATES


def test_mindful_closure_templates():
    """Verifies that all 4 compassionate closure templates are available with texts and icons."""
    templates = MindfulClosureService.get_templates()
    assert len(templates) == 4
    keys = [t["id"] for t in templates]
    assert "wavelength" in keys
    assert "self_focus" in keys
    assert "different_resonance" in keys
    assert "silent_bow" in keys


@pytest.mark.asyncio
async def test_evaluate_stale_conversations():
    """Matches with >48h of inactivity are identified and marked as stagnant."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    stale_match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True,
        matched_at=now - timedelta(hours=60),
        last_message_at=now - timedelta(hours=50),
        closure_status=None
    )

    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value.all.return_value = [stale_match]
    mock_db.execute.return_value = mock_res

    count = await MindfulClosureService.evaluate_stale_conversations(mock_db)

    assert count == 1
    assert stale_match.closure_status == "stagnant"
    assert mock_db.commit.called


@pytest.mark.asyncio
async def test_send_mindful_closure_success():
    """Sending a mindful closure updates status to closed_with_grace, logs message, and notifies partner."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True,
        matched_at=now - timedelta(hours=24),
        last_message_at=now - timedelta(hours=10),
        closure_status="stagnant"
    )

    user1 = User(
        id=user1_id,
        full_name="Ananya Sharma"
    )

    mock_db = AsyncMock()

    async def fake_execute(stmt):
        mock_r = MagicMock()
        # Check if querying Match or User
        stmt_str = str(stmt).lower()
        if "from public.matches" in stmt_str or "matches" in stmt_str:
            mock_r.scalar_one_or_none.return_value = match
        else:
            mock_r.scalar_one_or_none.return_value = user1
        return mock_r

    mock_db.execute.side_effect = fake_execute

    with patch("app.services.mindful_closure.push_notification") as mock_push, \
         patch("app.services.chat_manager.manager.send_direct_message", new_callable=AsyncMock) as mock_wss:

        res = await MindfulClosureService.send_mindful_closure(
            db=mock_db,
            match_id=match_id,
            user_id=user1_id,
            template_key="wavelength"
        )

        assert res["status"] == "closed_with_grace"
        assert match.closure_status == "closed_with_grace"
        assert match.closed_by_user_id == user1_id
        assert match.closure_template_key == "wavelength"
        assert "wavelengths" in match.closure_note
        assert mock_db.commit.called
        assert mock_push.called
        assert mock_wss.called


@pytest.mark.asyncio
async def test_send_mindful_closure_unauthorized():
    """Third party user cannot close someone else's dialogue."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    third_party_id = uuid.uuid4()
    match_id = uuid.uuid4()

    match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True,
        closure_status=None
    )

    mock_db = AsyncMock()
    mock_r = MagicMock()
    mock_r.scalar_one_or_none.return_value = match
    mock_db.execute.return_value = mock_r

    with pytest.raises(ValueError, match="not an authorized participant"):
        await MindfulClosureService.send_mindful_closure(
            db=mock_db,
            match_id=match_id,
            user_id=third_party_id,
            template_key="wavelength"
        )


@pytest.mark.asyncio
async def test_send_mindful_closure_already_closed():
    """Dialogue already closed with grace cannot be closed again."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()

    match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True,
        closure_status="closed_with_grace"
    )

    mock_db = AsyncMock()
    mock_r = MagicMock()
    mock_r.scalar_one_or_none.return_value = match
    mock_db.execute.return_value = mock_r

    with pytest.raises(ValueError, match="already been concluded"):
        await MindfulClosureService.send_mindful_closure(
            db=mock_db,
            match_id=match_id,
            user_id=user1_id,
            template_key="wavelength"
        )


@pytest.mark.asyncio
async def test_get_closure_status():
    """Checks closure status calculations for stagnant and closed threads."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True,
        matched_at=now - timedelta(hours=55),
        last_message_at=now - timedelta(hours=50),
        closure_status="stagnant"
    )

    mock_db = AsyncMock()
    mock_r = MagicMock()
    mock_r.scalar_one_or_none.return_value = match
    mock_db.execute.return_value = mock_r

    res = await MindfulClosureService.get_closure_status(mock_db, match_id, user1_id)
    assert res["is_stagnant"] is True
    assert res["is_closed"] is False
    assert res["hours_since_last_message"] >= 49.0
    assert len(res["templates"]) == 4


def test_mindful_closure_template_contract_symmetry():
    """Ensures each template has both id/key and text/message for 100% frontend resilience."""
    templates = MindfulClosureService.get_templates()
    for t in templates:
        assert "id" in t and "key" in t
        assert t["id"] == t["key"]
        assert "text" in t and "message" in t
        assert t["text"] == t["message"]
        assert len(t["key"]) > 0
        assert len(t["message"]) > 0


@pytest.mark.asyncio
async def test_send_mindful_closure_payload_symmetry():
    """Ensures WSS event and FCM push contain all alias keys expected by Flutter client."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    match_id = uuid.uuid4()

    match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True,
        closure_status="stagnant"
    )

    user1 = User(id=user1_id, full_name="Aarav Sen")
    mock_db = AsyncMock()

    async def fake_execute(stmt):
        mock_r = MagicMock()
        stmt_str = str(stmt).lower()
        if "from public.matches" in stmt_str or "matches" in stmt_str:
            mock_r.scalar_one_or_none.return_value = match
        else:
            mock_r.scalar_one_or_none.return_value = user1
        return mock_r

    mock_db.execute.side_effect = fake_execute

    with patch("app.services.mindful_closure.push_notification") as mock_push, \
         patch("app.services.chat_manager.manager.send_direct_message", new_callable=AsyncMock) as mock_wss:

        res = await MindfulClosureService.send_mindful_closure(
            db=mock_db,
            match_id=match_id,
            user_id=user1_id,
            template_key="wavelength"
        )

        assert res["status"] == "closed_with_grace"

        # Verify WebSocket payload has both key variants
        wss_call_args = mock_wss.call_args[0][1]
        assert wss_call_args["closed_by"] == str(user1_id)
        assert wss_call_args["closed_by_user_id"] == str(user1_id)
        assert "closure_note" in wss_call_args
        assert "note" in wss_call_args
        assert "farewell_note" in wss_call_args

        # Verify FCM Push has route
        push_call_kwargs = mock_push.call_args[1]
        assert push_call_kwargs["data"]["route"] == "/chat-dialogue"

