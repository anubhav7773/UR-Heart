# UR-Heart Sanctuary — Comprehensive Product & Feature Architecture Specification
**Document Version:** 2.0.0 (Production Master)  
**Author:** Principal Engineering & Product Management (20+ Years Systems Architecture Experience)  
**Audience:** External AIs, Systems Engineers, Product Leads, Security Auditors  
**Project Scope:** Full-Stack (Flutter Mobile Client + FastAPI / PostgreSQL Backend + Multi-Model AI Cluster)  

---

## 1. Executive Summary & Core Philosophy

**UR-Heart Sanctuary** is an anti-superficial, privacy-first connection sanctuary engineered under the strict statutory guidelines of the **Digital Personal Data Protection (DPDP) Act 2023 (India)**. Unlike conventional swipe apps driven by gamified dopamine loops, UR-Heart is architected around:
1. **Awaaz & Soul First ("Awaaz Jhooth Nahi Bolti"):** Voice sparks, ephemeral dialogues, and veiled photographs supersede superficial facial snap-judgments.
2. **Equal Perks & Zero Class Discrimination:** 1:1 value parity across all features. Any perk unlockable via micro-purchases (e.g., ₹29) is equally unlockable 100% free via mindful 30-second reflection ads. Wealthy seekers receive zero algorithmic priority over mindful free seekers.
3. **Statutory Privacy Shield:** Hardware-level screenshot blocking, zero raw media URL leaks, 35px bilateral photo veil, and automated right-to-be-forgotten data incineration.
4. **Three-Tier AI Intelligence (Eva):** Identity & Biometric KYC Sentinel, 24/7 Mindful Companion with Statutory Escalation Sentinel, and Gemini-Powered Realtime Dialogue Wingman.

---

## 2. Global Architecture & Systems Matrix

```
                      ┌──────────────────────────────────────────┐
                      │          UR-Heart Client (Flutter)       │
                      │   - Riverpod State Architecture          │
                      │   - Dual Theme (Light & Dark Sanctuary)  │
                      │   - WindowSecurityService (DPDP Shield)  │
                      └────────────────────┬─────────────────────┘
                                           │ HTTPS / WSS
                                           ▼
                      ┌──────────────────────────────────────────┐
                      │          FastAPI Cloud Core Engine       │
                      │   - PostgreSQL Database (Asyncpg / ORM)  │
                      │   - JWT / Firebase Auth Hybrid           │
                      │   - Ad Server-Side Verification (SSV)    │
                      └───────┬────────────┬─────────────┬───────┘
                              │            │             │
           ┌──────────────────┘            │             └──────────────────┐
           ▼                               ▼                                ▼
┌─────────────────────┐         ┌─────────────────────┐          ┌─────────────────────┐
│  AI Engine 1        │         │  AI Engine 2        │          │  AI Engine 3        │
│  Eva Identity & KYC │         │  Eva Companion Chat │          │  Gemini Wingman     │
│  - Groq / OpenRouter│         │  - 24/7 Support     │          │  - Realtime 1-on-1  │
│  - Vision Liveness  │         │  - Safety Sentinel  │          │  - Dynamic 3 Sparks │
│  - Bio Polishing    │         │  - App Guardrails   │          │  - Coach Insights   │
└─────────────────────┘         └─────────────────────┘          └─────────────────────┘
```

---

## 3. Deep Feature-by-Feature Specification

---

### Feature 1: Blind Pulse (Sanctuary Blind Date)
* **Core Philosophy:** Connection stripped of superficial judgments. Soul dialogue and voice first.
* **Source Files:**
  * Frontend: `lib/features/blind_date/presentation/screens/blind_date_hub_screen.dart`, `blind_date_session_screen.dart`, `blind_date_controller.dart`
  * Backend: `backend/app/api/v1/endpoints/blind_date.py`, `backend/app/services/blind_date_matcher.py`
* **Mechanics & Flow:**
  1. **Eligibility Check:** User enters queue using a daily streak pass or stored bonus passes.
  2. **Mathematical 3-Gender Matching:**
     * Accurately supports **Men**, **Women**, and **Non-Binary / Gender-Expansive** seekers.
     * Enforces strict bidirectional compatibility: $Gender_B \in Pref_A \land Gender_A \in Pref_B \land Age_B \in [MinAge_A, MaxAge_A] \land Age_A \in [MinAge_B, MaxAge_B]$.
  3. **Veiled Session:**
     * Duration: Exactly **5 minutes (300 seconds)** countdown timer.
     * Partner photo heavily blurred with a 35px blur radius (`sigmaX: 35, sigmaY: 35`).
     * Real 7-second **Voice Spark** audio player playable directly on the veiled card.
     * Eva AI generates a soulful icebreaker prompt (e.g., *"What is a quiet dream you hold close to your heart?"*).
  4. **In-Session Extension Perk (+3 Minutes):**
     * When $\le 60\text{ seconds}$ remain, seekers can extend the session by $+180\text{ seconds}$ (up to 3 times per session).
  5. **Mutual Resonance Gate:**
     * At session conclusion, both parties must tap **"Resonate"**.
     * If both tap "Resonate": Veil lifts, photos reveal, and match transitions into a direct dialogue chat.
     * If either taps "Mindful Bow": Session concludes with graceful closure; zero penalty.
* **Perks & Pricing (Equal Parity):**
  * **Daily Streak Pass:** 1 Free pass per day (requires maintaining an active 24h streak).
  * **Bonus Passes:** Watch 1 rewarded ad (30s) OR unlock instant pass for **₹29**.
  * **Session Extension (+3m):** Watch 1 rewarded ad (30s) OR unlock instant extension for **₹29**.
  * **Fast-Track Radar:** **Free for all users** (Equal VIP toggle, orders matchmaking queue by join timestamp with zero class discrimination).
* **Validity & Reset:** Daily streak pass resets at 00:00 UTC; session countdown strictly expires at 0s unless extended.

---

### Feature 2: Anti-Ghosting & Mindful Closure
* **Core Philosophy:** Dating without unresolved anxiety. Concluding connections with dignity, empathy, and grace.
* **Source Files:**
  * Frontend: `lib/features/chat/presentation/widgets/chat_detail_action_bar.dart`, `chat_dialogue_screen.dart`
  * Backend: `backend/app/services/mindful_closure.py`, `backend/app/api/v1/endpoints/chat_api.py`
* **Mechanics & Flow:**
  1. **48-Hour Inactivity Detection:**
     * If no message is sent in an active match for 48 consecutive hours, the thread status is flagged as `stagnant`.
     * Eva AI companion gently intervenes, offering seekers closure reflections.
  2. **Pass with Grace (One-Tap Mindful Closure):**
     * Instead of vanishing (ghosting), a user taps "Pass with Grace" and selects from 4 compassionate templates:
       1. *Gentle Wavelengths:* "It was truly wonderful crossing paths, but I feel our wavelengths didn't quite align. Wishing you warmth and light! 🌸"
       2. *Self-Reflection & Space:* "Stepping back to focus on myself and my own space right now. Thank you deeply for the dialogue! ✨"
       3. *Seeking Different Resonance:* "I deeply appreciated our conversations, though I'm seeking a different resonance right now. 🙏"
       4. *Silent Mindful Bow:* "A respectful silent bow. Softly concluding this dialogue without lingering unsaid words. 🍃"
       5. *Custom Compassionate Note.*
  3. **Execution & Non-Punitive Delivery:**
     * The closure note is stored encrypted in the chat transcript.
     * Thread is gracefully archived into **"Past Reflections"**.
     * Partner receives a soft, non-punitive push notification: *"Gentle note from [Name] 🍃 - Wishing you warmth on your path."*
     * Real-time WebSocket event updates UI instantly with zero negative shock.
* **Perks & Validity:** Unlimited and 100% free for all users. Cannot be undone once sealed.

---

### Feature 3: Sacred Bridge (WhatsApp & Contact Reveal)
* **Core Philosophy:** Personal phone numbers and off-platform identities must never be exposed without bilateral, conscious consent.
* **Source Files:**
  * Frontend: `lib/features/chat/presentation/widgets/sacred_bridge_app_bar_action.dart`
  * Backend: `backend/app/models/domain/whatsapp_token.py`, `backend/app/api/v1/endpoints/ads_ssv.py`, `backend/app/api/v1/endpoints/web_store.py`
* **Mechanics & Flow:**
  1. Both participants in a mutual dialogue must independently consent to cross the Sacred Bridge.
  2. **Bilateral Unlock Threshold:**
     * User 1 must complete 3 mindful reflection ads (or redeem 1 Reveal Token).
     * User 2 must complete 3 mindful reflection ads (or redeem 1 Reveal Token).
  3. When both reach 3/3 progression, an ephemeral cryptographic token (`token_urlsafe(32)`) is generated.
  4. The verified WhatsApp handle / phone number is unmasked inside the dialogue with a direct WhatsApp launch button.
* **Perks & Pricing (Equal Parity):**
  * Free route: 3 Rewarded ads per user.
  * Instant route: **₹29 ($1.49)** Instant Contact Key (credits 1 Reveal Token).
* **Validity:** Once unlocked, the ephemeral reveal token remains valid for **24 hours**.

---

### Feature 4: 24-Hour Mindful Streak & Profile Boosting Engine
* **Core Philosophy:** Consistency and daily mindfulness over sporadic, compulsive usage.
* **Source Files:**
  * Frontend: `lib/features/rewards/presentation/screens/growth_hub_screen.dart`
  * Backend: `backend/app/services/streak_engine.py`
* **Mechanics & Flow:**
  1. **Daily Ritual:** Seeker watches one 30-second mindful reflection ad every 24 hours.
  2. **Rewards Granted:**
     * $+1$ Streak Count.
     * $+1$ Boost Point.
     * $+25\%$ Discovery Deck Priority multiplier (stacks up to $+300\%$).
     * Protects stored Reveal Tokens.
     * Unlocks the Daily Free Pass for Blind Pulse.
  3. **Loss Aversion Decay Penalty:**
     * If user misses the 24-hour cycle ($now > streak\_expires\_at$):
       * Streak count resets to **0**.
       * Boost points penalized by **$-2$**.
       * **1 Reveal Token is deducted / incinerated**.
       * In-app push notification: *"🥀 Streak Broken & Profile Downgraded"*.
  4. **Proactive Protection:** Push alert sent at **T-4 hours** before streak expiry.
* **Validity:** Exactly **24 hours (86,400 seconds)** per claim. Minimum 4-hour cooldown between claims.

---

### Feature 5: Discovery Deck & Swipe Quota
* **Core Philosophy:** Mindful evaluation of candidate profiles without endless mindless swiping.
* **Source Files:**
  * Frontend: `lib/features/feed/presentation/screens/feed_screen.dart`
  * Backend: `backend/app/api/v1/endpoints/feed.py`, `backend/app/api/v1/endpoints/ads_ssv.py`
* **Mechanics & Quotas:**
  * **Daily Base Quota:** **10 Sovereign Swipes** per 24 hours.
  * **Quota Refill Mechanisms:**
    1. *Quick Reflection Ad:* 10-second rewarded ad grants **+10 Swipes** + 10 points.
    2. *Deep Resonance Ad:* 20-second rewarded ad grants **+1 Direct Letter** + 25 points.
    3. *Slumber / Morning Harvest:* Rest-hour multiplier based on sleep hours:
       * $\ge 8\text{ hrs rest} \implies 2.0\times\text{ bonus}$.
       * $\ge 6\text{ hrs rest} \implies 1.5\times\text{ bonus}$.
    4. *Direct Purchase Packs:* Weekly (110 Swipes), Monthly (550 Swipes).
* **Direct Letters / Notes:** Allows a seeker to attach a heartfelt direct note that bypasses the standard swipe stack and appears highlighted in the recipient's priority inbox.

---

### Feature 6: Eva AI Three-Engine Intelligence Architecture
* **Source Files:**
  * Engine 1: `backend/app/services/eva_identity_engine.py`
  * Engine 2: `backend/app/services/eva_companion_engine.py`, `eva_guardrails.py`
  * Engine 3: `backend/app/services/gemini_wingman_engine.py`
  * Gateway: `backend/app/api/v1/endpoints/ai_sanctuary.py`, `ai_cluster.py`

#### Engine 1: Eva Identity & Biometric KYC Sentinel
* **Responsibilities:**
  1. **Video KYC & Liveness Verification:** Validates user video frames using Groq Vision and OpenRouter Vision failovers. Performs biometric face matching against profile photos.
  2. **Age & Underage Quarantine:** Flags users under 18 years; automatically routes underage accounts to quarantine per statutory guidelines.
  3. **High-Fidelity Bio Polishing:** Transforms 2–3 raw keywords into poetic, authentic sanctuary bios without generic clichés.

#### Engine 2: Eva Sanctuary Companion & 24/7 Support Sentinel
* **Responsibilities:**
  1. **Mindful Companion Dialogue:** Emotionally intelligent, empathetic conversation on relationship goals, loneliness, and personal values.
  2. **Strict App-Boundary Guardrails:** Denies out-of-scope queries (e.g., coding, stock picks, academic homework, partisan politics) with gentle sanctuary wisdom.
  3. **10% Critical Escalation Sentinel:** Detects critical intents (harassment, payment issues, self-harm, legal threats, human support requests) and automatically creates admin escalation tickets.
  4. **Chat Dialogue Sparks:** Contextual bonding spark prompts injected into 1-on-1 chats to rekindle stagnant conversations.

#### Engine 3: Gemini Dialogue Wingman
* **Responsibilities:**
  1. Analyzes profiles of both seekers and recent 10 messages in direct chat.
  2. Generates **3 tailored reply suggestions**:
     * 🔥 *Playful Spark* (lighthearted banter & charm)
     * 🌱 *Deep Resonance* (values-aligned authenticity)
     * ☕ *Smooth Segue* (low-pressure bridge)
  3. Provides a private *Coach Insight Note* advising on conversational tone.
  4. Powered by Google Gemini API with seamless failover to Groq/OpenRouter.

---

### Feature 7: DPDP Act 2023 Statutory Privacy & Security Shield
* **Core Philosophy:** Complete legal compliance with the Indian Digital Personal Data Protection Act 2023.
* **Source Files:**
  * Frontend: `lib/features/chat/presentation/services/window_security_service.dart`, `lib/features/legal_vault/`
  * Backend: `backend/app/services/data_incinerator_service.py`, `backend/app/api/v1/endpoints/legal_compliance.py`, `account_incinerator.py`
* **Provisions & Rules:**
  1. **FLAG_SECURE Hardware Shield:**
     * Prevents screenshots and screen recording across all sensitive screens: Chats, Feed, Profile, Resonances, Blind Pulse, and AI Sanctuary.
     * Sovereign founder / superadmin bypass (`asiverticals@gmail.com`) for marketing asset generation and Play Store recordings.
  2. **35px Bilateral Photo Veil:** Photos in Blind Pulse cannot be inspected in raw HTTP payloads or screens until bilateral mutual resonance.
  3. **Right to Data Portability:** Users can request an instant cryptographically signed PDF export of their entire personal data dossier (`/legal/export-my-data`).
  4. **Account Incinerator (Right to be Forgotten):**
     * Complete, irreversible cryptographic erasure of user PII, photos, KYC videos, messages, and tokens within statutory timeframe.
     * Zero soft-delete remnants for verified deletion requests.

---

### Feature 8: Authentication, Age Gate & Onboarding
* **Source Files:**
  * Frontend: `lib/features/auth/presentation/screens/age_gate_auth_screen.dart`, `neutral_dob_wheel.dart`, `consent_screen.dart`
  * Backend: `backend/app/api/v1/endpoints/auth.py`, `backend/app/services/email_service.py`
* **Mechanics & Flow:**
  1. **Statutory 18+ Age Gate:** Neutral date-of-birth scroll wheel with strict client & backend validation ($Age \ge 18$). Users under 18 cannot proceed.
  2. **Statutory Consent Accordion:** Discloses data processing terms, DPDP compliance, and grievance officer contact before account creation.
  3. **Google One Tap & Magic Link:**
     * Supports Google One Tap native sign-in and passwordless email OTP magic link.
     * **10–15 Second Delayed Welcome Email:** Welcome email dispatch is intentionally queued to arrive 10–15 seconds after signup so the seeker completes setup without distracting notification badges.

---

### Feature 9: Dual Theme Design System (Light & Dark Sanctuary)
* **Source Files:**
  * `lib/core/theme/dark_sanctuary_tokens.dart`, `light_sanctuary_tokens.dart`, `theme_controller.dart`
* **Specification:**
  * **Light Sanctuary:**
    * Canvas: Warm Cream (`#F9F6F0`)
    * Cards & Surfaces: Pure White (`#FFFFFF`)
    * Borders: Soft Beige / Muted Cream (`#E4DFD5`)
    * Text: Deep Charcoal (`#1E2229`), Muted Slate (`#6B7280`)
    * Accents: Sanctuary Pine (`#2D5A43`), Warm Terracotta (`#C85A32`), Sacred Gold (`#B8972E`)
  * **Dark Sanctuary:**
    * Canvas: Midnight Obsidian (`#0F1115`)
    * Cards & Surfaces: Elevated Slate (`#181B20`)
    * Borders: Muted Charcoal (`#22262E`)
    * Text: Crisp Ivory (`#EDEDED`), Soft Grey (`#A0AEC0`)
    * Accents: Glowing Terracotta (`#D97746`), Resonant Gold (`#E5C158`)
  * Dynamically observed via Riverpod (`ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark`) across all 13 feature modules.

---

## 4. Master Quota, Pricing & Perks Reference Table

| Feature / Perk | Free / Ad-Rewarded Route | Instant Paid / Micro Route | Validity / Expiry | Statutory & Technical Conditions |
|---|---|---|---|---|
| **Blind Pulse Matchmaking** | 1 Free Daily Pass (with active streak) | ₹29 per Instant Pass | Consumed upon pairing | Requires 18+, active streak or stored pass, bidirectional demographic compatibility |
| **Blind Pulse In-Session Extension** | Watch 1 Rewarded Ad (30s) | ₹29 per Extension | +180s added to current session | Max 3 extensions per session; must be requested with $\le 60\text{s}$ remaining |
| **Fast-Track Radar** | **100% Free for All Users** | N/A (No paid bypass) | Per queue entry | Equal VIP priority; ordered strictly by join timestamp |
| **Sacred Bridge (Contact Reveal)** | 3 Ads watched by User + 3 Ads by Partner | ₹29 Instant Contact Key (credits 1 Reveal Token) | Token valid for 24 hours | Requires bilateral mutual consent from both parties |
| **Discovery Deck Swipes** | 10 Daily Swipes base + 10 Swipes per 10s ad | Included in Sovereign Passes | Resets every 24h at 00:00 UTC | Slumber Harvest rest bonus applies ($\ge 8\text{h} = 2.0\times$) |
| **Direct Letters / Notes** | 1 Letter per 20s Ad | ₹49 for 3-Pack (Micro) | Non-expiring until sent | Bypasses standard swipe stack into recipient priority queue |
| **24h Daily Streak** | Watch 1 Rewarded Ad (30s) | N/A | Exactly 24 hours | Missing cycle resets streak to 0, penalizes -2 boost pts, deducts 1 reveal token |
| **Profile Discovery Boost** | Granted via Streak Engine (+25% per pt) | Part of Sovereign Pass tiers | Active while streak $\ge 1$ | Stacks up to +300% discovery priority |
| **1-Week Sovereign Sprint** | N/A | **₹49 ($4.99)** | 7 Days | 110 Swipes (+10% web bonus), 10 reflections, 100% ad-free, instant fast pass |
| **1-Month Sovereign Pass** | N/A | **₹149 ($14.99)** | 30 Days | 550 Swipes, 6 Direct Letters, 100% ad-free, Eva priority counsel, VIP badge |
| **1-Year Sovereign Pass** | N/A | **₹1,499 ($59.99)** | 365 Days | Infinite resonances for 1 year, 11 Direct Letters, 365d Sovereign Crest, Full Legal Export |
| **24h Global Passport** | N/A | **₹99 ($1.99)** | 24 Hours | Teleport to any world city (London, NYC, Mumbai, Delhi) + 10 bonus swipes |
| **Mindful Closure (Pass with Grace)** | **100% Free & Unlimited** | N/A | Permanent archive | Available on any active match; cannot be undone once sealed |
| **Eva AI Companion Chat** | **100% Free for All Users** | Priority bandwidth in Passes | 24/7 Availability | Restricted to relationship & sanctuary topics; out-of-scope questions denied |
| **Gemini Dialogue Wingman** | **100% Free in 1-on-1 Chats** | N/A | Per request | 3 dynamic tailored options; Roman Hindi & English output |
| **Data Dossier Export** | **100% Free (Statutory DPDP)** | N/A | Instant PDF generation | Validated user auth token required |
| **Account Erasure (Incinerator)** | **100% Free (Statutory DPDP)** | N/A | Irreversible execution | Permanently deletes PII, biometric KYC videos, messages, and tokens |

---

## 5. Security & Verification Checklists for Engineering & Audits

### Ad Server-Side Verification (SSV) Audit
* Handled at `backend/app/api/v1/endpoints/ads_ssv.py`.
* Verifies ECDSA ASN.1 DER cryptographic signatures against official Google AdMob public keys cached at `https://gstatic.com/admob/reward/verifier-keys.json`.
* Enforces HMAC-SHA256 signatures for Meta, Unity, Chartboost, and Liftoff networks.
* Anti-abuse throttle prevents automated bot claims ($<2\text{s}$ cooldown rejection).

### Biometric KYC Verification Audit
* Handled at `backend/app/services/eva_identity_engine.py` and `backend/app/api/v1/endpoints/admin_kyc.py`.
* Biometric face-match threshold $\ge 75\%$.
* Headless OpenCV frame extraction protects server against display environment crashes.
* AI scores below threshold are held in `pending_manual_review` for human review in the Superadmin Desk.

### Window Privacy Shield Audit
* Handled at `lib/features/chat/presentation/services/window_security_service.dart`.
* Enforces native Android `FLAG_SECURE` preventing capture across all 15 sensitive routes.
* Web client uses canvas blur protection stub.
* Founder account (`asiverticals@gmail.com`) automatically bypassed for Play Store asset generation.

---

## 6. Guidance for External AI Consumption

When another AI system ingests this document:
1. **Never suggest pay-to-win mechanics:** Every feature has a guaranteed 100% free mindful reflection ad equivalent.
2. **Never suggest violating DPDP Act 2023:** Screenshot blocking, age gating (18+), and data erasure are non-negotiable legal requirements.
3. **Never bypass mutual consent gates:** Photographs in Blind Pulse unblur ONLY after bilateral resonance; phone numbers reveal ONLY across the Sacred Bridge after bilateral tokens.
4. **Adhere to the Dual Theme System:** Use tokens from `LightSanctuaryTokens` and `DarkSanctuaryTokens` instead of ad-hoc hex codes.
