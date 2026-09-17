import pytest
from unittest.mock import patch, MagicMock
from uuid import uuid4
from datetime import datetime, timezone, timedelta
from fastapi import HTTPException
from app.services.storage_service import (
    validate_binary_magic_bytes,
    upload_profile_photo_to_storage,
    upload_kyc_video_to_storage,
    purge_kyc_video_from_storage
)
from app.services.ai_kyc_service import (
    handle_ai_verification_outcome,
    purge_expired_unreviewed_kyc_videos
)
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue

def test_magic_bytes_photo_validation():
    """Verify WebP and JPEG header validation and rejection of fake extensions."""
    valid_webp = b"RIFF\x00\x00\x00\x00WEBPVP8 " + b"\x00" * 20
    valid_jpeg = b"\xFF\xD8\xFF\xE0\x00\x10JFIF" + b"\x00" * 20
    fake_exe = b"MZ\x90\x00\x03\x00\x00\x00\x04\x00" + b"\x00" * 20

    assert validate_binary_magic_bytes(valid_webp, "photo") is True
    assert validate_binary_magic_bytes(valid_jpeg, "photo") is True
    assert validate_binary_magic_bytes(fake_exe, "photo") is False

def test_magic_bytes_video_validation():
    """Verify MP4 container box header verification."""
    valid_mp4 = b"\x00\x00\x00\x20ftypisom\x00\x00\x02\x00" + b"\x00" * 20
    text_file = b"This is just plain text masquerading as mp4"

    assert validate_binary_magic_bytes(valid_mp4, "video") is True
    assert validate_binary_magic_bytes(text_file, "video") is False

@pytest.mark.asyncio
async def test_photo_upload_size_limit_rejection():
    """Assert photos exceeding 150 KB are rejected with HTTP 413."""
    user_id = uuid4()
    oversized_bytes = b"RIFF" + b"\x00" * 4 + b"WEBP" + b"\x00" * (160 * 1024)

    with pytest.raises(HTTPException) as exc:
        await upload_profile_photo_to_storage(user_id, 1, oversized_bytes)
    assert exc.value.status_code == 413

@pytest.mark.asyncio
async def test_video_upload_size_limit_rejection():
    """Assert videos exceeding 2.5 MB are rejected with HTTP 413."""
    user_id = uuid4()
    oversized_bytes = b"\x00\x00\x00\x20ftypisom" + b"\x00" * (2621440 + 1024)

    with pytest.raises(HTTPException) as exc:
        await upload_kyc_video_to_storage(user_id, oversized_bytes)
    assert exc.value.status_code == 413

@pytest.mark.asyncio
async def test_auto_purge_on_ai_approval(db_session):
    """Confirm video is deleted from storage immediately when AI auto-verifies."""
    user = User(
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Priya Sharma",
        dob="1999-05-15",
        gender="female",
        city="Ayodhya"
    )
    db_session.add(user)
    await db_session.commit()

    with patch("app.services.storage_service.supabase_storage_client.storage.from_") as mock_storage:
        mock_bucket = MagicMock()
        mock_storage.return_value = mock_bucket

        result = await handle_ai_verification_outcome(
            user_id=user.id,
            user_name="Priya Sharma",
            user_city="Ayodhya",
            video_storage_path=f"{user.id}/test_video.mp4",
            confidence_score=0.92,
            transcript="Mera naam Priya Sharma hai aur main Ayodhya se hoon",
            has_valid_face=True,
            semantic_pass=True,
            db=db_session
        )

        assert result["status"] == "auto_verified"
        assert result["video_purged"] is True
        # Verify remove call was sent to Supabase storage bucket
        mock_bucket.remove.assert_called_once_with([f"{user.id}/test_video.mp4"])

    # Clean up user
    await db_session.delete(user)
    await db_session.commit()

@pytest.mark.asyncio
async def test_orphan_kyc_videos_cron_purge(db_session):
    """Confirm purge_expired_unreviewed_kyc_videos cleans up records older than 48 hours."""
    user = User(
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Stale User",
        dob="1999-01-01",
        gender="male",
        city="Varanasi"
    )
    db_session.add(user)
    await db_session.commit()

    stale_record = KycReviewQueue(
        user_id=user.id,
        video_storage_path=f"{user.id}/stale_video.mp4",
        registered_name="Stale User",
        registered_city="Varanasi",
        extracted_transcript="Test",
        ai_confidence_score=0.50,
        ai_flags=["low_confidence_score"],
        status="unreviewed",
        created_at=datetime.now(timezone.utc) - timedelta(hours=50)
    )
    db_session.add(stale_record)
    await db_session.commit()

    with patch("app.services.storage_service.supabase_storage_client.storage.from_") as mock_storage:
        mock_bucket = MagicMock()
        mock_storage.return_value = mock_bucket

        purged_count = await purge_expired_unreviewed_kyc_videos(db=db_session)
        assert purged_count >= 1
        mock_bucket.remove.assert_called_with([f"{user.id}/stale_video.mp4"])

    # Clean up stale record & user
    await db_session.delete(stale_record)
    await db_session.delete(user)
    await db_session.commit()
