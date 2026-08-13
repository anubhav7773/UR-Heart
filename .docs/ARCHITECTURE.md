# System Architecture Document

**Product Name:** Project RuralHeart  
**Document Version:** 2.0.0  
**Scope:** End-to-End System Architecture, Edge Infrastructure, Data Flow & Security  

---

## 1. Executive System Overview

**Project RuralHeart** is built on a high-concurrency, low-latency micro-services architecture tailored for Tier-2, Tier-3, and rural Indian network conditions (2G/3G/4G bandwidth variability).

+-----------------------------------------------------------------------+
|                         Flutter Mobile App                            |
|             (Cross-Platform UI / AdMob / Razorpay SDK)                 |
+-----------------------------------+-----------------------------------+
|
| HTTPS / WSS (WebSocket)
v
+-----------------------------------------------------------------------+
|                       Cloudflare Edge Network                         |
|             (SSL Termination / Static Asset CDN / WAF)                |
+-----------------------------------+-----------------------------------+
|
v
+-----------------------------------------------------------------------+
|                        FastAPI Backend Engine                         |
|    - Auth Service (JWT / OTP)     - Discovery Engine (PostGIS)        |
|    - Chat & WhatsApp Bridge       - Sachet Monetization (Razorpay)    |
+-----------------------------------+-----------------------------------+
|
+-----------------+-----------------+
|                                   |
v                                   v
+-----------------------------------+   +-------------------------------+
|     Supabase PostgreSQL 15        |   |      Cloudflare R2 Object     |
|   (PostGIS / Spatial Indexing)    |   |    (Compressed WebP Snaps)    |
+-----------------------------------+   +-------------------------------+


---

## 2. Core Architectural Components

### 2.1 Mobile Application (Frontend Layer)
* **Framework:** Flutter 3.x (Dart 3)
* **Design Philosophy:** Dark Theme First (`#121212`), high contrast, offline-first cached UI states.
* **Integrations:**
  * **Google AdMob SDK:** App Open Ads, Native In-Feed Cards, 20-Skip Interstitials, In-Chat Video Overlay Ads.
  * **Razorpay Flutter SDK:** Native UPI payment sheets for ₹9, ₹19, and ₹99 Sachet Passes.
  * **Image Optimization:** Auto-compresses camera/gallery picks to WebP before uploading.

---

### 2.2 API Server Layer (FastAPI Engine)
* **Framework:** Python 3.11 with FastAPI (Asynchronous ASGI via Uvicorn).
* **Key Sub-services:**
  1. **Authentication Engine:** Dual-mode handling for Social OAuth (Google/Meta), Mobile Phone OTP, and Email/Password.
  2. **Micro-Radius Discovery Engine:** Spatial SQL queries via GeoAlchemy2 to fetch cards within a 2 km – 10 km bounding box.
  3. **Chat Engine:** Real-time WebSocket connection router with automatic message counter triggers for the **Safe WhatsApp Bridge**.
  4. **Sachet Monetization Webhook Handler:** Synchronous verification of Razorpay signatures to grant instant feature passes.

---

### 2.3 Database & Storage Layer
* **Database:** PostgreSQL 15 hosted on Supabase.
* **Spatial Extension:** PostGIS (`ST_SetSRID`, `ST_MakePoint`, `ST_DWithin`, `ST_Distance`).
* **Object Storage:** Cloudflare R2 / AWS S3 for user profile images and chat media (served over global CDN).

---

## 3. High-Intent Data Flows

### A. "Chai Date" & Micro-Radius Discovery Flow
1. Mobile app sends user's coarse coordinates (`latitude`, `longitude`) with a target radius (e.g., 5 km).
2. FastAPI queries PostgreSQL using PostGIS `ST_DWithin` on indexed `raw_location`.
3. Results are formatted with spatial distance obfuscation (e.g., *"Within 2 km (Near Saket College area)"*) alongside the user's active `chai_status` badge.

### B. Safe WhatsApp Bridge Unlocking Flow
1. User A sends a message to User B via WebSocket.
2. PostgreSQL trigger `trg_increment_message_count` increments `matches.mutual_message_count`.
3. When count reaches **15**, the trigger sets `is_whatsapp_unlocked = TRUE`.
4. WebSocket broadcasts an `event: "new_message"` with `is_whatsapp_unlocked: true`, instantly revealing contact exchange options on both devices.

### C. Sachet Payment Verification Flow
1. User taps ₹9 "Chai Invite" or ₹19 "Photo Pass".
2. Flutter invokes `POST /payments/create-sachet-order` to get a Razorpay `order_id`.
3. User completes UPI payment via Razorpay.
4. Razorpay sends an authenticated webhook payload to `POST /payments/webhook`.
5. Backend verifies signature and updates `users.is_premium` or creates a record in `chai_invites` table instantly.

---

## 4. Security & Compliance Standards

1. **Location Privacy:** Raw GPS coordinates are never exposed via APIs; only obfuscated landmark text labels are returned to client devices.
2. **Auth Security:** JWTs signed with `HS256` / `RS256` algorithms with configurable token lifetimes.
3. **Database Security:** Supabase Row Level Security (RLS) policies enabled for `users`, `messages`, and `user_photos`.