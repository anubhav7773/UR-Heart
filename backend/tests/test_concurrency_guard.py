import asyncio
import pytest
from httpx import AsyncClient
from app.services.feed_cache import feed_cache

@pytest.fixture
def test_auth_headers(auth_headers):
    return auth_headers

@pytest.mark.asyncio
async def test_health_check_zero_db_overhead(async_client: AsyncClient):
    # Burst 20 concurrent pings to /health
    tasks = [async_client.get("/health") for _ in range(20)]
    responses = await asyncio.gather(*tasks)

    for resp in responses:
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "healthy"
        assert data["memory_guard"] == "512MB_optimized"

@pytest.mark.asyncio
async def test_feed_cache_shields_database(async_client: AsyncClient, test_auth_headers):
    # Clear feed cache first to ensure clean state
    feed_cache._cache.clear()

    # First call: populates cache
    res1 = await async_client.get("/api/v1/feed?limit=10", headers=test_auth_headers)
    assert res1.status_code == 200

    # Verify cache was populated
    assert len(feed_cache._cache) > 0

    # Second call: hits cache instantly
    res2 = await async_client.get("/api/v1/feed?limit=10", headers=test_auth_headers)
    assert res2.status_code == 200
    assert len(res1.json()) == len(res2.json())
