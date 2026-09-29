import pytest
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from fastapi.testclient import TestClient

from app.main import app
from app.models.domain.user import User
from app.services.streak_engine import StreakEngine
from app.api.v1.endpoints.notifications import NOTIFICATION_STORE
from app.core.database import async_session_factory

client = TestClient(app)


def test_claim_daily_streak_boost():
    """Verifies that claiming daily streak grants +1 streak, +1 boost point, and 24h timer."""
    from app.core.security import get_current_user
    test_user = User(
        id=uuid4(),
        auth_id=uuid4(),
        full_name="Streak Seeker",
        email="streak@urheart.app",
        streak_count=0,
        boost_points=0,
        reveal_tokens_count=1,
        is_profile_completed=True
    )
    app.dependency_overrides[get_current_user] = lambda: test_user
    try:
        res = client.post("/api/v1/ads/claim-reward", json={
            "ad_type": "daily_streak_boost"
        }, headers={"Authorization": "Bearer test"})
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["streak_count"] >= 1
        assert data["boost_points"] >= 1
        assert data["seconds_remaining"] > 0
        assert data["streak_expires_at"] is not None
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_streak_boost_feed_ranking():
    """Verifies that discovery feed returns candidates with boost_points and streak_count."""
    res = client.get("/api/v1/feed?limit=10")
    assert res.status_code == 200
    data = res.json()
    candidates = data.get("candidates", [])
    if candidates:
        first = candidates[0]
        assert "streak_count" in first
        assert "boost_points" in first
        assert "is_boosted" in first


@pytest.mark.asyncio
async def test_streak_decay_penalty_and_token_loss():
    """
    Verifies that when 24h expires without maintenance:
    - streak resets to 0
    - boost points decay
    - 1 reveal token is deducted / cut
    - alert notification is pushed
    """
    async with async_session_factory() as session:
        test_user = User(
            id=uuid4(),
            auth_id=uuid4(),
            full_name="Decay Test Seeker",
            dob=datetime(1998, 5, 20).date(),
            gender="Man",
            interested_in="Women",
            contact_bridge_encrypted="9988776655",
            streak_count=4,
            boost_points=5,
            reveal_tokens_count=2,
            streak_expires_at=datetime.now(timezone.utc) - timedelta(hours=2), # Expired 2h ago!
            referral_code=f"UR-{uuid4().hex[:6].upper()}"
        )
        session.add(test_user)
        await session.commit()
        await session.refresh(test_user)

        # Run evaluation
        decayed = await StreakEngine.evaluate_and_decay_streak(test_user, session)
        assert decayed is True
        assert test_user.streak_count == 0
        assert test_user.boost_points == 3  # 5 - 2 = 3
        assert test_user.reveal_tokens_count == 1  # 2 - 1 = 1 (1 Reveal token deducted!)
        assert test_user.streak_expires_at is None

        # Check notification in store
        user_notifs = NOTIFICATION_STORE.get(str(test_user.id), [])
        decay_notifs = [n for n in user_notifs if n.get("type") == "streak_broken"]
        assert len(decay_notifs) >= 1
        assert "🥀 Streak Broken" in decay_notifs[0]["title"]


def test_get_streak_status_endpoint():
    """Verifies that /api/v1/ads/streak-status rejects unauth with 401, and returns active countdown for auth user."""
    # 1. Unauthenticated request must be rejected with 401
    res_unauth = client.get("/api/v1/ads/streak-status")
    assert res_unauth.status_code == 401

    # 2. Authenticated request succeeds with 200 and returns active metrics
    from app.core.security import get_current_user
    test_user = User(
        id=uuid4(),
        auth_id=uuid4(),
        full_name="Status Seeker",
        email="status@urheart.app",
        streak_count=3,
        boost_points=3,
        reveal_tokens_count=2,
        is_profile_completed=True
    )
    app.dependency_overrides[get_current_user] = lambda: test_user
    try:
        res = client.get("/api/v1/ads/streak-status", headers={"Authorization": "Bearer test"})
        assert res.status_code == 200
        data = res.json()
        assert "streak_count" in data
        assert "boost_points" in data
        assert "reveal_tokens_count" in data
        assert "visibility_multiplier_label" in data
    finally:
        app.dependency_overrides.pop(get_current_user, None)

