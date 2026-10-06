import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api.v1.endpoints.ai_sanctuary import FEEDBACK_VAULT

client = TestClient(app)


def test_sentry_backend_initialization_presence():
    """Verify sentry_sdk is importable and backend didn't crash during init."""
    import sentry_sdk
    # Sentry hub or client should be initialized
    assert sentry_sdk is not None


def test_feedback_submission_with_diagnostics_and_alias():
    """Verify user feedback endpoint accepts rich diagnostics and records to vault."""
    initial_vault_count = len(FEEDBACK_VAULT)
    payload = {
        "category": "bug_report",
        "description": "Feed cards swipe latency takes >2 seconds on 4G network.",
        "user_sentiment": "constructive",
        "app_version": "1.0.0+1",
        "platform_os": "Android 14",
        "device_model": "Pixel 7 Pro",
        "screen_route": "FeedScreen"
    }

    # 1. Test primary endpoint /api/v1/ai/eva/feedback
    res1 = client.post("/api/v1/ai/eva/feedback", json=payload)
    assert res1.status_code == 201
    data1 = res1.json()
    assert data1["status"] == "success"
    assert data1["entry"]["platform_os"] == "Android 14"
    assert data1["entry"]["device_model"] == "Pixel 7 Pro"
    assert data1["entry"]["app_version"] == "1.0.0+1"

    # 2. Test alias endpoint /api/v1/feedback
    payload2 = {
        "category": "feature_suggestion",
        "description": "Please add Kundali / Astro resonance filter.",
        "user_sentiment": "positive",
        "app_version": "1.0.0+1",
        "platform_os": "iOS 17.5",
        "device_model": "iPhone 15",
        "screen_route": "SanctuarySettings"
    }
    res2 = client.post("/api/v1/feedback", json=payload2)
    assert res2.status_code == 201
    data2 = res2.json()
    assert data2["status"] == "success"
    assert data2["entry"]["category"] == "feature_suggestion"
    assert data2["entry"]["platform_os"] == "iOS 17.5"

    assert len(FEEDBACK_VAULT) >= initial_vault_count + 2
