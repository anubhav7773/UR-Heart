import uuid
import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock

from app.main import app
from app.core.security import get_current_user
from app.core.database import get_db
from app.models.domain.user import User

client = TestClient(app)


def test_unauthenticated_session_rejection():
    """
    CRITERIA 1: Unauthenticated Session Test
    Bina kisi Authorization header ke /api/v1/chat/threads, /api/v1/resonances/likes,
    aur /api/v1/notifications par GET request dispatch karein.
    Pass Criteria: Direct HTTP 401 Unauthorized aana chahiye. Zero data leak.
    """
    # 1. /api/v1/chat/threads
    res_chat = client.get("/api/v1/chat/threads")
    assert res_chat.status_code == 401, f"Expected 401 on /chat/threads, got {res_chat.status_code}"

    # 2. /api/v1/resonances/likes
    res_likes = client.get("/api/v1/resonances/likes")
    assert res_likes.status_code == 401, f"Expected 401 on /resonances/likes, got {res_likes.status_code}"

    # 3. /api/v1/notifications
    res_notif = client.get("/api/v1/notifications")
    assert res_notif.status_code == 401, f"Expected 401 on /notifications, got {res_notif.status_code}"


def test_magic_link_response_inspection():
    """
    CRITERIA 2: Magic Link Response Inspection
    POST /api/v1/auth/send-magic-link par valid email bhejein.
    Pass Criteria: HTTP response JSON mein magic_link, deep_link, ya raw token absent hona chahiye.
    """
    res = client.post("/api/v1/auth/send-magic-link", json={"email": "anubhav.founder@urheart.app"})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "sent"
    assert "magic_link" not in data, "CRITICAL DEFECT: magic_link leaked in response JSON"
    assert "deep_link" not in data, "CRITICAL DEFECT: deep_link leaked in response JSON"
    assert "token" not in data, "CRITICAL DEFECT: token leaked in response JSON"
    assert "masked_email" in data
    assert data["masked_email"].startswith("an***@")


@pytest.mark.asyncio
async def test_idor_profile_mutation_neutralization():
    """
    CRITERIA 3: IDOR Profile Mutation Test
    User A ke authenticated token ke sath POST /api/v1/profile/create par User B ka email
    pass karke profile modify karne ki koshish karein.
    Pass Criteria: User B ka profile completely untouched rehna chahiye; updates strictly User A par honi chahiye.
    """
    user_a_id = uuid.uuid4()
    user_b_id = uuid.uuid4()

    user_a = User(
        id=user_a_id,
        email="user_a@urheart.app",
        full_name="User Alpha",
        bio="Original Bio A",
        location_name="Ayodhya",
        is_profile_completed=True
    )
    user_b = User(
        id=user_b_id,
        email="user_b@urheart.app",
        full_name="User Beta",
        bio="Sacred Unmodified Bio B",
        location_name="Varanasi",
        is_profile_completed=True
    )

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    # Authenticated as User A
    app.dependency_overrides[get_current_user] = lambda: user_a
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # Attack payload: Attacker sends User B's email trying to hijack User B's bio and name
        malicious_payload = {
            "email": "user_b@urheart.app",  # Targeting User B
            "full_name": "Hacked Beta Profile",
            "bio": "Compromised by IDOR exploit",
            "looking_for": "Everyone",
            "gender": "Woman",
            "location_name": "Attacker City"
        }

        res = client.post("/api/v1/profile/create", json=malicious_payload)
        assert res.status_code == 200

        # Verify that User B's state was NOT touched
        assert user_b.full_name == "User Beta"
        assert user_b.bio == "Sacred Unmodified Bio B"
        assert user_b.email == "user_b@urheart.app"

        # Verify that updates were strictly bound to User A
        update_calls = mock_db.execute.call_args_list
        assert len(update_calls) > 0
        # The update query must be constrained to User.id == user_a.id
        called_stmt = str(update_calls[0][0][0])
        assert "users.id =" in called_stmt
        assert "users.email =" not in called_stmt
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_regression_authenticated_user_access():
    """
    CRITERIA 4: Regression Check
    Existing valid users ke normal profile, dialogue, resonance, aur notification
    flows bina kisi break ke smooth execute hone chahiye.
    """
    test_user = User(
        id=uuid.uuid4(),
        email="anubhav@asiverticals.me",
        full_name="Anubhav Singh",
        is_profile_completed=True
    )

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: test_user
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        # 1. Notifications with valid auth
        res_notif = client.get("/api/v1/notifications")
        assert res_notif.status_code == 200
        assert res_notif.json()["status"] == "success"

        # 2. Resonances likes with valid auth
        from unittest.mock import MagicMock
        mock_result = MagicMock()
        mock_result.all.return_value = []
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute.return_value = mock_result
        res_likes = client.get("/api/v1/resonances/likes")
        assert res_likes.status_code == 200
        assert "likes" in res_likes.json()

        # 3. Chat threads with valid auth
        res_chat = client.get("/api/v1/chat/threads")
        assert res_chat.status_code == 200
        assert "threads" in res_chat.json()
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)
