import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def get_social_login_token() -> str:
    payload = {
        "provider": "google",
        "id_token": "mock_id_token_12345",
        "device_id": "device_test_99",
        "fcm_token": "fcm_test_token"
    }
    response = client.post("/api/v1/auth/social-login", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "access_token" in json_resp["data"]
    assert "user_id" in json_resp["data"]
    return json_resp["data"]["access_token"]


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("healthy", "online")


def test_social_login():
    token = get_social_login_token()
    assert token is not None


def test_profile_complete_unauthorized():
    payload = {
        "full_name": "Rahul Singh",
        "dob": "2002-03-26",
        "gender": "male",
        "interested_in": "female",
        "intent": "serious",
        "bio": "Simple guy from Ayodhya.",
        "area_name": "Sohawal, Ayodhya",
        "village_pin_code": "224189",
        "latitude": 26.7880,
        "longitude": 82.1300,
        "photos": [
            {"photo_url": "https://r2.ruralheart.com/p1.webp", "is_first_impression": True, "display_order": 1},
            {"photo_url": "https://r2.ruralheart.com/p2.webp", "is_first_impression": False, "display_order": 2},
            {"photo_url": "https://r2.ruralheart.com/p3.webp", "is_first_impression": False, "display_order": 3},
            {"photo_url": "https://r2.ruralheart.com/p4.webp", "is_first_impression": False, "display_order": 4},
            {"photo_url": "https://r2.ruralheart.com/p5.webp", "is_first_impression": False, "display_order": 5}
        ]
    }
    response = client.post("/api/v1/profile/complete", json=payload)
    assert response.status_code == 401
    json_resp = response.json()
    assert json_resp["success"] is False
    assert json_resp["error"]["code"] == "UNAUTHORIZED"


def test_profile_complete_authorized():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "full_name": "Rahul Singh",
        "dob": "2002-03-26",
        "gender": "male",
        "interested_in": "female",
        "intent": "serious",
        "bio": "Simple guy from Ayodhya.",
        "area_name": "Sohawal, Ayodhya",
        "village_pin_code": "224189",
        "latitude": 26.7880,
        "longitude": 82.1300,
        "photos": [
            {"photo_url": "https://r2.ruralheart.com/p1.webp", "is_first_impression": True, "display_order": 1},
            {"photo_url": "https://r2.ruralheart.com/p2.webp", "is_first_impression": False, "display_order": 2},
            {"photo_url": "https://r2.ruralheart.com/p3.webp", "is_first_impression": False, "display_order": 3},
            {"photo_url": "https://r2.ruralheart.com/p4.webp", "is_first_impression": False, "display_order": 4},
            {"photo_url": "https://r2.ruralheart.com/p5.webp", "is_first_impression": False, "display_order": 5}
        ]
    }
    response = client.post("/api/v1/profile/complete", json=payload, headers=headers)
    assert response.status_code == 201
    json_resp = response.json()
    assert json_resp["success"] is True
    assert json_resp["data"]["is_profile_complete"] is True


def test_send_otp():
    payload = {"phone_number": "+919876543210"}
    response = client.post("/api/v1/auth/send-otp", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "session_id" in json_resp["data"]


def test_verify_otp():
    payload = {
        "phone_number": "+919876543210",
        "otp_code": "123456",
        "device_id": "test_device_otp_1"
    }
    response = client.post("/api/v1/auth/verify-otp", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "access_token" in json_resp["data"]
    assert "user_id" in json_resp["data"]


def test_email_login():
    payload = {
        "email": "rahul.ayodhya@ruralheart.com",
        "password": "Password123!",
        "device_id": "test_device_email_1"
    }
    response = client.post("/api/v1/auth/email-login", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "access_token" in json_resp["data"]


def test_chai_status():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "is_free_for_chai": True,
        "status_badge": "☕ Free for Chai",
        "location_landmark": "Saket College Gate"
    }
    response = client.post("/api/v1/intent/chai-status", json=payload, headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert json_resp["data"]["is_free_for_chai"] is True


def test_send_chai_invite():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    res_target = client.post("/api/v1/auth/social-login", json={
        "provider": "google",
        "id_token": "mock_target_chai_token",
        "device_id": "device_target_chai_999",
        "fcm_token": "fcm_target_token"
    })
    target_id = res_target.json()["data"]["user_id"]
    payload = {"receiver_id": target_id}
    response = client.post("/api/v1/intent/send-chai-invite", json=payload, headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "invite_id" in json_resp["data"]


def test_create_sachet_order():
    # 1. PLAN_BOOST_29 (₹29)
    res1 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "PLAN_BOOST_29"})
    assert res1.status_code == 200
    assert res1.json()["data"]["amount_inr"] == 29.0
    assert res1.json()["data"]["plan_type"] == "PLAN_BOOST_29"

    # 2. PLAN_DIRECT_DM_49 (₹49)
    res2 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "PLAN_DIRECT_DM_49"})
    assert res2.status_code == 200
    assert res2.json()["data"]["amount_inr"] == 49.0
    assert res2.json()["data"]["plan_type"] == "PLAN_DIRECT_DM_49"

    # 3. PLAN_AD_FREE_199 (₹199)
    res3 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "PLAN_AD_FREE_199"})
    assert res3.status_code == 200
    assert res3.json()["data"]["amount_inr"] == 199.0
    assert res3.json()["data"]["plan_type"] == "PLAN_AD_FREE_199"

    # 4. PLAN_SAFE_BRIDGE_499 (₹499)
    res4 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "PLAN_SAFE_BRIDGE_499"})
    assert res4.status_code == 200
    assert res4.json()["data"]["amount_inr"] == 499.0
    assert res4.json()["data"]["plan_type"] == "PLAN_SAFE_BRIDGE_499"


def test_direct_dm_flow():
    # Sender user
    token1 = get_social_login_token()
    headers1 = {"Authorization": f"Bearer {token1}"}

    # Target user created via social login
    res_target = client.post("/api/v1/auth/social-login", json={
        "provider": "google",
        "id_token": "mock_target_id_token",
        "device_id": "device_target_user_888",
        "fcm_token": "fcm_target_token"
    })
    assert res_target.status_code == 200
    target_user_id = res_target.json()["data"]["user_id"]

    # 1. Attempt direct DM without active pass -> 403 Forbidden
    direct_dm_payload = {
        "target_user_id": target_user_id,
        "message": "Hello from direct DM!"
    }
    unauth_resp = client.post("/api/v1/feed/direct-dm", json=direct_dm_payload, headers=headers1)
    assert unauth_resp.status_code == 403

    # 2. Unlock ₹49 Direct DM Pass
    verify_payload = {
        "razorpay_payment_id": "pay_test_dm_49",
        "razorpay_order_id": "order_test_dm_49",
        "razorpay_signature": "mock_sig_valid",
        "plan_type": "PLAN_DIRECT_DM_49"
    }
    verify_resp = client.post("/api/v1/payments/verify", json=verify_payload, headers=headers1)
    assert verify_resp.status_code == 200
    assert verify_resp.json()["data"]["verified"] is True

    # 3. Check active-pass endpoint reflects active Direct DM pass
    pass_resp = client.get("/api/v1/payments/active-pass", headers=headers1)
    assert pass_resp.status_code == 200
    assert pass_resp.json()["data"]["is_direct_dm_active"] is True

    # 4. Attempt direct DM with active pass -> 200 OK
    auth_dm_resp = client.post("/api/v1/feed/direct-dm", json=direct_dm_payload, headers=headers1)
    assert auth_dm_resp.status_code == 200
    json_dm = auth_dm_resp.json()
    assert json_dm["success"] is True
    assert "match_id" in json_dm["data"]
    assert "message_id" in json_dm["data"]
    assert json_dm["data"]["content"] == "Hello from direct DM!"


def test_get_feed_micro_radius():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    response = client.get("/api/v1/feed?radius_km=500.0", headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "cards" in json_resp["data"]


def test_upload_profile_photo():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    files = {"file": ("test_photo.jpg", b"fake_image_bytes_content", "image/jpeg")}
    response = client.post("/api/v1/profile/photos", files=files, headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert "photo_url" in json_resp or (isinstance(json_resp.get("data"), dict) and "photo_url" in json_resp["data"])


def test_put_profile_optional_null_empty_fields():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "full_name": "",
        "dob": None,
        "gender": None,
        "interested_in": "",
        "intent": None,
        "bio": None,
        "area_name": "",
        "village_pin_code": None,
        "latitude": None,
        "longitude": None,
        "photos": None
    }
    response = client.put("/api/v1/profile", json=payload, headers=headers)
    assert response.status_code in (200, 201)
    json_resp = response.json()
    assert json_resp["success"] is True


def test_firebase_login():
    payload = {
        "id_token": "mock_firebase_id_token_12345",
        "device_id": "test_device_firebase_1"
    }
    response = client.post("/api/v1/auth/firebase-login", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "access_token" in json_resp["data"]
    assert "user_id" in json_resp["data"]


def test_chat_media_disabled_and_strictly_text_only():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    dummy_match_id = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"

    # 1. POST /chat/upload-media should be disabled and return 400
    files = {"file": ("test_chat_photo.jpg", b"fake_chat_media_bytes", "image/jpeg")}
    response = client.post("/api/v1/chat/upload-media", files=files, headers=headers)
    assert response.status_code == 400
    json_resp = response.json()
    assert json_resp["success"] is False
    assert "disabled" in json_resp["error"]["message"].lower()

    # 2. Sending chat message with media_url should be rejected with 400
    payload = {
        "match_id": dummy_match_id,
        "content": "Check this photo",
        "media_url": "https://r2.ruralheart.com/chat-media/photo.jpg",
        "media_type": "image"
    }
    msg_res = client.post("/api/v1/chat/messages", json=payload, headers=headers)
    assert msg_res.status_code == 400
    assert "disabled" in msg_res.json()["error"]["message"].lower()


def test_heuristic_content_filter():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    dummy_match_id = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"

    # Blocked test cases
    blocked_messages = [
        "anubhav8400",
        "priya_07",
        "a n u b h a v 8 4 0 0",
        "nine eight seven six five four three two one zero",
        "ek do teen char panch chhe saat aath nau zero",
        "insta id @priya",
        "Mera telegram join karo",
        "call me 9876543210",
        "location maps.google.com/xyz",
        "pincode 110001",
    ]

    for msg in blocked_messages:
        payload = {
            "match_id": dummy_match_id,
            "content": msg,
        }
        res = client.post("/api/v1/chat/messages", json=payload, headers=headers)
        assert res.status_code == 400, f"Expected 400 for blocked message: '{msg}', got {res.status_code}"
        json_data = res.json()
        assert json_data["success"] is False
        assert "Safe Bridge" in json_data["error"]["message"]

    # Allowed normal test cases
    allowed_messages = [
        "Hello, kaise ho aap?",
        "Mujhe music pasand hai.",
        "Aap kahan se ho?",
    ]

    for msg in allowed_messages:
        payload = {
            "match_id": dummy_match_id,
            "content": msg,
        }
        res = client.post("/api/v1/chat/messages", json=payload, headers=headers)
        assert res.status_code == 200, f"Expected 200 for allowed message: '{msg}', got {res.status_code}"
        assert res.json()["success"] is True


def test_get_conversations_and_matches():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}

    # Test /api/v1/chat/conversations
    res1 = client.get("/api/v1/chat/conversations", headers=headers)
    assert res1.status_code == 200
    json_data1 = res1.json()
    assert json_data1["success"] is True
    assert isinstance(json_data1["data"], list)

    # Test /api/v1/chat/matches
    res2 = client.get("/api/v1/chat/matches", headers=headers)
    assert res2.status_code == 200
    json_data2 = res2.json()
    assert json_data2["success"] is True
    assert isinstance(json_data2["data"], list)


