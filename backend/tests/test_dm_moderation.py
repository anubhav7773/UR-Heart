import pytest
from uuid import uuid4
from datetime import date
from httpx import AsyncClient
from sqlalchemy import select

from app.services.text_moderation_service import validate_direct_dm_content
from app.models.domain.user import User
from app.models.domain.wallet import UserWallet
from app.api.dependencies import get_current_user
from app.main import app


def test_moderation_blocks_abusive_language():
    # Abusive words must be blocked
    is_valid, reason = validate_direct_dm_content("Hey send nudes now")
    assert is_valid is False
    assert "abusive or explicit" in reason


def test_moderation_blocks_external_links():
    # External URLs must be blocked
    is_valid, reason = validate_direct_dm_content("Check my profile at https://t.me/fakeuser")
    assert is_valid is False
    assert "External links" in reason


def test_moderation_approves_safe_intro():
    # Safe text must pass
    is_valid, reason = validate_direct_dm_content("Hello! Loved your bio about classical literature.")
    assert is_valid is True
    assert reason == "Approved"


def test_moderation_blocks_phone_numbers():
    # Phone numbers and contact leaks must be blocked
    is_valid, reason = validate_direct_dm_content("Call me on my private number 9876543210")
    assert is_valid is False
    assert "phone numbers" in reason.lower()


@pytest.mark.asyncio
async def test_send_direct_dm_blocked_by_moderation(async_client: AsyncClient, auth_headers, test_user):
    target_id = uuid4()
    # Attempting to send abusive content must return HTTP 422
    response = await async_client.post(
        "/api/v1/chat/send-direct-dm",
        json={
            "target_user_id": str(target_id),
            "content": "Hey bitch hookup with me"
        },
        headers=auth_headers
    )
    assert response.status_code == 422
    assert "abusive or explicit" in response.json()["detail"]


@pytest.mark.asyncio
async def test_report_and_block_auto_bans_sender_and_subsequent_dm_is_403(
    async_client: AsyncClient,
    db_session
):
    # Setup Sender and Recipient
    sender = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Abusive Sender",
        dob=date(1996, 2, 2),
        gender="male",
        city="Delhi",
        is_dm_banned=False,
        is_banned=False
    )
    recipient = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Protected Recipient",
        dob=date(1998, 4, 4),
        gender="female",
        city="Delhi",
        is_dm_banned=False,
        is_banned=False
    )
    db_session.add(sender)
    db_session.add(recipient)
    await db_session.commit()

    # Ensure sender has credits
    w_stmt = select(UserWallet).where(UserWallet.user_id == sender.id)
    w_res = await db_session.execute(w_stmt)
    wallet = w_res.scalar_one_or_none()
    if wallet:
        wallet.dm_credits = 10
    else:
        db_session.add(UserWallet(user_id=sender.id, dm_credits=10))
    await db_session.commit()

    # Recipient reports and blocks Sender
    app.dependency_overrides[get_current_user] = lambda: recipient
    report_res = await async_client.post(
        "/api/v1/safety/report-and-block",
        json={
            "reported_user_id": str(sender.id),
            "report_type": "direct_dm_abuse",
            "message_snippet": "Inappropriate direct message"
        },
        headers={"Authorization": "Bearer mock_recipient_token"}
    )
    assert report_res.status_code == 200
    assert report_res.json()["action"] == "user_blocked_and_dm_banned"

    # Confirm sender is auto-banned in database
    await db_session.refresh(sender)
    assert sender.is_dm_banned is True
    assert sender.dm_banned_at is not None

    # Sender attempts to send a Direct DM -> must return HTTP 403
    app.dependency_overrides[get_current_user] = lambda: sender
    dm_res = await async_client.post(
        "/api/v1/chat/send-direct-dm",
        json={
            "target_user_id": str(recipient.id),
            "content": "Hello again nice to meet you"
        },
        headers={"Authorization": "Bearer mock_sender_token"}
    )
    assert dm_res.status_code == 403
    assert "Direct DM privilege has been suspended" in dm_res.json()["detail"]

    # Cleanup overrides
    app.dependency_overrides.pop(get_current_user, None)
