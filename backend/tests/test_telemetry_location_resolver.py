import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app


@pytest.mark.asyncio
async def test_resolve_client_ip_location_endpoint():
    """
    Verify that GET /api/v1/telemetry/resolve-location returns 200,
    valid non-zero coordinates, city, region, and formatted GPS verified string.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/api/v1/telemetry/resolve-location")
        assert res.status_code == 200
        data = res.json()
        assert data.get("is_success") is True
        assert isinstance(data.get("latitude"), (int, float))
        assert isinstance(data.get("longitude"), (int, float))
        assert data.get("latitude") != 0.0
        assert data.get("longitude") != 0.0
        assert "city" in data and len(data["city"]) > 0
        assert "· GPS Verified" in data.get("formatted_location", "")
