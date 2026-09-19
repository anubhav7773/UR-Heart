import pytest
from httpx import AsyncClient
from uuid import uuid4
from datetime import date
from app.main import app
from app.api.dependencies import get_current_user
from app.models.domain.user import User

@pytest.mark.asyncio
async def test_non_admin_cannot_access_kyc_stats(async_client: AsyncClient, regular_user_auth_headers):
    response = await async_client.get("/api/v1/admin/kyc/stats", headers=regular_user_auth_headers)
    assert response.status_code == 403
    assert "Administrative access denied" in response.json()["detail"]

@pytest.mark.asyncio
async def test_non_admin_cannot_access_kyc_queue(async_client: AsyncClient, regular_user_auth_headers):
    response = await async_client.get("/api/v1/admin/kyc/queue", headers=regular_user_auth_headers)
    assert response.status_code == 403
    assert "Administrative access denied" in response.json()["detail"]

@pytest.mark.asyncio
async def test_imposter_super_admin_rejected_by_whitelist(async_client: AsyncClient):
    """If a rogue user has is_super_admin=True in DB but unauthorized email, hard whitelist must reject with 403."""
    imposter = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Imposter Admin",
        dob=date(1995, 1, 1),
        gender="male",
        city="Lucknow",
        bio="Hacker trying to bypass",
        is_super_admin=True,
        is_banned=False,
    )
    # Set imposter email
    imposter.email = "imposter@example.com"

    app.dependency_overrides[get_current_user] = lambda: imposter
    try:
        response = await async_client.get(
            "/api/v1/admin/kyc/stats",
            headers={"Authorization": "Bearer mock_imposter_token"}
        )
        assert response.status_code == 403
        assert "statutory Master Admin whitelist" in response.json()["detail"]
    finally:
        app.dependency_overrides.pop(get_current_user, None)

@pytest.mark.asyncio
async def test_statutory_master_admin_access_granted(async_client: AsyncClient):
    """The verified master admin with whitelisted email has full access to KYC stats and queue."""
    master_admin = User(
        id=uuid4(),
        firebase_uid=str(uuid4()),
        phone_number=f"+9198{str(uuid4().int)[:8]}",
        whatsapp_number=f"+9198{str(uuid4().int)[:8]}",
        full_name="Anubhav Singh",
        dob=date(1995, 1, 1),
        gender="male",
        city="Lucknow",
        bio="ASI Verticals Master Admin",
        is_super_admin=True,
        is_banned=False,
    )
    master_admin.email = "kshtriyaanubhav9120@gmail.com"

    app.dependency_overrides[get_current_user] = lambda: master_admin
    try:
        r_stats = await async_client.get(
            "/api/v1/admin/kyc/stats",
            headers={"Authorization": "Bearer mock_master_token"}
        )
        assert r_stats.status_code == 200

        r_queue = await async_client.get(
            "/api/v1/admin/kyc/queue",
            headers={"Authorization": "Bearer mock_master_token"}
        )
        assert r_queue.status_code == 200
    finally:
        app.dependency_overrides.pop(get_current_user, None)
