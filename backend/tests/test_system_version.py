import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_get_app_version():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/system/app-version")
    
    assert response.status_code == 200
    json_data = response.json()
    assert json_data["success"] is True
    assert "data" in json_data
    data = json_data["data"]
    assert "latest_version" in data and len(data["latest_version"].split(".")) == 3
    assert data["min_required_version"] == "1.0.0"
    assert data["force_update"] is False
    assert data["is_force_update"] is False
    assert "https://github.com/anubhav7773/UR-Heart/releases/download/" in data["apk_url"]
