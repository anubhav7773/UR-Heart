import os
import uuid
from datetime import date, datetime, timezone
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from httpx import ASGITransport, AsyncClient

from app.api.dependencies import get_current_user, get_db
from app.api.v1.endpoints.admin_kyc import _generate_placeholder_svg
from app.core.security import create_access_token
from app.main import app
from app.models.domain.kyc_escalation import AdminKycEscalation
from app.models.domain.user import User
from app.services.kyc_purge import purge_ephemeral_kyc_video


@pytest.fixture(autouse=True)
def clean_overrides():
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_admin_kyc_pending_queue_enriched():
    """
    Verifies that GET /api/v1/admin/kyc/pending-queue returns enriched items with
    user_name, user_email, and correct 3-photo mapping media URLs.
    """
    user_id = uuid.uuid4()
    admin_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Asi Verticals Sovereign",
        email="asiverticals@gmail.com",
        role="superadmin"
    )

    seeker_user = User(
        id=user_id,
        auth_id=uuid.uuid4(),
        full_name="Anubhav Singh",
        email="anubhavsinghayodhya99@gmail.com",
        dob=date(2004, 1, 1),
        avatar_url="users/avatars/anubhav.webp",
        photos=["users/photos/moment_1.webp"]
    )

    escalation = AdminKycEscalation(
        id=3,
        user_id=user_id,
        declared_dob=date(2004, 1, 1),
        declared_age=22,
        groq_match_score=0,
        groq_reasoning="Automated biometric evaluation temporarily unavailable. Escalated for manual verification.",
        anchor_photo_url=f"/api/v1/admin/kyc/media/{user_id}/profile_1",
        kyc_video_url=f"/api/v1/admin/kyc/media/{user_id}/selfie",
        status="pending",
        created_at=datetime.now(timezone.utc)
    )

    async def mock_get_current_user_admin():
        return admin_user

    async def mock_db_session():
        session = AsyncMock()
        mock_result = MagicMock()
        mock_result.all.return_value = [(escalation, seeker_user)]
        session.execute.return_value = mock_result
        yield session

    app.dependency_overrides[get_current_user] = mock_get_current_user_admin
    app.dependency_overrides[get_db] = mock_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/api/v1/admin/kyc/pending-queue")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 1
        item = data[0]

        assert item["id"] == 3
        assert item["user_id"] == str(user_id)
        assert item["user_name"] == "Anubhav Singh"
        assert item["user_email"] == "anubhavsinghayodhya99@gmail.com"
        assert item["kyc_selfie_url"] == f"/api/v1/admin/kyc/media/{user_id}/selfie"
        assert item["profile_photo_1_url"] == f"/api/v1/admin/kyc/media/{user_id}/profile_1"
        assert item["profile_photo_2_url"] == f"/api/v1/admin/kyc/media/{user_id}/profile_2"
        assert len(item["all_profile_photos"]) >= 1


@pytest.mark.asyncio
async def test_admin_kyc_media_auth_security():
    """
    Verifies that /api/v1/admin/kyc/media endpoints strictly reject unauthenticated or non-admin requests.
    Enforces header-only Authorization and prevents query string credential leakage or role-only bypasses.
    """
    user_id = uuid.uuid4()
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. No Authorization header -> 401
        res = await client.get(f"/api/v1/admin/kyc/media/{user_id}/selfie")
        assert res.status_code == 401

        # 2. Token in query param only -> 401 (disabled for credential protection)
        admin_token = create_access_token({"sub": "admin123", "email": "asiverticals@gmail.com", "role": "superadmin"})
        res_query = await client.get(f"/api/v1/admin/kyc/media/{user_id}/selfie?token={admin_token}")
        assert res_query.status_code == 401

        # 3. Non-admin token in Header -> 403
        non_admin_token = create_access_token({"sub": "user123", "email": "stranger@gmail.com", "role": "user"})
        res_non_admin = await client.get(
            f"/api/v1/admin/kyc/media/{user_id}/selfie",
            headers={"Authorization": f"Bearer {non_admin_token}"}
        )
        assert res_non_admin.status_code == 403

        # 4. Token with role: superadmin but non-admin email -> 403 (strict zero-trust email check)
        spoofed_role_token = create_access_token({"sub": "user999", "email": "attacker@evil.com", "role": "superadmin"})
        res_spoofed = await client.get(
            f"/api/v1/admin/kyc/media/{user_id}/selfie",
            headers={"Authorization": f"Bearer {spoofed_role_token}"}
        )
        assert res_spoofed.status_code == 403


@pytest.mark.asyncio
async def test_admin_kyc_media_selfie_serving():
    """
    Verifies that the live selfie endpoint:
    1. Returns sanitized SVG placeholder when file does not exist (never blank page or 404 JSON).
    2. Streams binary webp image when file exists on ephemeral disk.
    """
    user_id = uuid.uuid4()
    admin_token = create_access_token({"sub": "admin123", "email": "asiverticals@gmail.com", "role": "superadmin"})
    auth_headers = {"Authorization": f"Bearer {admin_token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Case A: File not on disk -> Returns graceful SVG placeholder
        res_svg = await client.get(f"/api/v1/admin/kyc/media/{user_id}/selfie", headers=auth_headers)
        assert res_svg.status_code == 200
        assert "image/svg+xml" in res_svg.headers.get("content-type", "")
        assert "<svg" in res_svg.text
        assert "Live KYC Selfie" in res_svg.text

        # Case B: File on disk -> Returns image/webp
        temp_dir = Path("uploads/kyc_ephemeral") / str(user_id)
        temp_dir.mkdir(parents=True, exist_ok=True)
        sample_file = temp_dir / "kyc_selfie.webp"
        sample_bytes = b"RIFF\x1a\x00\x00\x00WEBPVP8 \x0e\x00\x00\x00\x30\x01\x00\x9d\x01\x2a\x01\x00\x01\x00"
        sample_file.write_bytes(sample_bytes)

        try:
            res_webp = await client.get(f"/api/v1/admin/kyc/media/{user_id}/selfie", headers=auth_headers)
            assert res_webp.status_code == 200
            assert "image/webp" in res_webp.headers.get("content-type", "")
            assert res_webp.content == sample_bytes
        finally:
            if sample_file.exists():
                sample_file.unlink()
            if temp_dir.exists():
                temp_dir.rmdir()


@pytest.mark.asyncio
async def test_admin_kyc_media_profile_photos_and_open_redirect_defense():
    """
    Verifies that profile_1 and profile_2:
    1. Redirect to trusted domains (Cloudinary, Supabase).
    2. Strictly block untrusted external domains (Open Redirect / SSRF defense).
    """
    user_id = uuid.uuid4()
    admin_token = create_access_token({"sub": "admin123", "email": "asiverticals@gmail.com", "role": "superadmin"})
    auth_headers = {"Authorization": f"Bearer {admin_token}"}

    # Case A: Trusted external CDN URL
    user_trusted = User(
        id=user_id,
        auth_id=uuid.uuid4(),
        full_name="Anubhav Singh",
        email="anubhav@example.com",
        avatar_url="https://res.cloudinary.com/sanctuary/avatar.jpg",
        photos=["https://res.cloudinary.com/sanctuary/moment2.jpg"]
    )

    async def mock_db_trusted():
        session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = user_trusted
        session.execute.return_value = mock_result
        yield session

    app.dependency_overrides[get_db] = mock_db_trusted

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res_p1 = await client.get(
            f"/api/v1/admin/kyc/media/{user_id}/profile_1",
            headers=auth_headers,
            follow_redirects=False
        )
        assert res_p1.status_code == 307
        assert res_p1.headers.get("location") == "https://res.cloudinary.com/sanctuary/avatar.jpg"

    # Case B: Untrusted external URL (e.g. attacker domain) -> Blocked with SVG placeholder
    user_untrusted = User(
        id=user_id,
        auth_id=uuid.uuid4(),
        full_name="Attacker",
        email="attacker@example.com",
        avatar_url="https://evil-phishing-site.com/steal-creds.jpg",
        photos=[]
    )

    async def mock_db_untrusted():
        session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = user_untrusted
        session.execute.return_value = mock_result
        yield session

    app.dependency_overrides[get_db] = mock_db_untrusted

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res_block = await client.get(
            f"/api/v1/admin/kyc/media/{user_id}/profile_1",
            headers=auth_headers,
            follow_redirects=False
        )
        assert res_block.status_code == 200
        assert "image/svg+xml" in res_block.headers.get("content-type", "")
        assert "Untrusted external media domain blocked" in res_block.text


@pytest.mark.asyncio
async def test_admin_kyc_path_traversal_blocked():
    """
    Verifies that attempting path traversal in photo strings does not read arbitrary files.
    """
    user_id = uuid.uuid4()
    admin_token = create_access_token({"sub": "admin123", "email": "asiverticals@gmail.com", "role": "superadmin"})
    auth_headers = {"Authorization": f"Bearer {admin_token}"}

    user_traversal = User(
        id=user_id,
        auth_id=uuid.uuid4(),
        full_name="Attacker",
        email="attacker@example.com",
        avatar_url="../../backend/app/core/config.py",
        photos=[]
    )

    async def mock_db_traversal():
        session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = user_traversal
        session.execute.return_value = mock_result
        yield session

    app.dependency_overrides[get_db] = mock_db_traversal

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get(
            f"/api/v1/admin/kyc/media/{user_id}/profile_1",
            headers=auth_headers
        )
        # Must return placeholder SVG, NOT the contents of config.py
        assert res.status_code == 200
        assert "image/svg+xml" in res.headers.get("content-type", "")
        assert "JWT_SECRET_KEY" not in res.text


def test_svg_placeholder_xss_escaping():
    """
    Verifies that _generate_placeholder_svg escapes HTML/XML tags.
    """
    res = _generate_placeholder_svg("<script>alert(1)</script>", "\"><img src=x onerror=alert(2)>")
    assert res.status_code == 200
    text = res.body.decode("utf-8")
    assert "<script>" not in text
    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in text
    assert "&quot;&gt;&lt;img" in text


@pytest.mark.asyncio
async def test_admin_kyc_resolve_approve_and_purge():
    """
    Verifies that resolving a KYC ticket:
    1. Updates User kyc_status.
    2. Updates AdminKycEscalation status.
    3. Triggers FCM push notification.
    4. Triggers purge_ephemeral_kyc_video.
    """
    user_id = uuid.uuid4()
    admin_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        full_name="Asi Verticals Sovereign",
        email="asiverticals@gmail.com",
        role="superadmin"
    )

    async def mock_get_current_user_admin():
        return admin_user

    mock_session = AsyncMock()

    async def mock_db_session():
        yield mock_session

    app.dependency_overrides[get_current_user] = mock_get_current_user_admin
    app.dependency_overrides[get_db] = mock_db_session

    transport = ASGITransport(app=app)
    with patch("app.api.v1.endpoints.admin_kyc.purge_ephemeral_kyc_video") as mock_purge, \
         patch("app.api.v1.endpoints.notifications.push_notification") as mock_notif:

        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/api/v1/admin/kyc/resolve",
                json={
                    "escalation_id": 3,
                    "user_id": str(user_id),
                    "action": "approve",
                    "admin_notes": "Biometrics verified manually via 3-photo mapping"
                }
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "resolved"
            assert data["kyc_status"] is True

            # Verify purge was called
            mock_purge.assert_called_once_with(str(user_id))

            # Verify FCM notification was triggered
            mock_notif.assert_called_once()
            args, kwargs = mock_notif.call_args
            assert kwargs.get("user_id") == str(user_id)
            assert kwargs.get("notif_type") == "kyc_approved"


def test_purge_ephemeral_kyc_video_local_cleanup():
    """
    Verifies that purge_ephemeral_kyc_video cleanly removes local disk directory.
    """
    user_id = str(uuid.uuid4())
    temp_dir = Path("uploads/kyc_ephemeral") / user_id
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_file = temp_dir / "kyc_selfie.webp"
    temp_file.write_text("dummy ephemeral selfie data")

    assert temp_file.exists()

    # Call purge
    result = purge_ephemeral_kyc_video(user_id)
    assert result is True
    assert not temp_dir.exists()
