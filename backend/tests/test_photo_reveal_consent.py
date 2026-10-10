import uuid
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user, get_current_user_optional
from app.models.domain.user import User
from app.models.domain.photo_reveal_consent import PhotoRevealConsent

client = TestClient(app)


def test_user_and_photo_reveal_consent_models():
    """Verify that PhotoRevealConsent model fields and user.is_photo_veiled operate as expected."""
    user = User(
        id=uuid.uuid4(),
        email="seeker@urheart.app",
        full_name="Mindful Seeker",
        is_photo_veiled=True,
    )
    assert user.is_photo_veiled is True

    req_id = uuid.uuid4()
    tar_id = uuid.uuid4()
    consent = PhotoRevealConsent(
        requester_id=req_id,
        target_id=tar_id,
        status="pending",
    )
    assert consent.requester_id == req_id
    assert consent.target_id == tar_id
    assert consent.status == "pending"


def test_request_photo_reveal_endpoint():
    """Verify that a seeker can request photo reveal from a veiled candidate."""
    caller_id = uuid.uuid4()
    target_id = uuid.uuid4()

    caller = User(
        id=caller_id,
        email="caller@urheart.app",
        full_name="Caller Seeker",
    )
    target = User(
        id=target_id,
        email="target@urheart.app",
        full_name="Veiled Seeker",
        is_photo_veiled=True,
    )

    mock_db = AsyncMock()
    # 1st execute: find target user
    # 2nd execute: find existing consent (None)
    mock_target_res = MagicMock()
    mock_target_res.scalar_one_or_none.return_value = target

    mock_consent_res = MagicMock()
    mock_consent_res.scalar_one_or_none.return_value = None

    mock_db.execute = AsyncMock(side_effect=[mock_target_res, mock_consent_res])
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()

    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch("app.api.v1.endpoints.notifications.push_notification") as mock_push:
            res = client.post(f"/api/v1/feed/{target_id}/photo-reveal/request")
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "pending"
            assert "Photo reveal request dispatched" in data["message"]
            assert mock_push.called
    finally:
        app.dependency_overrides.clear()


def test_respond_to_photo_reveal_endpoint():
    """Verify that a seeker can accept or decline a photo reveal request."""
    caller_id = uuid.uuid4()  # Candidate who was asked
    requester_id = uuid.uuid4()  # Seeker who asked

    caller = User(
        id=caller_id,
        email="veiled@urheart.app",
        full_name="Veiled Seeker",
        is_photo_veiled=True,
    )

    consent = PhotoRevealConsent(
        requester_id=requester_id,
        target_id=caller_id,
        status="pending",
    )

    mock_db = AsyncMock()
    mock_consent_res = MagicMock()
    mock_consent_res.scalar_one_or_none.return_value = consent
    mock_db.execute = AsyncMock(return_value=mock_consent_res)
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with patch("app.api.v1.endpoints.notifications.push_notification") as mock_push:
            res = client.post(
                f"/api/v1/feed/{requester_id}/photo-reveal/respond",
                json={"action": "accept"},
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "accepted"
            assert consent.status == "accepted"
            assert mock_push.called
    finally:
        app.dependency_overrides.clear()


def test_request_declined_photo_reveal_forbidden():
    """Verify that a declined photo reveal request cannot be reset to pending."""
    caller_id = uuid.uuid4()
    target_id = uuid.uuid4()

    caller = User(id=caller_id, email="caller@urheart.app", full_name="Caller")
    target = User(id=target_id, email="target@urheart.app", full_name="Target", is_photo_veiled=True)

    declined_consent = PhotoRevealConsent(
        requester_id=caller_id,
        target_id=target_id,
        status="declined",
    )

    mock_db = AsyncMock()
    mock_target_res = MagicMock()
    mock_target_res.scalar_one_or_none.return_value = target
    mock_consent_res = MagicMock()
    mock_consent_res.scalar_one_or_none.return_value = declined_consent

    mock_db.execute = AsyncMock(side_effect=[mock_target_res, mock_consent_res])

    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.post(f"/api/v1/feed/{target_id}/photo-reveal/request")
        assert res.status_code == 403
        assert "previously declined" in res.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_respond_to_nonexistent_photo_reveal_404():
    """Verify that respond_to_photo_reveal rejects requests if no pending request exists."""
    caller_id = uuid.uuid4()
    requester_id = uuid.uuid4()

    caller = User(id=caller_id, email="caller@urheart.app", full_name="Caller")

    mock_db = AsyncMock()
    mock_consent_res = MagicMock()
    mock_consent_res.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=mock_consent_res)

    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.post(
            f"/api/v1/feed/{requester_id}/photo-reveal/respond",
            json={"action": "accept"},
        )
        assert res.status_code == 404
        assert "No pending photo reveal request found" in res.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_respond_to_already_processed_photo_reveal_400():
    """Verify that respond_to_photo_reveal rejects already accepted/declined requests."""
    caller_id = uuid.uuid4()
    requester_id = uuid.uuid4()

    caller = User(id=caller_id, email="caller@urheart.app", full_name="Caller")
    already_accepted = PhotoRevealConsent(
        requester_id=requester_id,
        target_id=caller_id,
        status="accepted",
    )

    mock_db = AsyncMock()
    mock_consent_res = MagicMock()
    mock_consent_res.scalar_one_or_none.return_value = already_accepted
    mock_db.execute = AsyncMock(return_value=mock_consent_res)

    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.post(
            f"/api/v1/feed/{requester_id}/photo-reveal/respond",
            json={"action": "accept"},
        )
        assert res.status_code == 400
        assert "Cannot respond to photo reveal request that is already 'accepted'" in res.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_seeker_profile_masks_photos_when_veiled():
    """Verify that get_seeker_profile returns empty photo URLs when veiled and locked."""
    caller_id = uuid.uuid4()
    target_id = uuid.uuid4()

    caller = User(id=caller_id, email="caller@urheart.app", full_name="Caller")
    target = User(
        id=target_id,
        email="target@urheart.app",
        full_name="Veiled Seeker",
        is_photo_veiled=True,
        avatar_url="https://example.com/clear_avatar.jpg",
        photos=["https://example.com/clear_photo1.jpg", "https://example.com/clear_photo2.jpg"],
    )

    mock_db = AsyncMock()
    mock_target_res = MagicMock()
    mock_target_res.scalar_one_or_none.return_value = target

    mock_match_res = MagicMock()
    mock_match_res.scalar_one_or_none.return_value = None

    mock_consent_res = MagicMock()
    mock_scalars = MagicMock()
    mock_scalars.all.return_value = []
    mock_consent_res.scalars.return_value = mock_scalars

    mock_db.execute = AsyncMock(side_effect=[mock_target_res, mock_match_res, mock_consent_res])

    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get(f"/api/v1/profile/{target_id}")
        assert res.status_code == 200
        data = res.json()
        assert data["is_photo_veiled"] is True
        assert data["is_photo_unlocked"] is False
        # Clear photo URLs must NOT be exposed
        assert data["avatar_url"] == ""
        assert data["avatar"] == ""
        assert data["photos"] == []
        assert data["photo_urls"] == []
    finally:
        app.dependency_overrides.clear()


def test_photo_reveal_returns_503_when_schema_not_ready():
    """Verify that photo reveal endpoint returns 503 if schema is marked unready."""
    caller = User(id=uuid.uuid4(), email="caller@urheart.app", full_name="Caller")
    app.dependency_overrides[get_current_user] = lambda: caller

    # Explicitly simulate degraded startup state
    original_state = getattr(app.state, "photo_veil_schema_ready", None)
    app.state.photo_veil_schema_ready = False

    try:
        res = client.post(f"/api/v1/feed/{uuid.uuid4()}/photo-reveal/request")
        assert res.status_code == 503
        assert "temporarily unavailable" in res.json()["detail"]
    finally:
        if original_state is not None:
            app.state.photo_veil_schema_ready = original_state
        else:
            delattr(app.state, "photo_veil_schema_ready")
        app.dependency_overrides.clear()


def test_health_check_reports_photo_veil_ready():
    """Verify that /api/v1/health exposes photo_veil_ready flag for observability."""
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    data = res.json()
    assert "photo_veil_ready" in data

