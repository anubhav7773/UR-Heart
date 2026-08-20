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


def test_email_signup_disposable_blocked():
    payload = {
        "email": "scammer@mailinator.com",
        "password": "Password123!",
        "full_name": "Fake User",
        "device_id": "test_device_fake_1"
    }
    response = client.post("/api/v1/auth/email-signup", json=payload)
    assert response.status_code == 400
    json_resp = response.json()
    assert "disposable" in json_resp["detail"].lower()


def test_email_login_unverified_blocked():
    payload = {
        "email": "unverified.user@gmail.com",
        "password": "Password123!",
        "device_id": "test_device_unverified_1"
    }
    response = client.post("/api/v1/auth/email-login", json=payload)
    assert response.status_code == 403
    json_resp = response.json()
    assert json_resp["detail"] == "Email not verified. Please check your inbox and verify your email address to log in."


def test_email_login_firebase_mock():
    payload = {
        "id_token": "mock_firebase_id_token_12345",
        "device_id": "test_device_email_1"
    }
    response = client.post("/api/v1/auth/email-login", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert "access_token" in json_resp["data"]


def test_admin_email_login_auto_verified():
    payload = {
        "email": "kshtriyaanubhav9120@gmail.com",
        "password": "AdminPassword123!",
        "device_id": "test_device_admin_1"
    }
    response = client.post("/api/v1/auth/email-login", json=payload)
    assert response.status_code == 200
    json_resp = response.json()
    assert json_resp["success"] is True
    assert json_resp["data"]["is_admin"] is True
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
    # 1. PLAN_BOOST_29 (₹29) / boost
    res1 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "boost", "amount": 29.0})
    assert res1.status_code == 200
    j1 = res1.json()
    assert j1["success"] is True
    assert j1["amount"] == 29.0
    assert j1["amount_in_paise"] == 2900
    assert j1["currency"] == "INR"
    assert "razorpay_key_id" in j1
    assert j1["order_id"].startswith("order_")
    assert j1["plan_type"] == "boost"
    assert "Profile Boost" in j1["description"]

    # 2. PLAN_DIRECT_DM_49 (₹49) / direct_dm
    res2 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "PLAN_DIRECT_DM_49"})
    assert res2.status_code == 200
    j2 = res2.json()
    assert j2["amount"] == 49.0
    assert j2["amount_in_paise"] == 4900
    assert j2["plan_type"] == "PLAN_DIRECT_DM_49"
    assert "Direct DM Pass" in j2["description"]

    # 3. PLAN_AD_FREE_199 (₹199) / zero_ads
    res3 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "zero_ads", "amount": 199.0})
    assert res3.status_code == 200
    j3 = res3.json()
    assert j3["amount"] == 199.0
    assert j3["amount_in_paise"] == 19900
    assert j3["plan_type"] == "zero_ads"
    assert "Zero Ads" in j3["description"]

    # 4. PLAN_SAFE_BRIDGE_499 (₹499) / safe_bridge
    res4 = client.post("/api/v1/payments/create-sachet-order", json={"plan_type": "safe_bridge", "amount": 499.0})
    assert res4.status_code == 200
    j4 = res4.json()
    assert j4["amount"] == 499.0
    assert j4["amount_in_paise"] == 49900
    assert j4["plan_type"] == "safe_bridge"
    assert "Safe Meet & WhatsApp Bridge" in j4["description"]


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


def test_unsend_chat_message():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    dummy_match_id = "00000000-0000-0000-0000-000000000001"

    # Send a message
    send_payload = {
        "match_id": dummy_match_id,
        "content": "Hello for unsend test",
    }
    send_res = client.post("/api/v1/chat/messages", json=send_payload, headers=headers)
    assert send_res.status_code == 200
    msg_id = send_res.json()["data"]["id"]

    # Unsend the message (DELETE /api/v1/chat/messages/{message_id})
    unsend_res = client.delete(f"/api/v1/chat/messages/{msg_id}", headers=headers)
    assert unsend_res.status_code == 200
    unsend_data = unsend_res.json()
    assert unsend_data["success"] is True
    assert unsend_data["data"]["is_deleted"] is True
    assert unsend_data["data"]["message_id"] == msg_id


def test_visitors_and_ghost_passers_flow():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}

    # Fetch visitors tray (GET /api/v1/profile/visitors)
    res = client.get("/api/v1/profile/visitors?limit=20", headers=headers)
    assert res.status_code == 200
    json_data = res.json()
    assert json_data["success"] is True
    assert "total_count" in json_data["data"]
    assert "visitors" in json_data["data"]
    assert isinstance(json_data["data"]["visitors"], list)


def test_direct_dm_sachet_unlock():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}

    target_user_id = "00000000-0000-0000-0000-000000000002"
    payload = {"target_user_id": target_user_id}

    # Unlock direct DM via sachet (POST /api/v1/payments/sachet/direct-dm)
    res = client.post("/api/v1/payments/sachet/direct-dm", json=payload, headers=headers)
    assert res.status_code == 200
    json_data = res.json()
    assert json_data["success"] is True
    data = json_data["data"]
def test_meetup_spot_message_validation_and_security():
    token = get_social_login_token()
    headers = {"Authorization": f"Bearer {token}"}
    dummy_match_id = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"

    # 1. Valid Meetup Spot message
    valid_spot_payload = {
        "match_id": dummy_match_id,
        "message_type": "meetup_spot",
        "metadata": {
            "spot_id": "osm_12345",
            "name": "Sharma Chai Tapri",
            "category": "Chai & Snacks",
            "distance_km": 3.4,
            "latitude": 28.6139,
            "longitude": 77.2090,
            "address": "Civil Lines, Ayodhya",
        }
    }
    res = client.post("/api/v1/chat/messages", json=valid_spot_payload, headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["message_type"] == "meetup_spot"
    assert data["content"] == "Suggested a meetup spot: Sharma Chai Tapri"
    assert data["metadata"]["name"] == "Sharma Chai Tapri"
    assert data["metadata"]["distance_km"] == 3.4

    # 2. Corrupted / Missing mandatory geometric fields -> 400
    invalid_spot_missing = {
        "match_id": dummy_match_id,
        "message_type": "meetup_spot",
        "metadata": {
            "name": "Incomplete Spot",
            # missing latitude, longitude, distance_km, category
        }
    }
    res_bad = client.post("/api/v1/chat/messages", json=invalid_spot_missing, headers=headers)
    assert res_bad.status_code == 400

    # 3. Coordinate out of bounds or distance > 50km ceiling -> 400
    invalid_spot_coords = {
        "match_id": dummy_match_id,
        "message_type": "meetup_spot",
        "metadata": {
            "name": "Too Far Spot",
            "category": "Restaurant",
            "latitude": 28.6139,
            "longitude": 77.2090,
            "distance_km": 85.0,  # Exceeds 50km hard ceiling
        }
    }
    res_far = client.post("/api/v1/chat/messages", json=invalid_spot_coords, headers=headers)
    assert res_far.status_code == 400

    # 4. Safe Bridge zero-bypass test: manual text containing phone / instagram / wa.me -> 400
    res_bypass = client.post("/api/v1/chat/messages", json={
        "match_id": dummy_match_id,
        "content": "Contact me on wa.me/919876543210 or insta @myhandle",
        "message_type": "text"
    }, headers=headers)
    assert res_bypass.status_code == 400


@pytest.mark.asyncio
async def test_user_location_update():
    from httpx import AsyncClient, ASGITransport
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        login_res = await ac.post("/api/v1/auth/social-login", json={
            "provider": "google",
            "id_token": "mock_id_token_12345",
            "device_id": "device_test_99",
            "fcm_token": "fcm_test_token"
        })
        assert login_res.status_code == 200
        token = login_res.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # 1. Update location via POST /api/v1/users/location
        payload = {"latitude": 26.7880, "longitude": 82.1300}
        res = await ac.post("/api/v1/users/location", json=payload, headers=headers)
        assert res.status_code == 200
        json_data = res.json()
        assert json_data["success"] is True
        assert json_data["data"]["latitude"] == 26.7880
        assert json_data["data"]["longitude"] == 82.1300

        # 2. Update location via PUT /api/v1/users/location
        payload2 = {"latitude": 26.7900, "longitude": 82.1350}
        res2 = await ac.put("/api/v1/users/location", json=payload2, headers=headers)
        assert res2.status_code == 200
        assert res2.json()["success"] is True

        # 3. Invalid location coords should return 422
        res_invalid = await ac.post("/api/v1/users/location", json={"latitude": 999.0, "longitude": 82.0}, headers=headers)
        assert res_invalid.status_code == 422


@pytest.mark.asyncio
async def test_profile_photo_upload_and_get():
    from httpx import AsyncClient, ASGITransport
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        login_res = await ac.post("/api/v1/auth/social-login", json={
            "provider": "google",
            "id_token": "mock_id_token_12345",
            "device_id": "device_test_99",
            "fcm_token": "fcm_test_token"
        })
        assert login_res.status_code == 200
        token = login_res.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Upload photo via POST /api/v1/profile/photos
        dummy_image = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9"
        files = {"file": ("test_photo.jpg", dummy_image, "image/jpeg")}
        res_upload = await ac.post("/api/v1/profile/photos", files=files, headers=headers)
        assert res_upload.status_code in (200, 201)
        upload_data = res_upload.json()
        photo_url = upload_data.get("photo_url") or (upload_data.get("data") and upload_data["data"].get("photo_url"))
        assert photo_url is not None
        assert len(photo_url) > 0

        # 2. Get profile via GET /api/v1/profile and verify photo is returned
        res_profile = await ac.get("/api/v1/profile", headers=headers)
        assert res_profile.status_code == 200
        p_data = res_profile.json()["data"]
        assert "photos" in p_data
        assert len(p_data["photos"]) >= 1
        assert p_data["photos"][0] == photo_url






