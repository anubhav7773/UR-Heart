# REST & WebSocket API Specification

**Product Name:** Project RuralHeart  
**Document Version:** 2.0.0 (High-Intent Quick Meetup, WhatsApp Bridge & Sachet Payments Update)  
**Base URL:** `https://api.ruralheart.com/api/v1`  
**Protocol:** HTTPS (REST) & WSS (WebSockets)  
**Authentication Scheme:** Bearer Token (JWT via `Authorization: Bearer <TOKEN>`)  

---

## 1. Global Error Response Standard

All endpoints return errors in a uniform JSON structure:

```json
{
  "success": false,
  "error": {
    "code": "WHATSAPP_LOCKED",
    "message": "Send at least 15 mutual messages to unlock direct contact exchange.",
    "details": {
      "current_message_count": 8,
      "required_message_count": 15
    }
  },
  "timestamp": "2026-08-12T12:00:00Z"
}

Common HTTP Status Codes
200 OK - Request succeeded.

201 Created - Resource created successfully.

400 Bad Request - Invalid payload or missing parameters.

401 Unauthorized - Missing or expired JWT token.

403 Forbidden - Feature locked behind payment paywall.

429 Too Many Requests - Rate limit exceeded.

500 Internal Server Error - Backend exception.

2. Module 1: Authentication & Profile Onboarding
2.1 Multi-Option Login (Social SSO / Mobile OTP / Email)
Authenticates credentials or phone OTP and returns JWT session tokens.

Endpoint: POST /auth/login

Auth Required: No

Request Body (Mobile OTP Example)
{
  "auth_type": "phone_otp",
  "phone_number": "+919876543210",
  "otp_code": "5678",
  "device_id": "android_a1b2c3d4e5",
  "fcm_token": "fcm_push_token_sample_123"
}

Response (200 OK)
{
  "success": true,
  "data": {
    "user_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "Bearer",
    "expires_in": 1296000,
    "is_profile_complete": true,
    "is_premium": false
  }
}

2.2 Complete Profile Onboarding
Submits user metadata, 5 photo URLs, and GPS location during initial onboarding.

Endpoint: POST /profile/complete

Auth Required: Yes (Bearer Token)

Request Body
{
  "full_name": "Rahul Singh",
  "dob": "2002-03-26",
  "gender": "male",
  "interested_in": "female",
  "intent": "serious",
  "chai_status": "free_for_chai",
  "bio": "Simple guy from Ayodhya. Love photography and standard tea.",
  "area_name": "Sohawal, Ayodhya",
  "village_pin_code": "224189",
  "latitude": 26.7880,
  "longitude": 82.1300,
  "photos": [
    { "photo_url": "[https://r2.ruralheart.com/p1.webp](https://r2.ruralheart.com/p1.webp)", "is_first_impression": true, "display_order": 1 },
    { "photo_url": "[https://r2.ruralheart.com/p2.webp](https://r2.ruralheart.com/p2.webp)", "is_first_impression": false, "display_order": 2 },
    { "photo_url": "[https://r2.ruralheart.com/p3.webp](https://r2.ruralheart.com/p3.webp)", "is_first_impression": false, "display_order": 3 },
    { "photo_url": "[https://r2.ruralheart.com/p4.webp](https://r2.ruralheart.com/p4.webp)", "is_first_impression": false, "display_order": 4 },
    { "photo_url": "[https://r2.ruralheart.com/p5.webp](https://r2.ruralheart.com/p5.webp)", "is_first_impression": false, "display_order": 5 }
  ]
}

Response (201 Created)
{
  "success": true,
  "message": "Profile created successfully.",
  "data": {
    "user_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
    "is_profile_complete": true
  }
}

3. Module 2: "Chai Date" & Today's Intent Engine
3.1 Update Daily "Chai Date" Status
Sets or updates real-time intent status for quick local meetups.

Endpoint: POST /intent/chai-status

Auth Required: Yes

Request Body
{
  "chai_status": "free_for_chai"
}

Response (200 OK)
{
  "success": true,
  "message": "Chai Date status updated to 'free_for_chai'."
}

3.2 Send Direct "Chai Invite" (₹9 Sachet Micro-Purchase)
Sends a direct highlighted meetup proposal to a local user.

Endpoint: POST /intent/send-chai-invite

Auth Required: Yes

Request Body
JSON
{
  "receiver_id": "b1febc88-1c0b-4ef8-bb6d-6bb9bd380b22",
  "proposed_location": "Tea stall near Ayodhya Cantt Station",
  "sachet_transaction_id": "tx_chai_998877"
}

Response (201 Created)
JSON
{
  "success": true,
  "data": {
    "invite_id": "inv_123456789",
    "status": "pending",
    "message": "Chai Invite sent successfully to Priya."
  }
}
4. Module 3: Discovery Feed & Swiping Engine
4.1 Fetch Local Profile Cards (Micro-Radius 2 km - 10 km)
Retrieves nearby profiles with Chai Date badges and spatial distance obfuscation.

Endpoint: GET /feed?radius_km=5&limit=10

Auth Required: Yes

Response (200 OK)
JSON
{
  "success": true,
  "data": {
    "cards": [
      {
        "type": "profile",
        "profile": {
          "user_id": "b1febc88-1c0b-4ef8-bb6d-6bb9bd380b22",
          "first_name": "Priya",
          "age": 22,
          "distance_label": "Within 2 km (Near Saket College area)",
          "chai_status": "free_for_chai",
          "chai_status_label": "☕ Free for Chai this evening",
          "bio": "Coffee addict and book lover.",
          "area_name": "Ayodhya Cantt",
          "intent": "serious",
          "photos": [
            "[https://r2.ruralheart.com/priya_1.webp](https://r2.ruralheart.com/priya_1.webp)",
            "[https://r2.ruralheart.com/priya_2.webp](https://r2.ruralheart.com/priya_2.webp)"
          ]
        }
      },
      {
        "type": "ad_slot",
        "ad_config": {
          "ad_unit_id": "ca-app-pub-3940256099942544/6300978111",
          "format": "native_card"
        }
      }
    ]
  }
}
4.2 Ingest Swipe Action & Track Persistent 20-Skip Counter
Processes user swipe actions and manages the 20-skip interstitial ad trigger.

Endpoint: POST /feed/swipe

Auth Required: Yes

Request Body
JSON
{
  "target_user_id": "b1febc88-1c0b-4ef8-bb6d-6bb9bd380b22",
  "action": "reject"
}
Response (200 OK)
JSON
{
  "success": true,
  "data": {
    "is_match": false,
    "persistent_skip_count": 20,
    "trigger_interstitial_ad": true,
    "ad_unit_id": "ca-app-pub-3940256099942544/1033173712"
  }
}
5. Module 4: Chat Engine & "Safe WhatsApp Bridge"
5.1 Fetch Match Status & WhatsApp Bridge Counter
Checks if 15 mutual messages have been exchanged to reveal direct WhatsApp / Phone contact info.

Endpoint: GET /chat/whatsapp-bridge-status/{match_id}

Auth Required: Yes

Response (200 OK - Unlocked Example)
JSON
{
  "success": true,
  "data": {
    "match_id": "c11ebc99-9c0b-4ef8-bb6d-6bb9bd380c33",
    "mutual_message_count": 16,
    "is_whatsapp_unlocked": true,
    "partner_contact_info": {
      "phone_number": "+919876543210",
      "instagram_handle": "@priya_sharma_official",
      "whatsapp_link": "[https://wa.me/919876543210](https://wa.me/919876543210)"
    }
  }
}
Response (200 OK - Locked Example)
JSON
{
  "success": true,
  "data": {
    "match_id": "c11ebc99-9c0b-4ef8-bb6d-6bb9bd380c33",
    "mutual_message_count": 9,
    "is_whatsapp_unlocked": false,
    "remaining_messages_to_unlock": 6,
    "partner_contact_info": null
  }
}
5.2 Send Chat Media Attachment (Gated by ₹19 Photo Pass / ₹99 Subscription)
Uploads media assets to Cloudflare R2 if the user has an active photo pass or monthly subscription.

Endpoint: POST /chat/upload-media

Auth Required: Yes

Multipart Form Data
file: Binary File Buffer (JPEG/PNG/WebP)

conversation_id: UUID

Response (200 OK)
JSON
{
  "success": true,
  "data": {
    "media_url": "[https://r2.ruralheart.com/snaps/snap_99887766.webp](https://r2.ruralheart.com/snaps/snap_99887766.webp)",
    "is_view_once": false
  }
}
5.3 WebSocket Real-Time Chat Protocol
Handles direct text messaging, message delivery ticks, and real-time WhatsApp Bridge status updates.

WebSocket URL: wss://api.ruralheart.com/api/v1/chat/ws?token=<JWT_TOKEN>

Client -> Server: Send Message
JSON
{
  "event": "send_message",
  "payload": {
    "conversation_id": "c11ebc99-9c0b-4ef8-bb6d-6bb9bd380c33",
    "content": "Chai pine chalein kal shaam को?",
    "media_url": null
  }
}
Server -> Client: Receive Message (with Message Counter Update)
JSON
{
  "event": "new_message",
  "payload": {
    "message_id": "m99ebc99-9c0b-4ef8-bb6d-6bb9bd380m99",
    "conversation_id": "c11ebc99-9c0b-4ef8-bb6d-6bb9bd380c33",
    "sender_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
    "content": "Chai pine chalein kal shaam को?",
    "mutual_message_count": 15,
    "is_whatsapp_unlocked": true,
    "created_at": "2026-08-12T12:05:00Z"
  }
}
6. Module 5: Sachet Monetization Engine (UPI Micro-Transactions)
6.1 Create Sachet Order (₹9, ₹19, or ₹99)
Initiates Razorpay order creation based on the selected micro-plan.

Endpoint: POST /payments/create-sachet-order

Auth Required: Yes

Request Body
JSON
{
  "plan_type": "chai_invite_9"
}
(Options: chai_invite_9, profile_boost_19, day_photo_pass_19, monthly_premium_99)

Response (200 OK)
JSON
{
  "success": true,
  "data": {
    "order_id": "order_Nzx890aBcd1234",
    "amount_inr": 9.00,
    "plan_type": "chai_invite_9",
    "currency": "INR",
    "razorpay_key_id": "rzp_test_xxxxxxxxxxxxxx"
  }
}
6.2 Razorpay Payment Webhook
Handles automated callback triggers from Razorpay to activate sachet features instantly.

Endpoint: POST /payments/webhook

Auth Required: Signature Header Validation (X-Razorpay-Signature)

Request Body
JSON
{
  "event": "order.paid",
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_Pzx890aBcd5678",
        "order_id": "order_Nzx890aBcd1234",
        "status": "captured",
        "method": "upi"
      }
    }
  }
}
Response (200 OK)
JSON
{
  "status": "success",
  "message": "Sachet plan 'chai_invite_9' activated successfully."
}