# Product Requirements Document (PRD) — UR-Heart

**Application Name:** UR-Heart (Urban and Rural Heart)  
**Parent Entity:** ASI Verticals  
**Document ID:** URH-PRD-001  
**Version:** 2.0.0-PROD  
**Target Geo:** Tier-2, Tier-3 Cities & Semi-Urban/Rural India  
**Target Platforms:** Android (Primary - Min SDK 23 / Android 6.0+), iOS (Secondary)  
**Core Monetization:** 100% Ad-Supported (Zero Paywall, Zero In-App Purchases, Zero Subscriptions)  
**Infrastructure Ceiling:** $0.00/month (Strictly Free Tiers — Zero Credit/Debit Card Required)

---

## 1. Executive Summary & Problem Statement

### 1.1. Market Disruption
Mainstream dating apps operating in India (Tinder, Bumble, Hinge) impose subscription paywalls ranging between ₹1,000 and ₹4,000 per month. For youth and young adults in Tier-2 and Tier-3 cities (e.g., Lucknow, Kanpur, Patna, Indore, Bhopal, Gorakhpur, Meerut, Varanasi), this creates an insurmountable economic barrier. Consequently, users seek unsafe workarounds or abandon the platforms.

### 1.2. Product Solution: UR-Heart
**UR-Heart (Urban and Rural Heart)**, operated under **ASI Verticals**, provides a completely free, ad-funded platform tailored specifically to Indian regional and vernacular dynamics:
- **Zero Financial Cost:** 100% of features (matching, direct messaging, contact revelation) are unlocked via sponsored rewarded and interstitial video ads.
- **Data Minimization & Free Cloud Guarantee:** Operates entirely within free-tier quotas (Firebase Auth Spark + Supabase Free Database/Storage via MCP + Render Free Web Service).
- **Anti-Leak Ecosystem:** Prevents off-platform migration to external channels (WhatsApp, Instagram, Telegram) until a mutual ad-supported threshold is cleared.
- **Absolute Privacy & Safety:** Built-in screenshot and screen-recording prevention (`FLAG_SECURE`), mandatory 5-second Live Video/Audio KYC, and strict UGC reporting and blocking mechanisms.

---

## 2. Technical Stack & Infrastructure Boundaries (Zero-Card Blueprint)

| Subsystem | Service / Technology | Tier / Allocation | Billing / Card Requirement | Purpose in UR-Heart |
| :--- | :--- | :--- | :--- | :--- |
| **Client** | Flutter 3.x (Dart) | Open-Source Framework | None | Android & iOS cross-platform app |
| **Authentication** | Firebase Auth | Spark Plan (50,000 MAU) | **No Card Required** | Google One-Tap & Email/Password login |
| **Primary Database** | Supabase PostgreSQL | Free Tier (500 MB DB) | **No Card Required** | Relational data, RLS, Indexes, Pruning Cron |
| **Media Storage** | Supabase Storage | Free Tier (1 GB Bucket) | **No Card Required** | Storing client-compressed WebP profile photos |
| **Backend API** | FastAPI (Python 3.11) | Render.com Web Service | **No Card Required** | Async REST APIs, WebSockets, OCR & NLP filters |
| **Ad Mediation** | Google Mobile Ads SDK | AdMob + InMobi + Meta | **No Card Required** | Multi-network rewarded and interstitial ads |
| **Ideation / Design** | Google Stitch MCP | UI/UX Generation | None | Screen prototyping & vernacular design tokens |

---

## 3. User Personas & Device Specifications

### 3.1. Primary Target Personas
1. **Ravi (Age 22, Tier-3 Town - Gorakhpur):** College student, Android user (Redmi Note series, 4GB RAM), prepaid mobile data with fluctuating speeds. Wants to date locally without spending monthly pocket money on app subscriptions. Prefers Hindi/Hinglish instructions.
2. **Pooja (Age 24, Tier-2 City - Lucknow):** Working professional, highly concerned about privacy, stalking, and image misuse. Wants assurance that her photos cannot be screenshotted, downloaded, or shared on external messaging apps without strict consent.

### 3.2. Target Device & OS Constraints
- **Operating Systems:** Android 8.0 (API level 26) through Android 15+.
- **Memory Footprint:** Application RAM consumption must remain under 120 MB on low-end 2GB/3GB RAM Android devices.
- **Network Resilience:** Full functional stability on 3G, 4G, 5G, and high-packet-loss mobile networks.

---

## 4. Detailed Functional Requirements (FR)

### FR-01: Ephemeral Installation Identity & "Zero on Delete"
- **FR-01.1 (Client-Side Generation):** Upon the very first launch following an installation, the Flutter application must generate a cryptographically random UUID v4 (`installation_uuid`).
- **FR-01.2 (Storage Isolation):** The `installation_uuid` must be persisted strictly within Android internal private app sandbox storage (`SharedPreferences` / application sandboxed file directory). It must **never** be saved to external shared storage or device backup mirrors (`android:allowBackup="false"`).
- **FR-01.3 (Startup Handshake):** Every network request initiating an authenticated session must include `X-Installation-UUID` in the HTTP header.
- **FR-01.4 (Backend Verification & Wipe):**
  - FastAPI receives `X-Installation-UUID` and queries `public.users.last_installation_uuid`.
  - If `last_installation_uuid IS NULL`, update it to the incoming UUID.
  - If `last_installation_uuid != incoming_uuid`:
    - The backend identifies that an app uninstall or application data wipe has occurred.
    - Immediately execute an atomic transaction resetting `streak_count = 0` and `reward_balance = 0`.
    - Update `last_installation_uuid = incoming_uuid`.
    - Return payload status: `{"status": "reset_executed", "streak_count": 0, "reward_balance": 0}`.
  - If identical, preserve existing streak and reward balances.

---

### FR-02: Age Verification & Google Play Minor Restriction (Age-Gating)
- **FR-02.1 (Neutral DOB Selection):** The registration screen must display a Date of Birth wheel initialized to a blank or neutral state (no pre-selected adult year).
- **FR-02.2 (18+ Hard Gate):** The user's age is calculated dynamically on the client and validated on the backend:
  $$\text{Age} = \text{Current Date} - \text{Selected DOB}$$
- **FR-02.3 (Underage Handling & Device Cooldown):**
  - If calculated age is $< 18$ years, registration immediately terminates with error: *"UR-Heart is strictly for individuals aged 18 and older."*
  - A SHA-256 hash of the device identifier combined with the submitted phone number is inserted into `public.underage_quarantine` with a 180-day expiry timestamp.
  - Subsequent registration attempts from the same device/phone combination within 180 days are rejected before phone OTP generation.

---

### FR-03: Multi-Provider Authentication & Profile Setup
- **FR-03.1 (Firebase Auth Integration):**
  - Primary Method: Google Sign-In (One-Tap flow).
  - Secondary Method: Email & Password.
- **FR-03.2 (Session Synchronization):**
  - Upon successful Firebase authentication, the mobile client retrieves the Firebase ID token (`jwt`).
  - Client calls FastAPI: `POST /api/v1/auth/session-sync` with the `Authorization: Bearer <firebase_id_token>`.
  - FastAPI decodes and verifies the token using the Firebase Admin SDK, extracting `firebase_uid`, `email`, and `email_verified`.
  - Record is upserted into Supabase `public.users` mapping `auth_id = firebase_uid`.
- **FR-03.3 (Mandatory Demographics):** User must submit:
  - `full_name`: String (2 to 50 characters, letters and spaces only).
  - `phone_number`: E.164 format Indian mobile number (`+91XXXXXXXXXX`).
  - `whatsapp_number`: E.164 format Indian mobile number (`+91XXXXXXXXXX`).
  - `gender`: Enum (`male`, `female`, `other`).
  - `city`: String (Tier-2/Tier-3 city selector with search).
  - `bio`: Optional String (Maximum 250 characters).

---

### FR-04: 5-Photo Upload, WebP Compression & OCR Anti-Leak Pre-Check
- **FR-04.1 (Photo Slot Mandate):** Every user must upload exactly 5 photos:
  - Slot 1: Hero Display Photo (shown primarily in discovery feed).
  - Slots 2 to 5: Secondary Lifestyle Photos.
- **FR-04.2 (Client-Side Compression & BlurHash):**
  - Before any network transmission, the Flutter app uses `flutter_image_compress` to compress each image to `.webp` format.
  - Constraint: Resolution capped at $1080 \times 1350$ px; file size must not exceed 100 KB.
  - Client generates a 32-character `BlurHash` string from a tiny thumbnail ($32 \times 32$ px) to store in Supabase for instant placeholder rendering.
- **FR-04.3 (Backend OCR Text Moderation Gate):**
  - The compressed image is sent to FastAPI: `POST /api/v1/moderation/scan-photo`.
  - Backend runs OpenCV QR Code detection (<15ms). If a QR code or barcode is detected $\rightarrow$ Return `HTTP 422 Unprocessable Entity` ("QR Codes are strictly forbidden").
  - Backend applies Grayscale + Gaussian Blur + Otsu Thresholding, then passes the matrix to Tesseract OCR (`--oem 1 --psm 11`).
  - **Rejection Patterns:**
    - Any 10-digit number sequence (phone numbers).
    - Social media prefixes or handles (`@`, `ig:`, `insta`, `sc:`, `snap`, `wa:`, `tele`, `fb:`).
  - If text is detected matching forbidden patterns $\rightarrow$ Reject upload with `HTTP 422`.
  - If clean $\rightarrow$ Image is saved to Supabase Storage bucket `user-photos` under path: `/users/{user_id}/slot_{1-5}.webp`, and database record in `public.user_photos` is marked `ocr_verified = TRUE`.

---

### FR-05: 5-Second Live Video/Audio KYC Verification
- **FR-05.1 (DPDP Act Bilingual Notice):** Prior to camera/microphone initialization, an unbundled modal is presented:
  - *English:* "Notice under DPDP Act 2023: Live Video/Audio is collected solely for one-time age and identity verification. Encrypted via AES-256 and purged within 24-48 hours."
  - *Hindi:* "डिजिटल व्यक्तिगत डेटा संरक्षण अधिनियम 2023 के तहत सूचना: लाइव वीडियो/ऑडियो केवल एक बार पहचान और उम्र सत्यापन के लिए है। सत्यापन के 24-48 घंटे के भीतर इसे हमेशा के लिए हटा दिया जाएगा।"
  - User must tap "Agree & Proceed".
- **FR-05.2 (Recording Constraints):**
  - Frontend opens a circular selfie viewfinder.
  - App records a 5-second video (MP4 format, low-bitrate H.264, max size 2 MB) where the user states their name and city.
- **FR-05.3 (Temporary Storage & Auto-Purge):**
  - Uploaded to Supabase Storage: `/kyc_temp/{user_id}_kyc.mp4`.
  - Once reviewed and approved (or rejected), `public.users.kyc_status` is updated to `TRUE`.
  - File is hard-deleted from storage immediately after verification (maximum lifecycle SLA: 48 hours).

---

### FR-06: Discovery Feed & Swiping Mechanics
- **FR-06.1 (Feed Querying & Exclusions):**
  - The feed returns user profile cards matching preference criteria (gender preference, age range, location proximity).
  - Feed query strictly excludes:
    - Profiles already swiped by the current user.
    - Profiles blocked by the current user or profiles that have blocked the current user.
    - Soft-deleted accounts (`deleted_at IS NOT NULL`) and banned accounts (`is_banned = TRUE`).
- **FR-06.2 (Swipe Actions):**
  - **Swipe Left (Pass):** Records a `pass` row in `public.swipes`. (Pruned automatically after 30 days to protect storage).
  - **Swipe Right (Like):** Records a `like` row in `public.swipes`. If a reciprocal `like` exists from the target, atomically instantiate a row in `public.matches`.
  - **Center Action (Direct DM):** Bypasses the mutual match requirement.
    - Unlocked strictly when the user watches a 10-second rewarded video ad.
    - Grants an immediate direct conversation channel to the target profile.

---

### FR-07: Ad Monetization Integration & Pacing Rules
- **FR-07.1 (Paced Interstitial Feed Ads):**
  - After every 10 consecutive profile swipes (combination of likes and passes), the feed pauses.
  - A subtle 2-second countdown HUD appears: *"Next profile in 2..."*.
  - A 20-second non-intrusive interstitial ad is served via the AdMob/InMobi mediation chain.
  - Frequency capping: Maximum 1 interstitial per 3 minutes to prevent ad fatigue.
- **FR-07.2 (Direct DM Rewarded Ad):**
  - Tapping "Direct DM" triggers an affirmative opt-in modal: *"Watch a short 10s video ad to send a Direct DM without matching"*.
  - Successful completion increments `public.users.reward_balance` by 3 DM credits.
- **FR-07.3 (Mutual WhatsApp Reveal 3-Ad Bundle):**
  - Disclosed clearly as a sponsored feature: Both users must watch 3 rewarded video ads (30s each) to reveal WhatsApp numbers.
- **FR-07.4 (Server-Side Verification - SSV Guard):**
  - No reward is credited directly by the mobile client.
  - The ad network issues an HTTP GET callback to FastAPI: `/api/v1/ads/verify-reward`.
  - FastAPI verifies Google's ECDSA public signature (or network HMAC).
  - FastAPI verifies transaction uniqueness against `public.processed_ad_transactions`.
  - Reward is updated on the database level.

---

### FR-08: Protected Chat System & Iron-Curtain Anti-Leak Engine
- **FR-08.1 (Screenshot & Recording Prevention):**
  - When the user enters any Chat screen or Profile view, Flutter executes:
    `FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE)`
  - Screenshots on Android produce a blank black screen or display "Can't take screenshot due to security policy."
  - Screen recording records audio only with black visual frames.
  - App switcher preview displays a blank solid color.
  - Flags are removed (`clearFlags`) when navigating back to public settings.
- **FR-08.2 (Pre-Transmission NLP Filter - `chat_sanitizer.py`):**
  - When a user submits a message via WebSocket or REST, it is intercepted by `sanitize_chat_message()` before database persistence:
    1. **Unicode De-obfuscation:** Decomposes diacritics (NFKD), strips zero-width spaces (`\u200b`, `\u200c`, `\u200d`, `\ufeff`).
    2. **Phone Number Filtering:** Strips all non-digit characters and matches against 10-digit Indian mobile sequences starting with 6, 7, 8, or 9 (with or without `+91`, `0`, spaces, dots, slashes).
    3. **Word-to-Number Transliteration:** Maps English words (`zero` to `nine`) and Hindi transliterations (`shunya`, `ek`, `do`, `teen`, `chaar`, `paanch`, `chhe`, `saat`, `aath`, `nau`) into digit strings and checks for 10-digit sequences.
    4. **Social Handles & Leetspeak:** Condenses string (removes whitespace/symbols) and checks for keywords (`whatsapp`, `watsapp`, `vatsap`, `instagram`, `insta`, `telegram`, `snapchat`, `facebook`, `paytm`, `gpay`). Tokenized boundary search for short prefixes (`@`, `ig:`, `wa:`, `sc:`, `tg:`).
- **FR-08.3 (Rejection Behavior):**
  - If a violation is identified:
    - The message is **not** written to `public.messages`.
    - The message is **not** broadcast to the recipient.
    - Sender receives a localized WebSocket alert:
      `{"event": "error_alert", "code": 422, "message": "Phone numbers, social handles (@, IG, WA, Snap) or external contacts cannot be shared directly in chat."}`
    - The chat input highlights in red with an error icon.

---

### FR-09: WhatsApp Reveal State Machine
- **FR-09.1 (Dual Opt-In Consent):**
  - Either User 1 or User 2 taps "Unlock WhatsApp" in chat.
  - A consent banner appears for both users: *"Unlock mutual WhatsApp connection by watching 3 short video ads each."*
  - State initialized in `public.whatsapp_reveal_tokens` with `user1_consent = TRUE` or `user2_consent = TRUE`.
- **FR-09.2 (Ad Progression Counter):**
  - User 1 watches Ad 1, 2, 3 $\rightarrow$ Backend increments `user1_ads_count` up to 3 via verified SSV callbacks.
  - User 2 watches Ad 1, 2, 3 $\rightarrow$ Backend increments `user2_ads_count` up to 3 via verified SSV callbacks.
- **FR-09.3 (Threshold & Revelation):**
  - When `user1_ads_count == 3 AND user2_ads_count == 3`:
    - Backend updates `is_unlocked = TRUE`.
    - Generates a cryptographically random `ephemeral_token` valid for 24 hours.
    - Emits WebSocket event `whatsapp_unlocked` to both users.
  - The chat displays a verified Contact Card showing the other user's WhatsApp number with a direct CTA: *"Open in WhatsApp"*.

---

### FR-10: Gamification, Daily Streaks & Badge Hierarchy
- **FR-10.1 (Daily Streak Counter):**
  - A streak is maintained if the user performs at least one qualifying action every 24-hour cycle (Active Login + 10 Swipes + 1 Message sent).
  - Streak is updated in `public.users.streak_count`.
- **FR-10.2 (Badge Tier Progression):**
  - **Tier 1 (Bronze Spark):** 3-day streak + 5 ads supported.
  - **Tier 2 (Silver Flame):** 7-day streak + 15 ads supported.
  - **Tier 3 (Gold Crown):** 30-day streak + 50 ads supported.
  - Badges are displayed on user profile cards in the feed, giving higher algorithmic priority to high-tier users.
- **FR-10.3 (Uninstall Reset Enforcement):**
  - Reinstallation resets `streak_count = 0` and `reward_balance = 0` (via FR-01).

---

### FR-11: Safety, Reporting, Blocking & Grievance Mechanism (IT Rules & UGC)
- **FR-11.1 (Pre-UGC EULA Acceptance):**
  - Onboarding requires explicit acceptance of the End User License Agreement (EULA).
  - Strictly prohibits harassment, abusive language, nudity, impersonation, and solicitation.
- **FR-11.2 (Instant User Blocking):**
  - Available on every profile and chat screen via a 3-dot menu.
  - Tapping "Block" instantly inserts a row into `public.blocked_users`.
  - All existing matches are deactivated (`is_active = FALSE`), chat history is suppressed, and feed profiles are hidden reciprocally.
- **FR-11.3 (In-App Reporting):**
  - User can report profiles or messages selecting reasons: `Harassment`, `Fake Profile / Impersonation`, `Underage`, `Commercial Spam`, `Obscene Content`.
  - Record inserted into `public.user_reports`.
- **FR-11.4 (Statutory 24-Hour Grievance Redressal SLA):**
  - As per IT Rules 2021, parent company **ASI Verticals** publishes Grievance Officer details in app settings:
    - *Grievance Officer:* Resident Grievance Officer, ASI Verticals
    - *Email:* `grievance@asiverticals.com`
    - *Address:* Registered Office, Lucknow, Uttar Pradesh, India
  - Backend admin alert triggers for any account receiving $\ge 3$ distinct reports within 24 hours, initiating immediate account suspension pending review.

---

### FR-12: Account & Complete Data Erasure (DPDP & Play Store Mandate)
- **FR-12.1 (In-App One-Tap Data Erase):**
  - Located under *Profile $\rightarrow$ Account Settings $\rightarrow$ Delete Account & Wipe Data*.
  - Triggers a confirmation dialog: *"This will permanently delete your profile, photos, chat history, and KYC records immediately."*
  - On confirmation:
    - User's photos are deleted from Supabase Storage.
    - User's database record undergoes a hard delete or cascaded purge via foreign key `ON DELETE CASCADE`.
    - Firebase Auth user account is deleted via Admin SDK.
- **FR-12.2 (Public Web Deletion Form):**
  - Hosted at: `https://asiverticals.com/ur-heart/data-deletion`.
  - Accessible via any standard web browser without having the app installed.
  - User submits their registered mobile number + OTP verification to trigger the identical data erasure pipeline.

---

## 5. Data Flow & State Machine Specifications

### 5.1. Authentication & Session Sync State Machine
[User Launches App]
│
▼
[Check Local Sandbox for installation_uuid]
├── Missing? ──► Generate UUID v4 & Save to Sandbox
└── Exists?  ──► Read existing UUID
│
▼
[Firebase Auth (Google One-Tap / Email)] ──► Obtain Firebase ID Token
│
▼
[Call POST /api/v1/auth/session-sync]
(Headers: Bearer , X-Installation-UUID)
│
▼
[FastAPI Verifies Token via Firebase Admin]
│
▼
[Query public.users by auth_id]
├── Not Found? ──► INSERT new user (Save incoming UUID)
└── Found?
├── incoming_uuid == last_installation_uuid?
│      └── Status: OK (Keep Streaks & Rewards)
└── incoming_uuid != last_installation_uuid?
└── Status: RESET (streak_count=0, reward_balance=0, update UUID)


---

### 5.2. Mutual WhatsApp Reveal State Machine
[User A or B Taps "Unlock WhatsApp" in Chat]
│
▼
[Insert/Fetch row in public.whatsapp_reveal_tokens]
│
▼
[User A Watches Rewarded Ads 1, 2, 3] ──► Verified via AdMob SSV Callback ──► user1_ads_count++
[User B Watches Rewarded Ads 1, 2, 3] ──► Verified via AdMob SSV Callback ──► user2_ads_count++
│
▼
[Check Completion: user1_ads_count >= 3 AND user2_ads_count >= 3]
├── NO  ──► Wait for remaining ads (Display progress: e.g., 2/3 and 1/3)
└── YES ──► 1. UPDATE is_unlocked = TRUE
2. Generate ephemeral_token (valid for 24h)
3. Emit WebSocket event "whatsapp_unlocked"
4. Reveal verified contact cards in chat UI


---

## 6. Non-Functional Requirements (NFR)

### NFR-01: Performance & Latency
- **API Response Time:** 95% of REST endpoints must respond within $< 250$ ms under normal load.
- **OCR Validation SLA:** Photo scan (QR check + Preprocessing + Tesseract OCR) must complete in $< 400$ ms per image.
- **WebSocket Delivery:** Chat messages must achieve end-to-end client delivery in $< 100$ ms on active 4G connections.

### NFR-02: Storage & Free Tier Ceiling Protection
- **Postgres DB Optimization:**
  - Table IDs use UUID v4 (16 bytes) or auto-incrementing `BIGINT` (8 bytes).
  - Enums and short strings constrained to `VARCHAR(10)` or `VARCHAR(20)`.
  - Background PostgreSQL Cron (`pg_cron` / Edge Function) executes every 24 hours:
    - Hard deletes all messages where `created_at < NOW() - INTERVAL '30 days'`.
    - Hard deletes all non-matching `pass` swipes where `created_at < NOW() - INTERVAL '30 days'`.
  - Guarantees database size stays comfortably under 350 MB for 25,000 MAU (well below Supabase 500 MB ceiling).
- **Media Optimization:**
  - Mandatory client-side WebP compression (< 100 KB).
  - 5 photos per user $= 500$ KB per user.
  - 1 GB Supabase Storage supports $2,000+$ active onboarding users simultaneously. KYC videos purged within 48 hours.

### NFR-03: Security & Privacy Mandates
- **Transport Security:** 100% of network traffic enforced over TLS 1.3.
- **Cryptographic SSV:** Ad completion rewards accepted strictly via ECDSA SHA-256 signature verification.
- **Display Protection:** OS-level screenshot and screen recording blocking enforced via `FLAG_SECURE`.
- **Statutory Audit Logs:** User connection metadata (IP address, timestamp, auth ID) logged into `public.legal_audit_logs` and retained for 180 days per CERT-In guidelines, segregated from chat data.

---

## 7. Edge Cases & Resilience Engineering

| Edge Case Scenario | System Behavior & Mitigation |
| :--- | :--- |
| **No Ad Inventory Available (Ad Load Fails)** | Exponential backoff retry (2s, 4s, 8s). If failure persists after 3 attempts, inform user gracefully: *"Ad server busy. Please try again in 1 minute."* Do not block core app navigation. |
| **User Closes Rewarded Ad Prematurely** | AdMob SDK triggers `onAdDismissedFullScreenContent` without calling `onUserEarnedReward`. Backend does not receive SSV callback. Ad counter is **not** incremented. |
| **Network Disconnects During 3rd WhatsApp Ad** | The ad completion callback is transmitted directly from Google AdMob servers to FastAPI backend via SSV. Even if user's mobile data disconnects, the backend records the ad view. On client reconnect, the state synchronizes automatically. |
| **User Attempts Leetspeak / Spaced Digits in Chat** | `chat_sanitizer.py` de-obfuscates text: decomposes NFKD unicode, eliminates spaces/symbols, converts written Hindi/English numbers to digits. 100% caught before database write. |
| **User Attempts Multiple Accounts on Same Device** | Every account registration checks `underage_quarantine` and device installation parameters. If an account was previously banned for harassment, subsequent registrations on the same device identifier are blocked. |

---

## 8. Verification & Acceptance Criteria (For Antigravity QA)

1. **Auth & State Verification:**
   - Fresh install generates unique UUID $\rightarrow$ Backend sets `last_installation_uuid`.
   - App data wipe $\rightarrow$ Next login sends new UUID $\rightarrow$ Backend resets `streak_count = 0` and `reward_balance = 0`.
2. **Anti-Leak Verification:**
   - Uploading a profile photo containing an Instagram handle (`@priya_sharma`) or a phone number triggers `HTTP 422` and upload failure.
   - Sending `"Call me at 9876543210"` or `"insta id: rahul_01"` or `"nau aath saat..."` via chat triggers WebSocket rejection alert 422.
3. **Screenshot Verification:**
   - Attempting a hardware screenshot (`Power + Volume Down`) on Android inside Feed or Chat produces a black image or security error.
4. **WhatsApp Reveal Verification:**
   - WhatsApp number remains encrypted and hidden until both users have completed 3 verified rewarded video ads each.
5. **Account Deletion Verification:**
   - Tapping "One-Tap Data Erase" immediately wipes user row, photos from storage, and terminates session.

---
*Authored & Validated for ASI Verticals / UR-Heart Engineering Pipeline.*