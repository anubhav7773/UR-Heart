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
    assert data["status"] == "healthy"


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
    payload = {"receiver_id": "b1febc88-1c0b-4ef8-bb6d-6bb9bd380b22"}
    response = client.post("/api/v1/intent/send-chai-invite", json=payload, headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "invite_id" in json_resp["data"]


def test_whatsapp_bridge_status():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    response = client.get("/api/v1/chat/whatsapp-bridge-status/match_test_123", headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert json_resp["data"]["required_threshold"] == 15
    assert json_resp["data"]["is_whatsapp_unlocked"] is True


def test_create_sachet_order():
    payload = {"plan_type": "chai_invite"}
    response = client.post("/api/v1/payments/create-sachet-order", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert json_resp["data"]["amount_inr"] == 9.0
    assert json_resp["data"]["plan_type"] == "chai_invite"


def test_get_feed_micro_radius():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    response = client.get("/api/v1/feed?radius_km=5.0", headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    cards = json_resp["data"]["cards"]
    assert len(cards) >= 5
    profile_cards = [c["profile"] for c in cards if c["type"] == "profile"]
    assert len(profile_cards) > 0
    assert profile_cards[0]["is_verified_local"] is True
    assert "Near" in profile_cards[0]["distance_label"]


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


def test_upload_chat_media():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    files = {"file": ("test_chat_photo.jpg", b"fake_chat_media_bytes", "image/jpeg")}
    response = client.post("/api/v1/chat/upload-media", files=files, headers=headers)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "media_url" in json_resp["data"]
    assert "chat-media" in json_resp["data"]["media_url"]

