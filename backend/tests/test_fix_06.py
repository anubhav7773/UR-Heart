import pytest
from uuid import uuid4
from unittest.mock import patch, MagicMock, AsyncMock
from httpx import AsyncClient
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue

VALID_MP4_BYTES = b"\x00\x00\x00\x1cftypisom\x00\x00\x02\x00isomiso2mp41" + b"\x00" * 100

@pytest.mark.asyncio
async def test_submit_video_kyc_uploads_to_kyc_temp_and_enqueues_unreviewed(async_client: AsyncClient, db_session):
    """
    GOAL FIX-06:
    When video is submitted via POST /api/v1/kyc/submit-video:
    - Uploads compressed MP4 to Supabase Storage bucket 'kyc-temp' with path '{user_id}/selfie.mp4'
    - Inserts record into public.kyc_review_queue with status='unreviewed'
    - Retains video in kyc-temp (does NOT auto-purge immediately)
    """
    user_id = uuid4()
    candidate_name = f"Test Candidate {uuid4().hex[:6]}"
    candidate = User(
        id=user_id,
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name=candidate_name,
        dob="1999-01-01",
        gender="male",
        city="Ayodhya",
        kyc_status=False,
        kyc_state="pending_manual_review"
    )
    db_session.add(candidate)
    await db_session.commit()
    await db_session.refresh(candidate)

    headers = {"X-Consent-DPDP": "true"}
    files = {"file": ("selfie.mp4", VALID_MP4_BYTES, "video/mp4")}
    data = {
        "user_id": str(user_id),
        "user_name": candidate_name,
        "user_city": "Ayodhya"
    }

    with patch("app.services.ai_kyc_service.verify_face_in_video", return_value=True), \
         patch("app.services.ai_kyc_service.extract_audio_track", return_value=True), \
         patch("app.services.ai_kyc_service.transcribe_audio_groq", new_callable=AsyncMock) as mock_whisper, \
         patch("app.services.ai_kyc_service.evaluate_semantic_match_groq", new_callable=AsyncMock) as mock_llama, \
         patch("app.services.storage_service.supabase_storage_client.storage.from_") as mock_storage:

        mock_whisper.return_value = f"Mera naam {candidate_name} hai aur main Ayodhya se hoon"
        mock_llama.return_value = {
            "name_match": True,
            "city_match": True,
            "confidence": 0.96
        }
        mock_bucket = MagicMock()
        mock_storage.return_value = mock_bucket

        response = await async_client.post("/api/v1/kyc/submit-video", headers=headers, files=files, data=data)

        assert response.status_code == 200, response.text
        res_data = response.json()
        assert res_data["status"] == "queued_for_admin_review"
        assert res_data["video_purged"] is False
        assert res_data["confidence"] == 0.96
        assert res_data["transcript"] == f"Mera naam {candidate_name} hai aur main Ayodhya se hoon"

        # Verify upload to kyc-temp with path {user_id}/selfie.mp4
        mock_bucket.upload.assert_called_with(
            path=f"{user_id}/selfie.mp4",
            file=VALID_MP4_BYTES,
            file_options={"content-type": "video/mp4", "upsert": "true"}
        )

    # Clean up
    await db_session.delete(candidate)
    await db_session.commit()

@pytest.mark.asyncio
async def test_admin_kyc_queue_returns_1h_signed_playback_url(async_client: AsyncClient, admin_token, db_session):
    """
    GOAL FIX-06:
    When fetching pending queue via GET /api/v1/admin/kyc/queue:
    - Generates 1-hour presigned URL (expires_in=3600)
    - Returns full HTTPS URL to client
    """
    user_id = uuid4()
    candidate_name = f"Test Queue {uuid4().hex[:6]}"
    candidate = User(
        id=user_id,
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name=candidate_name,
        dob="1999-01-01",
        gender="male",
        city="Ayodhya",
        kyc_status=False,
        kyc_state="pending_manual_review"
    )
    db_session.add(candidate)
    await db_session.commit()
    await db_session.refresh(candidate)

    queue_entry = KycReviewQueue(
        user_id=user_id,
        video_storage_path=f"{user_id}/selfie.mp4",
        registered_name=candidate_name,
        registered_city="Ayodhya",
        extracted_transcript=f"Mera naam {candidate_name} hai aur main Ayodhya se hoon",
        ai_confidence_score=0.96,
        ai_flags=[],
        status="unreviewed"
    )
    db_session.add(queue_entry)
    await db_session.commit()
    await db_session.refresh(queue_entry)

    headers = {"Authorization": f"Bearer {admin_token}"}

    with patch("app.services.storage_service.supabase_storage_client.storage.from_") as mock_storage:
        mock_bucket = MagicMock()
        mock_storage.return_value = mock_bucket
        expected_signed_url = f"https://mock-storage.supabase.co/kyc-temp/{user_id}/selfie.mp4?token=signed_1h"
        mock_bucket.create_signed_url.return_value = {"signedURL": expected_signed_url}

        response = await async_client.get("/api/v1/admin/kyc/queue", headers=headers)
        assert response.status_code == 200
        items = response.json()
        assert len(items) >= 1

        target_item = next((it for it in items if it["user_id"] == str(user_id)), None)
        assert target_item is not None
        assert target_item["registered_name"] == candidate_name
        assert target_item["registered_city"] == "Ayodhya"
        assert target_item["extracted_transcript"] == f"Mera naam {candidate_name} hai aur main Ayodhya se hoon"
        assert target_item["video_playback_url"] == expected_signed_url

        # Assert expires_in was set to 3600 (1 hour)
        mock_bucket.create_signed_url.assert_any_call(
            path=f"{user_id}/selfie.mp4",
            expires_in=3600
        )

    # Clean up
    await db_session.delete(queue_entry)
    await db_session.delete(candidate)
    await db_session.commit()
