import uuid
from datetime import date, datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch
import pytest

from app.models.domain.blind_date import BlindDateSession
from app.models.domain.user import User
from app.services.blind_date_matcher import BlindDateMatcherService


def test_check_eligibility_streak_active_not_used_today():
    """Seeker with active daily streak and unused today gets 1 free pass."""
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        streak_count=5,
        streak_expires_at=now + timedelta(hours=12),
        last_blind_date_date=date.today() - timedelta(days=1),
        blind_date_passes=0,
    )

    eligibility = BlindDateMatcherService.check_eligibility(user)
    assert eligibility["can_enter"] is True
    assert eligibility["has_daily_streak_pass"] is True
    assert eligibility["is_streak_active"] is True
    assert eligibility["reason"] == "ready"


def test_check_eligibility_streak_inactive_no_passes():
    """Seeker without active streak cannot enter for free, must watch ad or unlock."""
    user = User(
        id=uuid.uuid4(),
        streak_count=0,
        streak_expires_at=None,
        last_blind_date_date=None,
        blind_date_passes=0,
    )

    eligibility = BlindDateMatcherService.check_eligibility(user)
    assert eligibility["can_enter"] is False
    assert eligibility["has_daily_streak_pass"] is False
    assert eligibility["is_streak_active"] is False
    assert eligibility["reason"] == "streak_inactive"


def test_check_eligibility_streak_active_already_used_today():
    """Active streak seeker who already used today's free pass has reason daily_pass_exhausted."""
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        streak_count=3,
        streak_expires_at=now + timedelta(hours=8),
        last_blind_date_date=date.today(),
        blind_date_passes=0,
    )

    eligibility = BlindDateMatcherService.check_eligibility(user)
    assert eligibility["can_enter"] is False
    assert eligibility["has_daily_streak_pass"] is False
    assert eligibility["reason"] == "daily_pass_exhausted"


def test_check_eligibility_bonus_passes_override():
    """Bonus passes allow entry even if streak pass was already used."""
    now = datetime.now(timezone.utc)
    user = User(
        id=uuid.uuid4(),
        streak_count=3,
        streak_expires_at=now + timedelta(hours=8),
        last_blind_date_date=date.today(),
        blind_date_passes=2,
    )

    eligibility = BlindDateMatcherService.check_eligibility(user)
    assert eligibility["can_enter"] is True
    assert eligibility["bonus_passes"] == 2
    assert eligibility["reason"] == "ready"


@pytest.mark.asyncio
async def test_claim_ad_pass_ignites_streak_and_adds_pass():
    """Watching a rewarded ad adds a pass and activates streak if inactive (100% Value Parity)."""
    user = User(
        id=uuid.uuid4(),
        streak_count=0,
        streak_expires_at=None,
        last_blind_date_date=None,
        blind_date_passes=0,
    )

    mock_db = AsyncMock()

    with patch("app.services.streak_engine.StreakEngine.claim_daily_streak_ad", new_callable=AsyncMock) as mock_streak_ad:
        # Mock StreakEngine behavior: sets streak active
        async def fake_streak_ad(u, db):
            u.streak_count = 1
            u.streak_expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
            return {"status": "success"}
        mock_streak_ad.side_effect = fake_streak_ad

        res = await BlindDateMatcherService.claim_ad_pass(mock_db, user)

        assert user.blind_date_passes == 1
        assert mock_streak_ad.called
        assert res["can_enter"] is True
        assert res["bonus_passes"] == 1


@pytest.mark.asyncio
async def test_extend_session_duration_and_count():
    """Extending an active session adds +180s and increments extension_count."""
    user1_id = uuid.uuid4()
    user2_id = uuid.uuid4()
    session_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    original_expiry = now + timedelta(seconds=120)

    session = BlindDateSession(
        id=session_id,
        user1_id=user1_id,
        user2_id=user2_id,
        status="active",
        expires_at=original_expiry,
        extension_count=0,
    )

    from unittest.mock import MagicMock
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalars.return_value.first.return_value = session
    mock_db.execute.return_value = mock_result

    updated = await BlindDateMatcherService.extend_session(mock_db, session_id, user1_id)

    assert updated.extension_count == 1
    assert (updated.expires_at - original_expiry).total_seconds() == 180
    assert mock_db.commit.called


@pytest.mark.asyncio
async def test_cancel_queue_refunds_daily_pass():
    """Cancelling while unmatched in waiting status restores daily streak pass."""
    user_id = uuid.uuid4()
    today = date.today()
    user = User(
        id=user_id,
        last_blind_date_date=today,
        blind_date_passes=0,
    )
    from app.models.domain.blind_date import BlindDateQueueEntry
    queue_entry = BlindDateQueueEntry(
        user_id=user_id,
        gender="man",
        interested_in="everyone",
        age=25,
        status="waiting",
        joined_at=datetime.now(timezone.utc),
    )

    from unittest.mock import MagicMock
    mock_db = AsyncMock()
    mock_q_res = MagicMock()
    mock_q_res.scalars.return_value.first.return_value = queue_entry
    mock_u_res = MagicMock()
    mock_u_res.scalars.return_value.first.return_value = user

    mock_db.execute.side_effect = [mock_q_res, mock_u_res]

    result = await BlindDateMatcherService.cancel_queue_entry(mock_db, user_id)

    assert result is True
    assert user.last_blind_date_date is None
    assert mock_db.delete.called
    assert mock_db.commit.called


@pytest.mark.asyncio
async def test_cancel_queue_refunds_bonus_pass():
    """Cancelling while unmatched restores bonus pass if streak pass was not used today."""
    user_id = uuid.uuid4()
    yesterday = date.today() - timedelta(days=1)
    user = User(
        id=user_id,
        last_blind_date_date=yesterday,
        blind_date_passes=1,
    )
    from app.models.domain.blind_date import BlindDateQueueEntry
    queue_entry = BlindDateQueueEntry(
        user_id=user_id,
        gender="woman",
        interested_in="men",
        age=24,
        status="waiting",
        joined_at=datetime.now(timezone.utc),
    )

    from unittest.mock import MagicMock
    mock_db = AsyncMock()
    mock_q_res = MagicMock()
    mock_q_res.scalars.return_value.first.return_value = queue_entry
    mock_u_res = MagicMock()
    mock_u_res.scalars.return_value.first.return_value = user

    mock_db.execute.side_effect = [mock_q_res, mock_u_res]

    result = await BlindDateMatcherService.cancel_queue_entry(mock_db, user_id)

    assert result is True
    assert user.blind_date_passes == 2
    assert mock_db.delete.called
    assert mock_db.commit.called

