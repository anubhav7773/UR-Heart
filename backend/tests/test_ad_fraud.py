import pytest
import pytest_asyncio
from httpx import AsyncClient

@pytest_asyncio.fixture
async def test_auth_headers(auth_headers):
    yield auth_headers

@pytest.mark.asyncio
async def test_app_ads_txt_endpoint(async_client: AsyncClient):
    response = await async_client.get("/app-ads.txt")
    assert response.status_code == 200
    assert "google.com" in response.text
    assert "pub-3940256099942544" in response.text
    assert "applovin.com" in response.text

@pytest.mark.asyncio
async def test_privacy_policy_ad_disclosure(async_client: AsyncClient):
    response = await async_client.get("/api/v1/legal/policies/privacy")
    assert response.status_code == 200
    content = response.json().get("content", "")
    assert "THIRD-PARTY ADVERTISING NETWORKS & MONETIZATION" in content
    assert "Google AdMob" in content
    assert "AppLovin" in content

@pytest.mark.asyncio
async def test_ad_claim_24h_rate_limit(async_client: AsyncClient, test_auth_headers):
    # Simulate 7 successful claims
    for _ in range(7):
        res = await async_client.post(
            "/api/v1/wallet/claim-reward",
            json={"ad_tier": "10s", "reward_choice": "dm_credit"},
            headers=test_auth_headers
        )
        assert res.status_code == 200

    # 8th claim must be blocked by HTTP 429
    blocked_res = await async_client.post(
        "/api/v1/wallet/claim-reward",
        json={"ad_tier": "10s", "reward_choice": "dm_credit"},
        headers=test_auth_headers
    )
    assert blocked_res.status_code == 429
    assert "Daily ad reward limit reached" in blocked_res.json()["detail"]
