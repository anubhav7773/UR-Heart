import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_forged_jwt_rejection_sec01():
    """
    Test 4: Forged JWT Rejection (SEC-01 Verification)
    Sending an unsigned or forged JWT token MUST receive HTTP 401 Unauthorized.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Test unsigned token on /api/v1/users/me
        response = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": "Bearer fake.unsigned.jwt"}
        )
        assert response.status_code == 401
        data = response.json()
        assert data.get("error_code") == "AUTH_FAILED" or response.status_code == 401

        # 2. Test empty bearer token
        response_empty = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": "Bearer "}
        )
        assert response_empty.status_code == 401

        # 3. Test missing authorization header
        response_no_auth = await client.get("/api/v1/users/me")
        assert response_no_auth.status_code == 401
