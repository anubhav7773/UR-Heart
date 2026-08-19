# 💖 UR HEART — Product Blueprint, Security Architecture & Market Differentiation Report

---

## 1. Executive Summary & Market Motive

### The Problem in Indian Tier-2 & Tier-3 Dating Markets
- **High Scams & Safety Apprehension:** Users (especially women) face significant fear regarding offline meetups, fake profiles, and unsafe locations.
- **Prohibitive Global Pricing:** Western apps (Tinder, Bumble) enforce monthly subscriptions ranging from ₹1,500 to ₹3,000, creating massive drop-offs for high-intent Tier-2/3 users.
- **Privacy & Extortion Vulnerabilities:** Screenshot leaks, identity theft, and GPS coordinate scraping (trilateration) create immense hesitation among privacy-conscious demographics.
- **Online-to-Offline (O2O) Disconnect:** Traditional apps abandon users once matched, offering zero assistance or safety validation for the physical meetup stage.

### The "Ur Heart" Mission
To build India’s first **high-trust, O2O dating ecosystem** customized for Tier-2/3 cities—combining accessible **sachet-based monetization**, zero-leak privacy, verified commercial meetup spots, and a hardware-hardened mobile client.

---

## 2. Core Feature Breakdown & User Journey

### A. Adaptive Discovery Engine
- **Obsidian Dark Theme:** High-contrast, battery-efficient, luxury UI built with Flutter.
- **Radial Distance Indicators:** Real-time distance calculation without exposing coordinates.
- **State Preservation:** Uses `AutomaticKeepAliveClientMixin` and custom lifecycle guards to prevent feed resets during background resume, notifications, or deep navigation.

### B. "Safe Bridge" Privacy & Monetization Framework
- **₹49 Direct DM (Sachet Engagement):** High-intent users can initiate conversations instantly without waiting for a reciprocal swipe.
- **₹499 Safe Bridge Unlock:** Phone numbers, email addresses, social media handles, and external URLs are strictly locked behind a mutual paywall to eradicate spam, bots, and platform leakage.

### C. O2O "Nearby Date Spot Radar" (0–50 km Engine)
- **High-Precision Commercial Venue Engine:** Real-time discovery across 4 strict categories:
  - *Cafes & Bakes*
  - *Restaurants*
  - *Hotels & Lounges*
  - *Chai & Snacks*
- **4-Hour TTL In-Memory Caching:** High-speed response times with multi-mirror Overpass/OSM fallback.
- **Interactive Chat Spot Bubbles:** Suggest spots directly inside chat via native cards featuring category badges, radial distance, and coordinate-locked Google Maps navigation (Zero Pin Drift).

### D. Real-Time Encrypted Chat & Presence
- Low-latency WebSocket transport with cryptographic JWT token handshakes.
- Synchronized read receipts (`POST /read`), active typing indicators, and presence heartbeat management.

---

## 3. Competitive Differentiation Matrix

| Dimension | Standard Global Apps (Tinder/Bumble) | Generic Indian Clones | Ur Heart (Our Platform) |
| :--- | :--- | :--- | :--- |
| **Monetization** | Expensive monthly tiers (₹1,500+) | Aggressive ad walls / Broken checkouts | **Sachet-based intent (₹49 DM / ₹499 Safe Bridge)** |
| **Offline Safety (O2O)** | None (Unassisted) | None | **Integrated 0–50km Date Spot Radar (Verified Commercial Only)** |
| **Screenshot Shield** | Permitted / Weak OS checks | Unprotected | **Hardware-Level `FLAG_SECURE` (Zero screen capture/recording)** |
| **Location Privacy** | Often leaks precise coordinates | Insecure coordinate endpoints | **Strict Anti-Trilateration (Only `distance_km`, Zero raw GPS leak)** |
| **Anti-Scam Defense** | Open text (Spam prone) | Basic string replacement | **Zero-Bypass Safe Bridge with API & Payload-level Regex Enforcement** |
| **Theme & UX** | Generic white UI | Template-based | **Custom Obsidian Dark-Theme with High-Contrast Accents** |

---

## 4. Enterprise-Grade Security Posture (Completed Audit)

```
[ Mobile Client (Flutter) ]
├── Hardware FLAG_SECURE (Blocks screenshots / recordings)
├── FlutterSecureStorage (Encrypted SharedPreferences / Keystore)
├── System-Only Network Security Config (Anti-MitM / Prohibits Cleartext)
└── Release R8 / ProGuard Code Obfuscation
│
▼  (HTTPS / WSS with Cryptographic JWT Handshake)
[ FastAPI Backend Engine ]
├── IDOR / BOLA Participant Guard (403 Forbidden on Unauthorized Chat Access)
├── Sliding-Window Rate Limiter (Chat: 5/5s, Feed: 40/60s, Location: 10/60s)
├── Anti-Trilateration Privacy Filter (Stripped Lat/Lon fields on Feed & Profile)
├── Input Sanitization & XSS Defense (Escapes HTML, strips null bytes)
└── Zero-Bypass Safe Bridge Filter (Blocks external URLs/numbers before unlock)
```

- **IDOR / BOLA Defense:** Verified participant check (`verify_conversation_access`) on all read/write chat operations.
- **GPS Privacy:** Discovery feed (`/api/v1/feed`) and public profile endpoints return only radial distance (`distance_km`), fully stripping raw `latitude` and `longitude`.
- **MitM Protection:** Android `network_security_config.xml` rejects unencrypted HTTP and user-installed proxy CA certificates.
- **Data-at-Rest:** Auth tokens and user IDs are encrypted via Hardware Keystore/Keychain.
- **DoS / Spam Guard:** Multi-tier sliding-window rate limiting on all sensitive endpoints.

---

## 5. Technical Stack

- **Frontend:** Flutter (Dart), Android Keystore / iOS Keychain, WindowManager `FLAG_SECURE`.
- **Backend:** FastAPI (Python 3.11+), Pydantic v2.
- **Database & Persistence:** PostgreSQL / SQLite via SQLAlchemy AsyncSession.
- **Real-Time Layer:** WebSockets with session/zombie management.
- **Push Notifications:** Firebase Cloud Messaging (FCM) with decoupled deep-link routing.
- **Geo-Intelligence:** Overpass API with multi-mirror fallback and native Google Maps intent integration.
- **Quality Assurance:** 40+ automated security and logic tests passing (`pytest`), 0 warnings (`flutter analyze`).
