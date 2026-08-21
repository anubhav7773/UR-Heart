import pytest
from starlette.testclient import TestClient
from app.main import app
from tests.test_security_audit import create_test_user_session

client = TestClient(app)


def test_verify_google_play_missing_fields():
    token, user_id = create_test_user_session("gplay_user_1")
    headers = {"Authorization": f"Bearer {token}"}

    # Missing purchase_token
    res = client.post("/api/v1/payments/verify-google-play", json={
        "purchase_token": "",
        "product_id": "sachet_boost_29"
    }, headers=headers)
    assert res.status_code == 400

    # Missing product_id
    res = client.post("/api/v1/payments/verify-google-play", json={
        "purchase_token": "valid_token_123",
        "product_id": ""
    }, headers=headers)
    assert res.status_code == 400


def test_verify_google_play_boost_29():
    token, user_id = create_test_user_session("gplay_user_boost")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post("/api/v1/payments/verify-google-play", json={
        "purchase_token": "gplay_token_boost_12345",
        "product_id": "sachet_boost_29",
        "package_name": "com.ruralheart.urheart"
    }, headers=headers)

    assert res.status_code == 200
    data = res.json()["data"]
    assert data["status"] == "success"
    assert data["activated"] is True
    assert data["plan_type"] == "PLAN_BOOST_29"

    # Check active pass status
    pass_res = client.get("/api/v1/payments/active-pass", headers=headers)
    assert pass_res.status_code == 200
    pass_data = pass_res.json()["data"]
    assert pass_data["is_boosted"] is True


def test_verify_google_play_direct_dm_49():
    token, user_id = create_test_user_session("gplay_user_dm")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post("/api/v1/payments/verify-google-play", json={
        "purchase_token": "gplay_token_dm_12345",
        "product_id": "sachet_direct_dm_49",
        "package_name": "com.ruralheart.urheart"
    }, headers=headers)

    assert res.status_code == 200
    data = res.json()["data"]
    assert data["status"] == "success"
    assert data["activated"] is True
    assert data["plan_type"] == "PLAN_DIRECT_DM_49"


def test_verify_google_play_vip_ad_free_199():
    token, user_id = create_test_user_session("gplay_user_vip")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post("/api/v1/payments/verify-google-play", json={
        "purchase_token": "gplay_token_vip_12345",
        "product_id": "vip_ad_free_199",
        "package_name": "com.ruralheart.urheart"
    }, headers=headers)

    assert res.status_code == 200
    data = res.json()["data"]
    assert data["status"] == "success"
    assert data["activated"] is True
    assert data["plan_type"] == "PLAN_AD_FREE_199"


def test_verify_google_play_safe_bridge_499():
    token, user_id = create_test_user_session("gplay_user_bridge")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post("/api/v1/payments/verify-google-play", json={
        "purchase_token": "gplay_token_bridge_12345",
        "product_id": "safe_bridge_499",
        "package_name": "com.ruralheart.urheart"
    }, headers=headers)

    assert res.status_code == 200
    data = res.json()["data"]
    assert data["status"] == "success"
    assert data["activated"] is True
    assert data["plan_type"] == "PLAN_SAFE_BRIDGE_499"
