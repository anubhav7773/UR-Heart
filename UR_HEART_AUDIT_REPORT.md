# UR-Heart Codebase Audit Report
**Date:** 2026-08-21  
**Project:** UR-Heart (formerly Project RuralHeart)  
**Scope:** Complete End-to-End Codebase Audit (Flutter Mobile App & FastAPI Backend)  
**Status:** Audit & Codebase Inventory (No code modified)

---

## Executive Summary

The `UR-Heart` codebase comprises a **FastAPI (Python 3.11+)** asynchronous backend paired with a **Flutter (Dart 3.0+)** cross-platform mobile application. The platform is architected specifically for Tier-2, Tier-3, and rural/urban Indian dating dynamics, featuring localized monetization (sachet micro-transactions ₹29–₹499), anti-leak communication firewalls ("Safe Bridge"), PostGIS-powered proximity and midpoint date radar ("Chai & Date Spots"), and video selfie identity verification.

---

## 1. End-to-End User Journey (Current State)

```mermaid
flowchart TD
    A[App Launch: main.dart] --> B[AnimatedSplashScreen]
    B --> C{Authenticated & Token Valid?}
    C -- No --> D[AuthScreen]
    C -- Yes --> E{is_profile_complete == true?}
    E -- No --> F[OnboardingScreen]
    E -- Yes --> G[MainHomeScreen: IndexedStack]
    
    D -->|Google OAuth / Phone OTP / Email| H[Backend /auth/* Endpoints]
    H -->|JWT Access Token + User Profile| C
    
    F -->|Step 1: Bio & Intent<br/>Step 2: DOB & Gender<br/>Step 3: Location / Pin<br/>Step 4: Photos| I[POST /profile/complete]
    I --> G

    subgraph "Main Dashboard (IndexedStack)"
        G --> Tab1[Tab 0: FeedScreen / Explore]
        G --> Tab2[Tab 1: ConversationsScreen / Chats]
        G --> Tab3[Tab 2: ActivityScreen]
        G --> Tab4[Tab 3: ProfileScreen]
    end

    Tab1 -->|Swipe Like/Reject| J[POST /feed/swipe]
    Tab1 -->|Direct DM ₹49 Sachet| K[POST /feed/direct-dm]
    Tab1 -->|Reward Video Ad| L[POST /ads/claim-reward]
    Tab1 -->|Profile Visitors Sheet| M[GET /profile/visitors]

    Tab2 -->|Select Match| N[IndividualChatScreen]
    N -->|Real-Time WS /ws/{match_id}| O[WebSocket Stream & Typing / Read Receipts]
    N -->|Zero-Leak Content Guard| P[Regex & Phonetic Leak Interceptor]
    N -->|Dual Consent + ₹499 Payment| Q[Safe Bridge Unlock: Reveal Phone & WA]
    N -->|Meetup Radar| R[GET /places/meetup-spots Midpoint Date Spots]

    Tab4 -->|Selfie Video Verification| S[POST /verification/upload-video]
    Tab4 -->|Voice Bio Record & Play| T[POST /profile/upload-voice-bio]
    Tab4 -->|Manage Sachet Passes| U[Razorpay Sachet Checkout]
    Tab4 -->|Admin Panel (if is_admin)| V[AdminVerificationScreen]
    Tab4 -->|Logout / Delete Account| W[App Exit / Purge Storage]
```

### 1.1 Step-by-Step Flow Breakdown

1. **App Launch & Initialization (`mobile_app/lib/main.dart`):**
   - Initializes `WidgetsFlutterBinding`, enables screenshot blocking via `PrivacyProtectionService.enableSecureScreen()`.
   - Initializes Firebase Core, Android High Importance Notification Channel, Google Mobile Ads SDK with test device filtering, and Firebase AppCheck (Debug provider for Android/Apple).
   - Initializes Sentry Flutter error monitoring and mounts `RuralHeartApp` with `AnimatedSplashScreen`.
   - Registers app lifecycle observer to push presence heartbeats (`PUT /profile/presence`) on `AppLifecycleState.resumed` and `paused`.

2. **Authentication & Session Init (`mobile_app/lib/features/auth/`):**
   - Splash screen inspects `FirebaseAuth.instance.currentUser` and `StorageManager.instance.getAuthToken()`.
   - If unauthenticated, displays `AuthScreen` (`mobile_app/lib/features/auth/auth_screen.dart` or modular `presentation/auth_screen.dart`).
   - Supports 3 authentication strategies:
     * **Google Sign-In**: Native Google OAuth exchange -> backend `POST /auth/social-login` or `POST /auth/firebase-login`.
     * **Phone / SMS OTP**: Firebase phone verification `verifyPhoneNumber` -> backend token validation (`POST /auth/verify-otp`).
     * **Email / Password**: Direct login (`POST /auth/email-login`) or registration (`POST /auth/email-signup`).
   - Server returns JWT access token (`HS256`, 15-day expiry), `user_id`, `is_profile_complete`, `is_premium`, and `is_admin`.
   - Credentials and flags are written to `FlutterSecureStorage` via `StorageManager`.

3. **Onboarding / Profile Setup (`mobile_app/lib/features/profile/onboarding_screen.dart`):**
   - If `is_profile_complete == false`, user is forced into a multi-step onboarding wizard.
   - Collects: Full Name, Bio, DOB (must be 18+), Gender & Interested-in, Intent (Casual, Serious, Friendship, Networking), Village PIN code / Area name, GPS Coordinates, and Profile Photos (uploaded via `POST /profile/photos`).
   - Finalizes profile via `POST /profile/complete` and routes to `MainHomeScreen`.

4. **Main Dashboard (`mobile_app/lib/features/home/home_screen.dart`):**
   - 4-tab `IndexedStack` keeping widget state preserved:
     * **Tab 0: Explore / Feed (`FeedScreen`)**: Fetches candidate cards based on PostGIS distance calculations, age, and gender preferences. Injects native ad cards every 5 cards. Supports swiping, profile expansion dialog, voice bio preview, rewarded ad top-up (+5 swipes), and visitor analytics bottom sheet.
     * **Tab 1: Chats / Conversations (`ConversationsScreen`)**: Lists active matches and conversations with last message snippet, unread count badge, and online indicators.
     * **Tab 2: Activity (`ActivityScreen`)**: 3 sub-tabs displaying "Matches", "Profiles You Liked", and "Disliked Profiles" fetched via `GET /users/activity`.
     * **Tab 3: Profile (`ProfileScreen`)**: Displays user avatar, active sachet pass status (Boost, Direct DM, VIP Ad-Free), selfie verification status badge, voice bio recorder/player, settings (Blocked Users, Privacy/Security toggles, App Updates), Admin Review panel access (for admins), and Account Deletion / Logout actions.

5. **Core Interactions:**
   - **Real-Time Chat (`IndividualChatScreen`):**
     * Connects to `ws://.../api/v1/chat/ws/{match_id}?token=...`.
     * Receives and broadcasts real-time text messages, typing indicators, read receipts ("double blue ticks"), and consent updates.
     * 10-second background watchdog timer polls `GET /chat/messages/{match_id}` as fallback.
   - **Zero-Leak Content Guard & Safe Bridge:**
     * All messages are scrutinized by multi-pass regex, leetspeak, Devanagari digit converters, and phonetic Hinglish analyzers (`backend/app/services/content_guard.py`).
     * Prevents sharing phone numbers, social media handles (IG, Snapchat, Telegram), UPI IDs, and maps before Safe Bridge is unlocked.
     * Unlocking requires **both users** to give consent and complete a ₹499 Razorpay payment (`POST /chat/bridge-payment`).
   - **Midpoint Date Radar (`MeetupSpotsSheet`):**
     * Computes geographical midpoint between User A and User B coordinates (`PlacesService.compute_midpoint`).
     * Queries OpenStreetMap/Overpass API for verified nearby Chai stalls, cafes, family restaurants, and hotels within 15km–50km.
     * Launches external navigation via Google Maps URLs.
   - **Monetization & Sachet Purchases (`PaymentService`):**
     * Integrates `razorpay_flutter` native checkout for 4 tiers: ₹29 (Boost 10x), ₹49 (Direct DM), ₹199 (VIP Ad-Free 30 days), and ₹499 (Safe Bridge).
     * Verifies payment signatures via backend `POST /payments/verify` (HMAC-SHA256).

6. **App Exit & Logout / Deletion:**
   - **Logout:** Disconnects WebSockets, clears `FlutterSecureStorage`, signs out of Firebase Auth, and resets navigation stack to `AuthScreen`.
   - **Account Deletion:** Invokes `DELETE /users/me`, cascading deletes all database records (photos, swipes, matches, messages, transactions), purges local cache, and redirects to `AuthScreen`.

---

### 1.2 Inventory of Active Screens, Controllers & Backend Endpoints

#### Active Mobile Screens & Sheets
| Screen / Component | File Location | Key Purpose |
| :--- | :--- | :--- |
| `AnimatedSplashScreen` | `mobile_app/lib/features/splash/splash_screen.dart` | Cold start animation, token check, notification deep-linking |
| `AuthScreen` | `mobile_app/lib/features/auth/auth_screen.dart` | Email, Google OAuth, and Phone OTP authentication |
| `AuthScreen` (Modular) | `mobile_app/lib/features/auth/presentation/auth_screen.dart` | Clean-architecture segmented auth interface |
| `OnboardingScreen` | `mobile_app/lib/features/profile/onboarding_screen.dart` | Multi-step user onboarding & profile completion wizard |
| `MainHomeScreen` | `mobile_app/lib/features/home/home_screen.dart` | Root 4-tab bottom navigation wrapper |
| `FeedScreen` | `mobile_app/lib/features/feed/feed_screen.dart` | Discovery card feed, swipe engine, rewarded ads |
| `ConversationsScreen` | `mobile_app/lib/features/chat/chat_screen.dart` | Conversation list, match bubbles, unread counts |
| `IndividualChatScreen` | `mobile_app/lib/features/chat/chat_screen.dart` | Real-time chat, Safe Bridge banner, meetup bar |
| `ActivityScreen` | `mobile_app/lib/screens/activity_screen.dart` | Activity tracking (Matches, Liked, Disliked) |
| `ProfileScreen` | `mobile_app/lib/features/profile/profile_screen.dart` | User profile, active passes, voice bio, settings |
| `EditProfileScreen` | `mobile_app/lib/features/profile/edit_profile_screen.dart` | Full profile field editing & photo uploads |
| `AdminVerificationScreen` | `mobile_app/lib/screens/admin_verification_screen.dart` | Admin video verification review panel |
| `BlockedUsersScreen` | `mobile_app/lib/features/settings/blocked_users_screen.dart` | View and unblock previously blocked users |
| `VisitorsSheet` | `mobile_app/lib/features/feed/visitors_sheet.dart` | Who viewed my profile bottom sheet |
| `SafeBridgePaywallSheet` | `mobile_app/lib/features/chat/widgets/safe_bridge_paywall_sheet.dart` | ₹499 Safe Bridge payment modal |
| `MeetupSpotsSheet` | `mobile_app/lib/features/chat/widgets/meetup_spots_sheet.dart` | Midpoint date radar places selector |
| `SubscriptionSheet` | `mobile_app/lib/features/subscription/subscription_sheet.dart` | Monetization tiers & Razorpay trigger sheet |
| `ProfileViewDialog` | `mobile_app/lib/features/profile/profile_view_dialog.dart` | Fullscreen profile inspection dialog |

#### Active Mobile Controllers & Services
| Controller / Service | File Location | Key Purpose |
| :--- | :--- | :--- |
| `ApiClient` | `mobile_app/lib/core/network/api_client.dart` | Dio HTTP client singleton with all backend endpoints |
| `FirebaseAuthInterceptor` | `mobile_app/lib/core/network/firebase_auth_interceptor.dart` | Automatic Firebase ID token injection into HTTP headers |
| `StorageManager` | `mobile_app/lib/core/security/storage_manager.dart` | Secure key-value store wrapper (`flutter_secure_storage`) |
| `AppAuthProvider` | `mobile_app/lib/features/auth/auth_provider.dart` | Global authentication state and session persistence |
| `AuthController` | `mobile_app/lib/features/auth/controllers/auth_controller.dart` | State machine for modular authentication |
| `ChatProvider` | `mobile_app/lib/features/chat/chat_provider.dart` | Distance calculations & chat helper utilities |
| `PaymentService` | `mobile_app/lib/features/subscription/payment_service.dart` | Razorpay checkout dispatch & event completers |
| `AdManager` | `mobile_app/lib/core/ads/ad_manager.dart` | Google AdMob rewarded & interstitial loader |
| `LocationService` | `mobile_app/lib/core/services/location_service.dart` | Geolocator GPS coordinate acquisition |
| `FcmService` | `mobile_app/lib/core/services/fcm_service.dart` | Push notification token syncing & payload routing |
| `AppUpdateService` | `mobile_app/lib/core/services/app_update_service.dart` | In-app APK update checker & installer |
| `WindowSecurityService` | `mobile_app/lib/core/services/security_service.dart` | Screenshot and screen-recording prevention |

#### Backend API Endpoints Implemented in FastAPI
| Module | Method | Route | Handler Function |
| :--- | :--- | :--- | :--- |
| **Auth** | `POST` | `/api/v1/auth/social-login` | `social_login` |
| | `POST` | `/api/v1/auth/firebase-login` | `firebase_login` |
| | `POST` | `/api/v1/auth/send-otp` | `send_otp` |
| | `POST` | `/api/v1/auth/verify-otp` | `verify_otp` |
| | `POST` | `/api/v1/auth/email-signup` | `email_signup` |
| | `POST` | `/api/v1/auth/email-login` | `email_login` |
| **Profile** | `GET` | `/api/v1/profile/me` | `get_user_profile` |
| | `PUT` | `/api/v1/profile` | `update_profile` |
| | `POST` | `/api/v1/profile/complete` | `complete_profile` |
| | `POST` | `/api/v1/profile/photos` | `upload_profile_photo` |
| | `POST` | `/api/v1/profile/upload-voice-bio` | `upload_voice_bio` |
| | `DELETE` | `/api/v1/profile/voice-bio` | `delete_voice_bio` |
| | `PUT` | `/api/v1/profile/presence` | `update_presence` |
| | `GET` | `/api/v1/profile/visitors` | `get_profile_visitors` |
| | `DELETE` | `/api/v1/profile/visitors/{visitor_id}` | `dismiss_profile_visitor` |
| | `GET` | `/api/v1/profile/blocked` | `get_blocked_users` |
| | `POST` | `/api/v1/profile/unblock/{target_id}` | `unblock_user_by_path` |
| | `POST` | `/api/v1/profile/report` | `report_user` |
| **Users** | `GET` | `/api/v1/users/me` | `get_my_user_profile` |
| | `PUT` | `/api/v1/users/me` | `update_my_user_profile` |
| | `POST` | `/api/v1/users/fcm-token` | `update_fcm_token` |
| | `POST` | `/api/v1/users/location` | `update_user_location` |
| | `GET` | `/api/v1/users/activity` | `get_user_activity` |
| | `DELETE` | `/api/v1/users/me` | `delete_current_user_account` |
| **Feed** | `GET` | `/api/v1/feed` | `get_feed` |
| | `POST` | `/api/v1/feed/swipe` | `swipe_action` |
| | `POST` | `/api/v1/feed/direct-dm` | `send_direct_dm` |
| **Matches** | `GET` | `/api/v1/matches/feed` | `get_matches_feed` |
| | `POST` | `/api/v1/matches/swipe` | `post_matches_swipe` |
| **Chat** | `WS` | `/api/v1/chat/ws/{match_id}` | `chat_websocket_endpoint` |
| | `GET` | `/api/v1/chat/matches` | `get_matches` |
| | `GET` | `/api/v1/chat/messages/{match_id}` | `get_chat_messages` |
| | `POST` | `/api/v1/chat/messages` | `send_chat_message` |
| | `DELETE` | `/api/v1/chat/messages/{message_id}` | `unsend_chat_message` |
| | `POST` | `/api/v1/chat/upload-media` | `upload_chat_media` |
| | `GET` | `/api/v1/chat/bridge-status/{match_id}` | `get_safe_bridge_status` |
| | `POST` | `/api/v1/chat/consent/{match_id}` | `submit_chat_consent` |
| | `POST` | `/api/v1/chat/{match_id}/meetup-consent` | `update_meetup_consent` |
| | `POST` | `/api/v1/chat/bridge-payment` | `submit_bridge_payment` |
| | `POST` | `/api/v1/chat/messages/read` | `mark_messages_as_read` |
| | `GET` | `/api/v1/chat/icebreakers` | `get_icebreakers` |
| **Intent** | `POST` | `/api/v1/intent/chai-status` | `update_chai_status` |
| | `POST` | `/api/v1/intent/send-chai-invite` | `send_chai_invite` |
| **Places** | `GET` | `/api/v1/places/nearby` | `get_nearby_spots` |
| | `GET` | `/api/v1/places/meetup-spots` | `get_meetup_spots` |
| **Payments**| `POST` | `/api/v1/payments/create-order` | `create_razorpay_order` |
| | `POST` | `/api/v1/payments/create-sachet-order` | `create_sachet_order` |
| | `POST` | `/api/v1/payments/verify` | `verify_payment` |
| | `GET` | `/api/v1/payments/active-pass` | `get_active_pass_status` |
| | `POST` | `/api/v1/payments/webhook` | `razorpay_webhook` |
| **Ads** | `GET` | `/api/v1/ads/config` | `get_ad_config` |
| | `POST` | `/api/v1/ads/telemetry` | `log_ad_event` |
| | `POST` | `/api/v1/ads/claim-reward` | `claim_ad_reward` |
| **Verification**| `POST` | `/api/v1/verification/upload-video` | `upload_verification_video` |
| | `GET` | `/api/v1/verification/status` | `get_verification_status` |
| **Admin** | `GET` | `/api/v1/admin/verifications/pending` | `get_pending_verifications` |
| | `POST` | `/api/v1/admin/verifications/{user_id}/review` | `review_user_verification` |
| **Safety** | `POST` | `/api/v1/safety/block` | `block_user` |
| | `POST` | `/api/v1/safety/report` | `report_user` |
| **System** | `GET` | `/api/v1/system/app-version` | `get_app_version` |
| **Root** | `GET` | `/health` / `/api/v1/health` | `health_check` |

---

## 2. Production Readiness Audit Table

| Feature Name & Location | Status | Current Gaps & Missing Edge-Case Handling |
| :--- | :---: | :--- |
| **Phone & OTP Authentication**<br>`mobile_app/lib/features/auth/` & `backend/app/api/v1/auth.py` | **Partially Implemented** | Firebase Auth SMS delivery works on mobile, but backend `/auth/send-otp` generates random mock codes in memory (`_mock_otp_store`) without a live SMS gateway integration (e.g. Fast2SMS / Twilio). Rate limiting (5 req/min) exists on endpoint. |
| **Google Sign-In**<br>`mobile_app/lib/features/auth/auth_screen.dart` | **Production Ready** | Correctly exchanges Google ID Token with Firebase and backend. Handles cancellation and account switching. |
| **Email/Password Auth**<br>`backend/app/api/v1/auth.py` | **Production Ready** | Password hashing with bcrypt, disposable email domain blocking (`DISPOSABLE_EMAIL_DOMAINS`), JWT token issuance. |
| **Session & Token Management**<br>`mobile_app/lib/core/network/firebase_auth_interceptor.dart` | **Partially Implemented** | Interceptor refreshes Firebase ID token and injects `Authorization: Bearer`. **Gap:** On `401 Unauthorized`, it logs the error but does not trigger automatic navigation back to login or session purge. |
| **Discovery Feed & PostGIS Filtering**<br>`mobile_app/lib/features/feed/feed_screen.dart` & `backend/app/api/v1/feed.py` | **Production Ready** | PostGIS `ST_DWithin` spatial query with fallback when zero candidates are within radius. Handles age and gender preferences. |
| **Swipe & Matching Engine**<br>`backend/app/api/v1/feed.py` & `matches.py` | **Production Ready** | Atomic swipe logging in `swipes` table, mutual like detection, instant `matches` record creation, and push notification dispatch. |
| **Direct DM Sachet Feature**<br>`backend/app/api/v1/feed.py` (`/feed/direct-dm`) | **Production Ready** | Enforces 1 free daily DM for non-paying users, checks active `direct_dm_until` pass or requires ₹49 sachet unlock. |
| **Profile Visitors Tracking**<br>`mobile_app/lib/features/feed/visitors_sheet.dart` & `profile.py` | **Production Ready** | Logs impressions in `profile_visitors` table, allows dismissing visitors, and aggregates unread visitor counts. |
| **Real-Time WebSocket Chat**<br>`mobile_app/lib/features/chat/chat_screen.dart` & `backend/app/api/v1/chat.py` | **Partially Implemented** | Working single-node WebSocket with typing indicators, read receipts, and 10s HTTP watchdog. **Gaps:** `ConnectionManager` uses in-memory Python `dict/set`—will not broadcast across multiple server instances without Redis pub/sub. Mobile WebSocket lacks exponential backoff auto-reconnect on network drop. |
| **Zero-Leak Content Guard**<br>`backend/app/services/content_guard.py` | **Production Ready** | Multi-pass regex, leetspeak converter, Hindi/Hinglish numeral translation, zero-width char stripping, and UPI/social handle filtering. |
| **Safe Bridge Mutual Payment**<br>`mobile_app/lib/features/chat/widgets/safe_bridge_paywall_sheet.dart` & `backend/app/api/v1/chat.py` | **Production Ready** | Strict dual consent + ₹499 payment verification before revealing phone numbers and social links. |
| **Midpoint Date Radar / Places**<br>`mobile_app/lib/features/chat/widgets/meetup_spots_sheet.dart` & `backend/app/services/places_service.py` | **Production Ready** | Calculates true geographical midpoint, queries Overpass OSM API with tiered radius (15km/35km/50km), in-memory TTL caching (6h), and launches Google Maps. |
| **Chai Status & Chai Invites**<br>`backend/app/api/v1/intent.py` & `ApiClient` | **Mocked / Orphaned** | Backend endpoints (`/intent/chai-status`, `/intent/send-chai-invite`) and `ApiClient` methods are written, but **no Flutter UI screens connect to them** (orphaned feature). |
| **Monetization & Razorpay UPI**<br>`mobile_app/lib/features/subscription/` & `backend/app/api/v1/payments.py` | **Partially Implemented** | Full checkout options, order creation, and HMAC-SHA256 signature verification. **Gap / Vulnerability:** In `payments.py`, test environment checks permit mock signatures if `ENVIRONMENT` is default or test-like. |
| **Google AdMob Monetization**<br>`mobile_app/lib/core/ads/ad_manager.dart` & `backend/app/api/v1/ads.py` | **Production Ready** | Native ad cards in feed (every 5 cards), interstitial after 20 skips, rewarded video ad (+5 swipes, max 3/day enforced server-side). |
| **Voice Bio (Audio Record & Play)**<br>`mobile_app/lib/features/profile/profile_screen.dart` & `profile.py` | **Production Ready** | Uses `record` and `audioplayers` packages, uploads audio bytes to Supabase Storage, saves duration, and plays audio in feed/profile. |
| **5-Sec Selfie Video Verification**<br>`mobile_app/lib/features/profile/profile_screen.dart` & `backend/app/api/v1/verification.py` | **Production Ready** | Captures front-camera selfie video with extension whitelisting (`.mp4`, `.mov`), uploads to storage, sets status to `PENDING`. |
| **Admin Verification Review**<br>`mobile_app/lib/screens/admin_verification_screen.dart` & `backend/app/api/v1/admin.py` | **Production Ready** | Admin-gated (`is_admin == true`), lists pending verifications, plays video using `video_player`, and allows Approve/Reject actions. |
| **User Safety (Block & Report)**<br>`mobile_app/lib/features/settings/blocked_users_screen.dart` & `backend/app/api/v1/safety.py` | **Production Ready** | Writes to `blocked_users` and `reported_users` tables; blocks immediately exclude candidates from feed and chat lists. |
| **Media Storage Engine**<br>`backend/app/services/storage_engine.py` | **Partially Implemented** | Converts images to WebP via Pillow and posts to Supabase Storage REST API. **Gap:** If Supabase upload fails, it catches the exception and returns the public URL anyway, resulting in dead 404 images in the database. |
| **Screenshot / Screen Record Guard**<br>`mobile_app/lib/core/services/security_service.dart` | **Production Ready** | Uses Android `FLAG_SECURE` (`flutter_windowmanager`) to block screenshots and screen recordings on Android devices. |
| **In-App Auto Update**<br>`mobile_app/lib/core/services/app_update_service.dart` & `backend/app/api/v1/system.py` | **Production Ready** | Compares `package_info_plus` version with `/system/app-version`, downloads APK via Dio, and triggers install via `open_filex`. |
| **Audio/Video Real-Time Calls** | **Not Implemented** | **Zero WebRTC or VoIP calling code** in the codebase. No WebRTC dependency in `pubspec.yaml` and no signaling server. |

---

## 3. Infrastructure & Architecture Status

### 3.1 WebRTC & Signaling Implementation Status
- **Status: Not Implemented.**
- There is **no WebRTC engine, STUN/TURN server configuration, or real-time calling subsystem** anywhere in the mobile app or backend.
- The `video_player: ^2.8.2` package in `pubspec.yaml` is used strictly for static file playback of selfie verification videos in `AdminVerificationScreen`.
- There are no audio call or video call screens or signaling message types in the WebSocket dispatcher.

### 3.2 Real-Time Data Pipeline & Listeners
- **WebSocket Protocol:**
  * Endpoint: `ws(s)://<host>/api/v1/chat/ws/{match_id}?token=<jwt>`
  * Handshake: Validates JWT token and checks participant authorization (`verify_conversation_access_raw`) to prevent IDOR attacks.
  * Message Types: `message`, `typing`, `read_receipt`, `MEETUP_CONSENT_UPDATED`, `consent_update`, `MESSAGE_UNSENT`.
- **Architectural Limitations:**
  * **Single-Node In-Memory Manager:** Active sockets are stored in a Python dictionary in `backend/app/api/v1/chat.py`. If the backend is scaled horizontally across multiple instances or Render containers, clients connected to different instances will not receive each other's messages.
  * **Polling Watchdog Fallback:** The mobile app runs a 10-second background polling timer (`_realtimePollingTimer`) while on the chat screen to sync missed messages.
- **Push Notification Fallback (FCM):**
  * Firebase Cloud Messaging is integrated via `fcm_service.py` (`firebase_admin.messaging`).
  * Triggers high-importance notifications (`channel_id: 'high_importance_channel'`) when mutual matches occur or offline chat messages are received.
  * Degrades gracefully to console mock logs if Firebase service account credentials are not configured.

### 3.3 Security & Local Storage Handling
- **Local Storage:**
  * Uses `flutter_secure_storage` with Android `EncryptedSharedPreferences` and iOS Keychain for storing JWT access tokens, user IDs, and role flags.
  * Fallback non-sensitive counters (e.g. skip counts) are stored in SharedPreferences.
- **Hardware & Device Permissions:**
  * Location permissions requested via `geolocator` (`LocationService`).
  * Camera and microphone permissions requested on demand for photo picking (`image_picker`), audio recording (`record`), and selfie video capture.
  * Display protection: `FlutterWindowManager.addFlags(FLAG_SECURE)` prevents screenshots and screen recording on Android devices.
- **Network Security & Rate Limiting:**
  * Security middleware in `main.py` blocks automated vulnerability scanners (`sqlmap`, `nikto`, `dirbuster`, etc.) and adds security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, CSP, HSTS).
  * Rate limiting applied via `slowapi` and custom `rate_limit` dependencies (e.g., 5 req/min on `/auth`, 10 req/min on `/payments`, 60 req/min on `/feed`).

---

## 4. Current Risk & Blocker Summary

### Critical Architectural & Production Risks

1. **Horizontal Scaling Blocker (WebSocket State in Memory):**
   - **Location:** `backend/app/api/v1/chat.py` (`ConnectionManager`)
   - **Risk:** Chat connections are stored in Python process memory (`self.match_connections`). Deploying more than 1 container/pod on Render or Kubernetes will cause split-brain message delivery where users connected to separate pods cannot communicate.
   - **Impact:** Critical real-time chat failure in multi-instance production.

2. **Silent Storage Failure & Dead Asset Links:**
   - **Location:** `backend/app/services/storage_engine.py` (lines 70–78)
   - **Risk:** When an upload to Supabase Storage fails (e.g., bucket permissions, network error, or invalid API key), the exception is suppressed and the function returns the public CDN URL anyway.
   - **Impact:** Broken image and video links (404 errors) permanently saved in the database for user profile photos, voice bios, and selfie verifications.

3. **Payment Signature Verification Bypass in Non-Production Mode:**
   - **Location:** `backend/app/api/v1/payments.py` (lines 248–250)
   - **Risk:** If the server is deployed without explicitly setting `ENVIRONMENT=production`, `is_test_env` evaluates to `True`, allowing arbitrary `mock_*` signatures to activate real subscription passes and bypass Razorpay payment validation.
   - **Impact:** High financial and authorization bypass vulnerability.

4. **Missing Automatic 401 Session Expiry Handling in Mobile Client:**
   - **Location:** `mobile_app/lib/core/network/api_client.dart` & `firebase_auth_interceptor.dart`
   - **Risk:** `FirebaseAuthInterceptor` logs `401 Unauthorized` on expired tokens but does not execute a global logout or redirect to `AuthScreen`.
   - **Impact:** App enters broken/silent failure states where API requests fail repeatedly without prompting the user to re-authenticate.

5. **AudioPlayer & Timer Lifecycle Leaks in Mobile Feed and Chat:**
   - **Location:** `mobile_app/lib/features/feed/feed_screen.dart` & `chat_screen.dart`
   - **Risk:** If the user rapidly navigates away or switches tabs while a voice bio is streaming or while periodic polling timers are running, multiple concurrent timers or unreleased audio players can cause memory leaks and background audio playback.

6. **PostGIS Empty-Radius Fallback Performance Penalty:**
   - **Location:** `backend/app/api/v1/feed.py` (lines 308–320)
   - **Risk:** If a user is in a remote area with zero candidates within 500km, the fallback queries the entire `users` table without spatial bounds, causing high database CPU load as the user base grows.

---

## 5. Summary Conclusion & Verdict

The `UR-Heart` codebase has a strong foundation with complete core dating features implemented end-to-end:
- **Authentication & Onboarding**: Complete with Google, Phone, and Email flows.
- **Feed & Discovery**: Complete with PostGIS spatial filtering, swiping, matching, and native ads.
- **Messaging & Safe Bridge**: Functional real-time WebSocket messaging with an anti-leak content filter and dual-consent monetization.
- **Micro-Monetization**: Structured 4-tier Razorpay sachet model.
- **Identity & Moderation**: Video selfie verification with an admin review panel.

The primary gaps before launching to a large-scale production audience are:
1. Adding a Redis pub/sub layer to the WebSocket connection manager for multi-instance scaling.
2. Hardening Supabase storage error handling so failed uploads raise errors instead of returning 404 URLs.
3. Ensuring `ENVIRONMENT=production` is strictly enforced for payment signature verification.
4. Hooking a global 401 unauthorized handler in the mobile app to cleanly reset expired sessions.
5. Clarifying that real-time WebRTC audio/video calling is not yet present in the codebase.

---
*Report generated from comprehensive static analysis of the active `UR-Heart` codebase.*
