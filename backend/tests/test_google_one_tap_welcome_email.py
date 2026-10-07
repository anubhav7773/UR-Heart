import pytest
import uuid
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.models.domain.user import User
from app.core.config import get_settings
from app.services.email_service import EmailService
from app.core.security import (
    verify_firebase_jwt,
    GOOGLE_SERVER_CLIENT_ID,
    FIREBASE_PROJECT_ID,
)

client = TestClient(app)


# ---------------------------------------------------------------------------
# TEST 1: Dual-Cert Verification Engine (Google OAuth & Firebase Tokens)
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_verify_firebase_jwt_supports_google_oauth_claims():
    """Verify that Google OAuth tokens from Google One Tap are properly decoded and validated."""
    mock_payload = {
        "iss": "https://accounts.google.com",
        "aud": GOOGLE_SERVER_CLIENT_ID,
        "sub": "google-user-12345",
        "email": "testseeker@example.com",
        "name": "Sacred Seeker",
    }
    with patch("jose.jwt.get_unverified_header", return_value={"kid": "test-kid"}), \
         patch("jose.jwt.get_unverified_claims", return_value={"iss": "https://accounts.google.com"}), \
         patch("app.core.security.get_google_oauth_public_keys", AsyncMock(return_value={"test-kid": "fake-cert"})), \
         patch("jose.jwt.decode", return_value=mock_payload):

        claims = await verify_firebase_jwt("mock.google.jwt")
        assert claims["email"] == "testseeker@example.com"
        assert claims["sub"] == "google-user-12345"


@pytest.mark.asyncio
async def test_verify_firebase_jwt_supports_firebase_claims():
    """Verify that standard Firebase Auth tokens are also properly validated."""
    mock_payload = {
        "iss": f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}",
        "aud": FIREBASE_PROJECT_ID,
        "sub": "firebase-uid-67890",
        "email": "firebaseseeker@example.com",
    }
    with patch("jose.jwt.get_unverified_header", return_value={"kid": "fb-kid"}), \
         patch("jose.jwt.get_unverified_claims", return_value={"iss": f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"}), \
         patch("app.core.security.get_google_public_keys", AsyncMock(return_value={"fb-kid": "fake-fb-cert"})), \
         patch("jose.jwt.decode", return_value=mock_payload):

        claims = await verify_firebase_jwt("mock.firebase.jwt")
        assert claims["email"] == "firebaseseeker@example.com"
        assert claims["sub"] == "firebase-uid-67890"


# ---------------------------------------------------------------------------
# TEST 2: Delayed Welcome Email Scheduling & Execution Flow
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_schedule_delayed_welcome_email_flow():
    """Verify that schedule_delayed_welcome_email waits for the grace delay and invokes dispatch."""
    clean_email = f"delaytest_{uuid.uuid4().hex[:6]}@example.com"
    EmailService._in_flight_welcome_emails.discard(clean_email)

    with patch.object(EmailService, "dispatch_welcome_sanctuary_email", AsyncMock(return_value={"dispatched": True, "provider": "test_mock"})) as mock_dispatch, \
         patch("app.core.database.async_session_factory") as mock_session_ctx:

        mock_session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = False  # welcome_email_sent is False
        mock_session.execute.return_value = mock_result
        mock_session_ctx.return_value.__aenter__.return_value = mock_session

        task = EmailService.schedule_delayed_welcome_email(
            email=clean_email,
            full_name="Grace Seeker",
            delay_seconds=0.01  # Instant for unit testing
        )
        assert task is not None
        await task

        mock_dispatch.assert_awaited_once_with(
            email=clean_email,
            full_name="Grace Seeker"
        )
        assert clean_email not in EmailService._in_flight_welcome_emails


@pytest.mark.asyncio
async def test_schedule_delayed_welcome_email_in_flight_deduplication():
    """Verify that calling schedule_delayed_welcome_email twice while in-flight skips duplicates."""
    clean_email = f"deduptest_{uuid.uuid4().hex[:6]}@example.com"
    EmailService._in_flight_welcome_emails.discard(clean_email)

    with patch.object(EmailService, "dispatch_welcome_sanctuary_email", AsyncMock(return_value={"dispatched": True, "provider": "test_mock"})):
        # First call spawns task
        task1 = EmailService.schedule_delayed_welcome_email(
            email=clean_email,
            full_name="First Seeker",
            delay_seconds=0.5
        )
        assert task1 is not None

        # Second call immediately while task1 is running returns None
        task2 = EmailService.schedule_delayed_welcome_email(
            email=clean_email,
            full_name="Duplicate Seeker",
            delay_seconds=0.5
        )
        assert task2 is None

        await task1
        assert clean_email not in EmailService._in_flight_welcome_emails


@pytest.mark.asyncio
async def test_schedule_delayed_welcome_email_suppressed_if_already_sent_in_db():
    """Verify that if DB already has welcome_email_sent=True, the dispatch is skipped."""
    clean_email = f"alreadysent_{uuid.uuid4().hex[:6]}@example.com"
    EmailService._in_flight_welcome_emails.discard(clean_email)

    with patch.object(EmailService, "dispatch_welcome_sanctuary_email", AsyncMock()) as mock_dispatch, \
         patch("app.core.database.async_session_factory") as mock_session_ctx:

        mock_session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = True  # Already sent in DB!
        mock_session.execute.return_value = mock_result
        mock_session_ctx.return_value.__aenter__.return_value = mock_session

        task = EmailService.schedule_delayed_welcome_email(
            email=clean_email,
            full_name="Old Seeker",
            delay_seconds=0.01
        )
        assert task is not None
        await task

        mock_dispatch.assert_not_called()


# ---------------------------------------------------------------------------
# TEST 3: POST /api/v1/auth/google-sync Integration
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_google_sync_schedules_delayed_welcome_for_new_user():
    """Verify that a newly registered Google user gets the 14s delayed welcome email scheduled."""
    new_email = f"newgoogle_{uuid.uuid4().hex[:6]}@example.com"
    EmailService._in_flight_welcome_emails.discard(new_email)

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None  # User does not exist yet
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_db] = lambda: mock_db
    try:
        with patch("app.core.security.verify_firebase_jwt", AsyncMock(return_value={"email": new_email})), \
             patch.object(EmailService, "schedule_delayed_welcome_email") as mock_schedule:

            resp = client.post(
                "/api/v1/auth/google-sync",
                json={
                    "email": new_email,
                    "user_id": str(uuid.uuid4()),
                    "display_name": "New Google Seeker",
                    "id_token": "valid_mock_token",
                },
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "synchronized"

            mock_schedule.assert_called_once_with(
                email=new_email,
                full_name="New Google Seeker",
                delay_seconds=14.0
            )
    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_google_sync_does_not_resend_welcome_if_already_sent():
    """Verify that returning users who already received the email do not get another email."""
    existing_email = f"existing_{uuid.uuid4().hex[:6]}@example.com"
    mock_user = MagicMock()
    mock_user.id = uuid.uuid4()
    mock_user.email = existing_email
    mock_user.role = "user"
    mock_user.is_profile_completed = True
    mock_user.welcome_email_sent = True

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_user
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    app.dependency_overrides[get_db] = lambda: mock_db
    try:
        with patch("app.core.security.verify_firebase_jwt", AsyncMock(return_value={"email": existing_email})), \
             patch.object(EmailService, "schedule_delayed_welcome_email") as mock_schedule:

            resp = client.post(
                "/api/v1/auth/google-sync",
                json={
                    "email": existing_email,
                    "user_id": str(mock_user.id),
                    "display_name": "Existing Seeker",
                    "id_token": "valid_mock_token",
                },
            )
            assert resp.status_code == 200
            mock_schedule.assert_not_called()
    finally:
        app.dependency_overrides.pop(get_db, None)
