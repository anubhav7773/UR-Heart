from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check_endpoint():
    """Confirms /api/v1/health returns HTTP 200 operational and memory metrics."""
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "operational"
    assert data["app_name"] == "UR-Heart"
    assert "memory_consumption_mb" in data
    assert data["memory_consumption_mb"] < 512.0
