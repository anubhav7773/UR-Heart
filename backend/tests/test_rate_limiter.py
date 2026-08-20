import pytest
import time
from fastapi.testclient import TestClient
from app.main import app
from app.core.rate_limiter import limiter, UnifiedRateLimiter

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_limiter():
    """Reset rate limiter state before each test."""
    limiter.reset()
    yield
    limiter.reset()


@pytest.mark.asyncio
async def test_sliding_window_in_memory_rate_limiter():
    """Verify in-memory sliding window allows max_requests and rejects max_requests + 1."""
    test_limiter = UnifiedRateLimiter()
    test_limiter.redis_client = None  # Force in-memory fallback
    test_limiter.reset()

    identifier = "test_user_123:/feed"
    max_reqs = 3
    window_secs = 2

    # First 3 requests should pass
    for _ in range(max_reqs):
        allowed = await test_limiter.check_rate_limit(identifier, max_reqs, window_secs)
        assert allowed is True

    # 4th request must be rejected
    allowed = await test_limiter.check_rate_limit(identifier, max_reqs, window_secs)
    assert allowed is False

    # Simulate waiting past the sliding window
    time.sleep(2.1)

    # 5th request after expiry must be accepted
    allowed = await test_limiter.check_rate_limit(identifier, max_reqs, window_secs)
    assert allowed is True


def test_auth_endpoint_rate_limiting():
    """Verify making 6 rapid calls to auth endpoints triggers HTTP 429 on the 6th call."""
    payload = {
        "provider": "google",
        "id_token": "mock_rate_limit_token",
        "device_id": "rate_limiter_device",
        "fcm_token": "rate_limiter_fcm"
    }

    # First 5 calls allowed (5 req / 60s limit)
    for i in range(5):
        res = client.post("/api/v1/auth/social-login", json=payload)
        assert res.status_code == 200, f"Request {i+1} failed with {res.status_code}: {res.text}"

    # 6th call must return 429 Too Many Requests
    res_blocked = client.post("/api/v1/auth/social-login", json=payload)
    assert res_blocked.status_code == 429
    res_data = res_blocked.json()
    assert "Too many requests" in (res_data.get("detail") or res_data.get("error", {}).get("message", ""))
    assert "Retry-After" in res_blocked.headers


def test_payments_endpoint_rate_limiting():
    """Verify making 11 rapid calls to payments endpoints triggers HTTP 429 on the 11th call."""
    payload = {
        "plan_type": "PLAN_BOOST_29",
        "amount": 29.0
    }

    # First 10 calls allowed (10 req / 60s limit)
    for i in range(10):
        res = client.post("/api/v1/payments/create-order", json=payload)
        assert res.status_code == 200, f"Request {i+1} failed with {res.status_code}: {res.text}"

    # 11th call must return 429 Too Many Requests
    res_blocked = client.post("/api/v1/payments/create-order", json=payload)
    assert res_blocked.status_code == 429
    assert "Retry-After" in res_blocked.headers
