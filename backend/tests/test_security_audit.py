import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.sanitizer import sanitize_user_input
from app.core.rate_limiter import limiter

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_limiter_fixture():
    limiter.reset()
    yield
    limiter.reset()


def create_test_user_session(identifier: str):
    res = client.post(
        "/api/v1/auth/social-login",
        json={
            "provider": "google",
            "id_token": f"mock_token_{identifier}",
            "device_id": f"{identifier}",
            "fcm_token": f"fcm_{identifier}"
        },
        headers={"X-Device-Id": f"dev_{identifier}"}
    )
    assert res.status_code == 200
    data = res.json()["data"]
    return data["access_token"], data["user_id"]


import hmac
import hashlib
from app.core.config import settings

def setup_match_between_users(sender_token: str, recipient_user_id: str) -> str:
    headers = {"Authorization": f"Bearer {sender_token}"}
    pay_id = f"pay_test_{recipient_user_id[:8]}"
    order_id = f"order_test_{recipient_user_id[:8]}"
    secret = settings.RAZORPAY_KEY_SECRET or "sample_secret"
    sig = hmac.new(secret.encode("utf-8"), f"{order_id}|{pay_id}".encode("utf-8"), hashlib.sha256).hexdigest()
    # 1. Unlock Direct DM pass for sender
    verify_payload = {
        "razorpay_payment_id": pay_id,
        "razorpay_order_id": order_id,
        "razorpay_signature": sig,
        "plan_type": "PLAN_DIRECT_DM_49"
    }
    v_res = client.post("/api/v1/payments/verify", json=verify_payload, headers=headers)
    assert v_res.status_code == 200

    # 2. Send Direct DM to create conversation / match
    dm_payload = {
        "target_user_id": recipient_user_id,
        "message": "Private direct conversation message"
    }
    dm_res = client.post("/api/v1/feed/direct-dm", json=dm_payload, headers=headers)
    assert dm_res.status_code == 200
    return dm_res.json()["data"]["match_id"]


def test_idor_chat_snooping_blocked():
    """Verify User A (Attacker) cannot read messages between User B and User C."""
    token_a, user_a_id = create_test_user_session("attacker_alpha")
    token_b, user_b_id = create_test_user_session("victim_beta")
    token_c, user_c_id = create_test_user_session("victim_gamma")

    match_bc_id = setup_match_between_users(token_b, user_c_id)

    # Attacker User A attempts to read messages of match_bc_id
    headers_a = {"Authorization": f"Bearer {token_a}"}
    response = client.get(
        f"/api/v1/chat/messages/{match_bc_id}",
        headers=headers_a
    )
    assert response.status_code == 403
    assert "Access denied" in response.json()["detail"]


def test_idor_chat_sending_blocked():
    """Verify User A (Attacker) cannot inject/send messages into conversation between User B and User C."""
    token_a, user_a_id = create_test_user_session("attacker_alpha_2")
    token_b, user_b_id = create_test_user_session("victim_beta_2")
    token_c, user_c_id = create_test_user_session("victim_gamma_2")

    match_bc_id = setup_match_between_users(token_b, user_c_id)

    # Attacker User A attempts to send message into match_bc_id
    headers_a = {"Authorization": f"Bearer {token_a}"}
    payload = {
        "match_id": match_bc_id,
        "content": "Malicious injected message from User A",
    }
    response = client.post(
        "/api/v1/chat/messages",
        json=payload,
        headers=headers_a
    )
    assert response.status_code == 403
    assert "Access denied" in response.json()["detail"]


def test_feed_does_not_leak_raw_coordinates():
    """Verify Feed JSON response does not expose raw lat/lon fields."""
    token_a, user_a_id = create_test_user_session("feed_scanner_user")
    headers = {"Authorization": f"Bearer {token_a}"}
    response = client.get("/api/v1/feed", headers=headers)
    assert response.status_code == 200

    resp_json = response.json()
    feed_data = resp_json.get("data", {})
    cards = feed_data.get("cards", []) if isinstance(feed_data, dict) else []
    for card in cards:
        profile = card.get("profile")
        if profile:
            assert "latitude" not in profile, "Security Alert: Latitude leaked in Feed response!"
            assert "longitude" not in profile, "Security Alert: Longitude leaked in Feed response!"
            assert "distance_km" in profile, "distance_km must be present"


def test_xss_injection_sanitized():
    """Verify script tags in bio updates are escaped."""
    token_a, user_a_id = create_test_user_session("xss_tester_user")
    headers = {"Authorization": f"Bearer {token_a}"}
    payload = {"bio": "<script>alert('xss')</script> Hello!"}
    response = client.put("/api/v1/profile", json=payload, headers=headers)
    assert response.status_code == 200

    json_resp = response.json()
    updated_bio = json_resp.get("data", {}).get("bio") or json_resp.get("bio")
    assert "<script>" not in updated_bio
    assert "&lt;script&gt;" in updated_bio


def test_profile_other_user_no_coordinates_leak():
    """Verify viewing another user's profile does not leak raw GPS coordinates."""
    token_a, user_a_id = create_test_user_session("profile_viewer_user")
    token_b, user_b_id = create_test_user_session("profile_target_user")

    headers = {"Authorization": f"Bearer {token_a}"}
    response = client.get(f"/api/v1/profile?user_id={user_b_id}", headers=headers)
    assert response.status_code == 200

    profile_data = response.json().get("data", {})
    assert profile_data.get("latitude") is None
    assert profile_data.get("longitude") is None
    assert profile_data.get("phone_number") is None


def test_sanitizer_unit_defense():
    """Unit test sanitizer with various XSS vectors."""
    assert sanitize_user_input("<img src=x onerror=alert(1)>") == "&lt;img src=x onerror=alert(1)&gt;"
    assert sanitize_user_input("hello\x00world") == "helloworld"
    assert sanitize_user_input("   Normal Text   ") == "Normal Text"
    assert sanitize_user_input("<script>evil()</script>") == "&lt;script&gt;evil()&lt;/script&gt;"


def test_security_headers_present():
    """Verify standard security headers are attached on API responses."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("X-XSS-Protection") == "1; mode=block"
    assert "Strict-Transport-Security" in response.headers
    assert "Content-Security-Policy" in response.headers


def test_scanner_bot_blocked():
    """Verify automated scanning tools are blocked by middleware."""
    scanner_response = client.get("/health", headers={"User-Agent": "sqlmap/1.5.2#stable"})
    assert scanner_response.status_code == 403


from starlette.websockets import WebSocketDisconnect


def test_websocket_missing_token_rejected():
    """Verify WebSocket connection is rejected with 1008 if no token is passed."""
    with pytest.raises(WebSocketDisconnect) as excinfo:
        with client.websocket_connect("/api/v1/chat/ws/00000000-0000-0000-0000-000000000001"):
            pass
    assert excinfo.value.code == 1008


def test_websocket_invalid_token_rejected():
    """Verify WebSocket connection is rejected with 1008 if an invalid token is passed."""
    with pytest.raises(WebSocketDisconnect) as excinfo:
        with client.websocket_connect("/api/v1/chat/ws/00000000-0000-0000-0000-000000000001?token=invalid_token_xyz"):
            pass
    assert excinfo.value.code == 1008


def test_websocket_third_party_user_rejected():
    """Verify WebSocket connection is rejected with 1008 if user is not in match."""
    token_a, user_a_id = create_test_user_session("ws_attacker_a")
    token_b, user_b_id = create_test_user_session("ws_victim_b")
    token_c, user_c_id = create_test_user_session("ws_victim_c")

    match_bc_id = setup_match_between_users(token_b, user_c_id)

    # Attacker User A attempts to connect to match_bc room
    with pytest.raises(WebSocketDisconnect) as excinfo:
        with client.websocket_connect(f"/api/v1/chat/ws/{match_bc_id}?token={token_a}"):
            pass
    assert excinfo.value.code == 1008


def test_websocket_participant_accepted():
    """Verify authorized participant can connect to WebSocket successfully."""
    token_b, user_b_id = create_test_user_session("ws_participant_b")
    token_c, user_c_id = create_test_user_session("ws_participant_c")

    match_bc_id = setup_match_between_users(token_b, user_c_id)

    # Participant User B connects to match_bc room
    with client.websocket_connect(f"/api/v1/chat/ws/{match_bc_id}?token={token_b}") as websocket:
        websocket.send_json({"type": "typing", "is_typing": True})


def test_mass_assignment_privilege_escalation_blocked():
    """Verify malicious injection of is_admin, is_boosted, ad_free_until into profile update is ignored."""
    token, user_id = create_test_user_session("mass_assign_tester")
    headers = {"Authorization": f"Bearer {token}", "X-Device-Id": "mass_assign_tester"}

    malicious_payload = {
        "bio": "Legitimate updated bio text",
        "is_boosted": True,
        "is_admin": True,
        "ad_free_until": "2099-01-01T00:00:00Z"
    }

    # 1. Send update request
    res = client.put("/api/v1/profile", json=malicious_payload, headers=headers)
    assert res.status_code == 200
    res_data = res.json()
    assert res_data["success"] is True
    assert res_data["data"]["bio"] == "Legitimate updated bio text"
    assert res_data["data"]["is_admin"] is False
    assert res_data["data"]["is_boosted"] is False

    # 2. Query profile back and verify bio updated but privileged fields were NOT mutated
    get_res = client.get("/api/v1/profile/me", headers=headers)
    assert get_res.status_code == 200
    profile = get_res.json()["data"]

    assert profile["bio"] == "Legitimate updated bio text"
    assert profile.get("is_admin") is False
    assert profile.get("is_boosted", False) is False


def test_invalid_payment_signature_rejected():
    """Verify that forged or malformed HMAC signatures in /verify are strictly rejected with 400."""
    token, user_id = create_test_user_session("sig_verifier_user")
    headers = {"Authorization": f"Bearer {token}"}

    forged_payload = {
        "razorpay_payment_id": "pay_fake_123456",
        "razorpay_order_id": "order_fake_123456",
        "razorpay_signature": "forged_invalid_signature_hex",
        "plan_type": "PLAN_BOOST_29"
    }
    res = client.post("/api/v1/payments/verify", json=forged_payload, headers=headers)
    assert res.status_code == 400
    assert "Invalid payment signature" in res.json().get("detail", "")


def test_invalid_webhook_signature_rejected():
    """Verify that razorpay webhook requests with invalid or missing HMAC signatures are rejected with 400."""
    webhook_body = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": "pay_webhook_test_123",
                    "amount": 2900,
                    "currency": "INR"
                }
            }
        }
    }

    # 1. Missing signature header
    res_no_sig = client.post("/api/v1/payments/razorpay/webhook", json=webhook_body)
    assert res_no_sig.status_code == 400

    # 2. Forged signature header
    res_bad_sig = client.post(
        "/api/v1/payments/razorpay/webhook",
        json=webhook_body,
        headers={"X-Razorpay-Signature": "bad_hex_signature"}
    )
    assert res_bad_sig.status_code == 400
    assert "Invalid webhook signature" in res_bad_sig.json().get("detail", "")


@pytest.mark.asyncio
async def test_storage_engine_upload_failure_raises_502(monkeypatch):
    """Verify StorageEngineService raises 502 HTTPException when Supabase storage is unavailable or fails."""
    from app.services.storage_engine import StorageEngineService
    from fastapi import HTTPException
    from app.core.config import settings

    # Simulate unreachable/failing Supabase Storage endpoint
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://invalid-nonexistent-host.supabase.co")

    with pytest.raises(HTTPException) as excinfo:
        await StorageEngineService.upload_profile_photo(b"mock_raw_image_data", "test.jpg")
    assert excinfo.value.status_code == 502
    assert "Storage upload failed" in excinfo.value.detail

