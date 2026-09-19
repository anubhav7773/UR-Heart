import pytest
from httpx import AsyncClient
from uuid import uuid4


@pytest.mark.asyncio
async def test_wallet_initial_balance(async_client: AsyncClient, auth_headers):
    response = await async_client.get("/api/v1/wallet/balance", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["dm_credits"] >= 0
    assert "night_farm_ads_today" in data
    assert data["night_farm_daily_cap"] == 18


@pytest.mark.asyncio
async def test_claim_reward_idempotency(async_client: AsyncClient, auth_headers):
    key = f"test_idem_{uuid4()}"
    payload = {
        "ad_tier": "10s",
        "reward_choice": "dm_credit",
        "idempotency_key": key
    }
    # First claim succeeds
    res1 = await async_client.post("/api/v1/wallet/claim-reward", json=payload, headers=auth_headers)
    assert res1.status_code == 200
    assert res1.json()["delta"] == 1

    # Second claim with identical key fails with 409
    res2 = await async_client.post("/api/v1/wallet/claim-reward", json=payload, headers=auth_headers)
    assert res2.status_code == 409


@pytest.mark.asyncio
async def test_spend_insufficient_balance_triggers_402(async_client: AsyncClient, auth_headers):
    # Try to spend more than available
    spend_payload = {
        "reward_type": "wa_reveal_token",
        "amount": 10
    }
    res = await async_client.post("/api/v1/wallet/spend", json=spend_payload, headers=auth_headers)
    assert res.status_code == 402
    assert "Insufficient" in res.json()["detail"]
