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
    assert data["keep_alive"] is True
    assert "uptime_seconds" in data
    assert response.headers.get("X-Render-KeepAlive") == "active"
    assert "no-cache" in response.headers.get("Cache-Control", "")

def test_health_check_head_method():
    """Confirms HEAD /api/v1/health and HEAD /health return HTTP 200 for UptimeRobot."""
    resp_v1 = client.head("/api/v1/health")
    assert resp_v1.status_code == 200
    assert resp_v1.headers.get("X-Render-KeepAlive") == "active"

    resp_root = client.head("/health")
    assert resp_root.status_code == 200
    assert resp_root.headers.get("X-Render-KeepAlive") == "active"

def test_ping_endpoint_get_and_head():
    """Confirms /ping supports ultra-fast GET and HEAD keepalives for UptimeRobot."""
    resp_get = client.get("/ping")
    assert resp_get.status_code == 200
    assert resp_get.text == "pong"
    assert resp_get.headers.get("X-Render-KeepAlive") == "active"

    resp_head = client.head("/ping")
    assert resp_head.status_code == 200
    assert resp_head.headers.get("X-Render-KeepAlive") == "active"

def test_root_endpoint_get_and_head():
    """Confirms root / endpoint supports GET and HEAD methods."""
    resp_get = client.get("/")
    assert resp_get.status_code == 200
    assert resp_get.json()["status"] == "online"

    resp_head = client.head("/")
    assert resp_head.status_code == 200

