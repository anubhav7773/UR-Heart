import pytest
from httpx import AsyncClient
from uuid import uuid4
from unittest.mock import patch, MagicMock
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue

@pytest.mark.asyncio
async def test_admin_endpoints_restricted_access(async_client: AsyncClient, regular_user_token):
    """Assert admin endpoints deny access to regular users with 403 Forbidden."""
    headers = {"Authorization": f"Bearer {regular_user_token}"}
    r1 = await async_client.get("/api/v1/admin/kyc/stats", headers=headers)
    assert r1.status_code == 403

    r2 = await async_client.get("/api/v1/admin/kyc/queue", headers=headers)
    assert r2.status_code == 403

@pytest.mark.asyncio
async def test_admin_decision_approves_and_purges_storage(async_client: AsyncClient, admin_token, db_session):
    """Confirm approval sets user status to verified and triggers hard video removal."""
    headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Seed candidate user and review queue record
    candidate = User(
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Vikas Dubey",
        dob="1998-07-12",
        gender="male",
        city="Kanpur",
        kyc_status=False,
        kyc_state="pending_manual_review"
    )
    db_session.add(candidate)
    await db_session.commit()
    await db_session.refresh(candidate)

    queue_entry = KycReviewQueue(
        user_id=candidate.id,
        video_storage_path=f"{candidate.id}/selfie.mp4",
        registered_name="Vikas Dubey",
        registered_city="Kanpur",
        extracted_transcript="Mera naam Vikas hai",
        ai_confidence_score=0.65,
        ai_flags=["face_detection_failed"],
        status="unreviewed"
    )
    db_session.add(queue_entry)
    await db_session.commit()
    await db_session.refresh(queue_entry)

    # 2. Execute decision with mocked storage client
    with patch("app.services.storage_service.supabase_storage_client.storage.from_") as mock_storage:
        mock_bucket = MagicMock()
        mock_storage.return_value = mock_bucket

        response = await async_client.post(
            "/api/v1/admin/kyc/review-decision",
            json={
                "queue_id": queue_entry.id,
                "user_id": str(candidate.id),
                "decision": "approve"
            },
            headers=headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["decision"] == "approve"
        assert data["video_purged_from_storage"] is True

        # Assert database user is now verified
        await db_session.refresh(candidate)
        assert candidate.kyc_status is True
        assert candidate.kyc_state == "verified"

        # Assert storage bucket remove method was called
        mock_bucket.remove.assert_called_once_with([f"{candidate.id}/selfie.mp4"])

    # Clean up
    await db_session.delete(queue_entry)
    await db_session.delete(candidate)
    await db_session.commit()

@pytest.mark.asyncio
async def test_admin_decision_rejects_and_purges_storage(async_client: AsyncClient, admin_token, db_session):
    """Confirm rejection sets user status to rejected and triggers hard video removal."""
    headers = {"Authorization": f"Bearer {admin_token}"}

    candidate = User(
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Rajesh Kumar",
        dob="1997-03-21",
        gender="male",
        city="Agra",
        kyc_status=False,
        kyc_state="pending_manual_review"
    )
    db_session.add(candidate)
    await db_session.commit()
    await db_session.refresh(candidate)

    queue_entry = KycReviewQueue(
        user_id=candidate.id,
        video_storage_path=f"{candidate.id}/selfie_reject.mp4",
        registered_name="Rajesh Kumar",
        registered_city="Agra",
        extracted_transcript="Mera naam Rajesh hai",
        ai_confidence_score=0.40,
        ai_flags=["transcript_mismatch"],
        status="unreviewed"
    )
    db_session.add(queue_entry)
    await db_session.commit()
    await db_session.refresh(queue_entry)

    with patch("app.services.storage_service.supabase_storage_client.storage.from_") as mock_storage:
        mock_bucket = MagicMock()
        mock_storage.return_value = mock_bucket

        response = await async_client.post(
            "/api/v1/admin/kyc/review-decision",
            json={
                "queue_id": queue_entry.id,
                "user_id": str(candidate.id),
                "decision": "reject",
                "rejection_reason": "Face does not match profile photos"
            },
            headers=headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["decision"] == "reject"
        assert data["video_purged_from_storage"] is True

        await db_session.refresh(candidate)
        assert candidate.kyc_status is False
        assert candidate.kyc_state == "rejected"
        assert candidate.kyc_failure_reason == "Face does not match profile photos"

        mock_bucket.remove.assert_called_once_with([f"{candidate.id}/selfie_reject.mp4"])

    # Clean up
    await db_session.delete(queue_entry)
    await db_session.delete(candidate)
    await db_session.commit()

@pytest.mark.asyncio
async def test_admin_dashboard_stats_and_queue(async_client: AsyncClient, admin_token):
    """Assert admin can fetch stats and queue successfully."""
    headers = {"Authorization": f"Bearer {admin_token}"}

    r_stats = await async_client.get("/api/v1/admin/kyc/stats", headers=headers)
    assert r_stats.status_code == 200
    stats_data = r_stats.json()
    assert "pending_count" in stats_data
    assert "verified_count" in stats_data
    assert "rejected_count" in stats_data

    r_queue = await async_client.get("/api/v1/admin/kyc/queue", headers=headers)
    assert r_queue.status_code == 200
    assert isinstance(r_queue.json(), list)
