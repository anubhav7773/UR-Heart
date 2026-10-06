import uuid
from unittest.mock import AsyncMock, MagicMock
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.core.security import get_current_user_optional
from app.models.domain.user import User

client = TestClient(app)


def test_discovery_feed_strictly_excludes_caller_profile():
    """Verify that the discovery feed never returns the calling user's own card."""
    caller_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    cand_id = uuid.UUID("22222222-2222-2222-2222-222222222222")

    caller = User(
        id=caller_id,
        email="caller@urheart.app",
        full_name="Caller User",
        gender="Man",
        interested_in="Women",
        is_profile_completed=True,
    )
    other_candidate = User(
        id=cand_id,
        email="other@urheart.app",
        full_name="Other Candidate",
        gender="Woman",
        interested_in="Men",
        is_profile_completed=True,
        is_incognito=False,
    )
    # A candidate with same email as caller (e.g. duplicate legacy row)
    same_email_candidate = User(
        id=uuid.UUID("33333333-3333-3333-3333-333333333333"),
        email="caller@urheart.app",
        full_name="Duplicate Caller",
        gender="Woman",
        interested_in="Men",
        is_profile_completed=True,
        is_incognito=False,
    )

    mock_db = AsyncMock()
    mock_result = MagicMock()
    # Mock returning all 3 candidates before caller filtering
    mock_result.scalars.return_value.all.return_value = [other_candidate, caller, same_email_candidate]
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[get_current_user_optional] = lambda: caller
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        res = client.get("/api/v1/discovery/feed")
        assert res.status_code == 200
        data = res.json()
        candidate_ids = [c["id"] for c in data["candidates"]]

        # Assert other candidate is present
        assert str(cand_id) in candidate_ids
        # Assert caller's own ID is completely excluded
        assert str(caller_id) not in candidate_ids
        # Assert caller's duplicate email row is completely excluded
        assert str(same_email_candidate.id) not in candidate_ids
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)


def test_discovery_feed_excludes_caller_via_fallback_headers():
    """Verify that X-User-Id and X-User-Email headers exclude the caller even when unauthenticated."""
    caller_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
    cand_id = uuid.UUID("55555555-5555-5555-5555-555555555555")

    other_cand = User(
        id=cand_id,
        email="other_seeker@urheart.app",
        full_name="Other Seeker",
        gender="Woman",
        interested_in="Men",
        is_profile_completed=True,
        is_incognito=False,
    )
    unauthed_self = User(
        id=caller_id,
        email="self_unauthed@urheart.app",
        full_name="Self Unauthed",
        gender="Man",
        interested_in="Women",
        is_profile_completed=True,
        is_incognito=False,
    )

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = [other_cand, unauthed_self]
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[get_current_user_optional] = lambda: None
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        headers = {
            "X-User-Id": str(caller_id),
            "X-User-Email": "self_unauthed@urheart.app"
        }
        res = client.get("/api/v1/discovery/feed", headers=headers)
        assert res.status_code == 200
        data = res.json()
        candidate_ids = [c["id"] for c in data["candidates"]]

        assert str(cand_id) in candidate_ids
        assert str(caller_id) not in candidate_ids
    finally:
        app.dependency_overrides.pop(get_current_user_optional, None)
        app.dependency_overrides.pop(get_db, None)
