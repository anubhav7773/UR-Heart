import pytest
from uuid import uuid4
from datetime import date
from httpx import AsyncClient
from sqlalchemy import select, text

from app.models.domain.user import User
from app.models.domain.match import Match
from app.api.dependencies import get_current_user
from app.main import app


@pytest.mark.asyncio
async def test_location_catalog_endpoint(async_client: AsyncClient):
    response = await async_client.get("/api/v1/location/catalog")
    assert response.status_code == 200
    data = response.json()
    assert "Uttar Pradesh" in data
    assert "Lucknow" in data["Uttar Pradesh"]
    assert "Delhi NCR" in data
    assert "Maharashtra" in data


@pytest.mark.asyncio
async def test_whatsapp_reveal_requires_disclaimer(async_client: AsyncClient, auth_headers):
    # Missing disclaimer must fail with 400
    res = await async_client.post(
        "/api/v1/ads/reveal-whatsapp/00000000-0000-0000-0000-000000000000",
        json={"disclaimer_accepted": False},
        headers=auth_headers
    )
    assert res.status_code == 400
    assert "disclaimer must be accepted" in res.json()["detail"]


@pytest.mark.asyncio
async def test_whatsapp_reveal_logs_consent_and_unlocks(async_client: AsyncClient, db_session):
    # Setup User 1 and User 2
    u1 = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number="+919876543210",
        full_name="User One",
        dob=date(1996, 1, 1),
        gender="male",
        city="Lucknow",
        state="Uttar Pradesh",
        is_banned=False
    )
    u2 = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number="+919876543211",
        full_name="Partner Two",
        dob=date(1997, 2, 2),
        gender="female",
        city="Lucknow",
        state="Uttar Pradesh",
        is_banned=False
    )
    match = Match(
        id=uuid4(),
        user1_id=u1.id,
        user2_id=u2.id,
        whatsapp_unlocked=False
    )
    db_session.add(u1)
    db_session.add(u2)
    await db_session.flush()
    db_session.add(match)
    await db_session.commit()

    # Authenticate as User 1
    app.dependency_overrides[get_current_user] = lambda: u1

    reveal_res = await async_client.post(
        f"/api/v1/ads/reveal-whatsapp/{match.id}",
        json={"disclaimer_accepted": True},
        headers={
            "Authorization": "Bearer mock_u1_token",
            "X-Forwarded-For": "203.0.113.195",
            "User-Agent": "TestClient/1.0"
        }
    )
    assert reveal_res.status_code == 200
    body = reveal_res.json()
    assert body["status"] == "success"
    assert body["match_id"] == str(match.id)
    assert body["whatsapp_number"] == "+919876543211"
    assert "consent_logged_at" in body

    # Verify match unlocked in database
    await db_session.refresh(match)
    assert match.whatsapp_unlocked is True

    # Verify consent log written in PostgreSQL
    log_stmt = text(
        "SELECT user_id, partner_id, ip_address, disclaimer_accepted FROM public.consent_logs "
        "WHERE user_id = :uid AND partner_id = :pid"
    )
    log_res = await db_session.execute(log_stmt, {"uid": u1.id, "pid": u2.id})
    row = log_res.fetchone()
    assert row is not None
    assert row.user_id == u1.id
    assert row.partner_id == u2.id
    assert row.ip_address == "203.0.113.195"
    assert row.disclaimer_accepted is True

    app.dependency_overrides.pop(get_current_user, None)
