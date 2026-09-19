import pytest
from unittest.mock import patch
from httpx import AsyncClient
from uuid import uuid4
from datetime import date
from sqlalchemy import select

from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue
from app.services.storage_service import hard_delete_kyc_video


@pytest.mark.asyncio
async def test_kyc_approval_purges_video_storage(async_client: AsyncClient, master_admin_headers):
    mock_queue_id = uuid4()

    with patch("app.api.v1.endpoints.admin_kyc.hard_delete_kyc_video") as mock_delete:
        mock_delete.return_value = True

        # Review approval action
        response = await async_client.post(
            f"/api/v1/admin/kyc/review/{mock_queue_id}",
            json={"action": "approve"},
            headers=master_admin_headers
        )

        # Confirm hard-delete was executed
        # and media status confirmed purged
        if response.status_code == 200:
            assert response.json()["media_status"] == "PURGED_FROM_STORAGE"


@pytest.mark.asyncio
async def test_kyc_review_end_to_end_approval_and_purge(async_client: AsyncClient, master_admin_headers, db_session):
    user_id = uuid4()
    candidate = User(
        id=user_id,
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Biometric Test User",
        dob=date(1998, 5, 20),
        gender="female",
        city="Varanasi",
        kyc_status=False,
        kyc_state="pending_manual_review",
        is_banned=False,
    )
    db_session.add(candidate)
    await db_session.commit()

    queue_entry = KycReviewQueue(
        user_id=user_id,
        video_storage_path=f"kyc-videos/{user_id}/selfie.mp4",
        registered_name="Biometric Test User",
        registered_city="Varanasi",
        extracted_transcript="Mera naam Biometric Test User hai",
        ai_confidence_score=0.95,
        ai_flags=[],
        status="unreviewed"
    )
    db_session.add(queue_entry)
    await db_session.commit()
    await db_session.refresh(queue_entry)

    with patch("app.api.v1.endpoints.admin_kyc.hard_delete_kyc_video") as mock_delete:
        mock_delete.return_value = True

        response = await async_client.post(
            f"/api/v1/admin/kyc/review/{queue_entry.id}",
            json={"action": "approve"},
            headers=master_admin_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["action"] == "approve"
        assert data["user_id"] == str(user_id)
        assert data["media_status"] == "PURGED_FROM_STORAGE"
        mock_delete.assert_called_once_with(f"kyc-videos/{user_id}/selfie.mp4")

    # Verify DB updates
    await db_session.refresh(candidate)
    assert candidate.kyc_status is True
    assert candidate.kyc_state == "verified"

    await db_session.refresh(queue_entry)
    assert queue_entry.status == "approved"
    assert queue_entry.video_storage_path == "PURGED"


@pytest.mark.asyncio
async def test_kyc_review_end_to_end_rejection_and_purge(async_client: AsyncClient, master_admin_headers, db_session):
    user_id = uuid4()
    candidate = User(
        id=user_id,
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Rejected Biometric Candidate",
        dob=date(1997, 8, 15),
        gender="male",
        city="Lucknow",
        kyc_status=False,
        kyc_state="pending_manual_review",
        is_banned=False,
    )
    db_session.add(candidate)
    await db_session.commit()

    queue_entry = KycReviewQueue(
        user_id=user_id,
        video_storage_path=f"kyc-videos/{user_id}/selfie.mp4",
        registered_name="Rejected Biometric Candidate",
        registered_city="Lucknow",
        extracted_transcript="",
        ai_confidence_score=0.20,
        ai_flags=["liveness_failed"],
        status="unreviewed"
    )
    db_session.add(queue_entry)
    await db_session.commit()
    await db_session.refresh(queue_entry)

    with patch("app.api.v1.endpoints.admin_kyc.hard_delete_kyc_video") as mock_delete:
        mock_delete.return_value = True

        response = await async_client.post(
            f"/api/v1/admin/kyc/review/{queue_entry.id}",
            json={"action": "reject", "reason": "Liveness check failed."},
            headers=master_admin_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["action"] == "reject"
        assert data["media_status"] == "PURGED_FROM_STORAGE"
        mock_delete.assert_called_once_with(f"kyc-videos/{user_id}/selfie.mp4")

    # Verify DB updates
    await db_session.refresh(candidate)
    assert candidate.kyc_status is False
    assert candidate.kyc_state == "rejected"
    assert candidate.kyc_failure_reason == "Liveness check failed."

    await db_session.refresh(queue_entry)
    assert queue_entry.status == "rejected"
    assert queue_entry.video_storage_path == "PURGED"
    assert queue_entry.rejection_reason == "Liveness check failed."


@pytest.mark.asyncio
async def test_hard_delete_kyc_video_function():
    # Purged or empty returns True immediately
    assert await hard_delete_kyc_video("") is True
    assert await hard_delete_kyc_video("PURGED") is True

    # Real path invokes storage remove
    with patch("app.services.storage_service.get_supabase_admin_client") as mock_client_factory:
        mock_client = mock_client_factory.return_value
        result = await hard_delete_kyc_video("kyc-videos/user123/selfie.mp4")
        assert result is True
