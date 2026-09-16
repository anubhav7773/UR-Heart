# Product Requirement Document (PRD)
**Project Name:** UR-Heart (Urban & Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Identifier:** URH-PRD-001  
**Version:** 1.0.0-PROD  
**Status:** Approved for Engineering & Product Build  
**Target Release:** Q3 2025  
**Core Target Demographic:** Tier-2, Tier-3 & Semi-Urban India (Ages 18–32)  
**Primary Platforms:** Android (Optimized for Android 9+ & Budget MediaTek/Snapdragon SoC), iOS, Progressive Web App (PWA)

---

## 1. Executive Summary & Problem Statement

### 1.1 Executive Summary
**UR-Heart** is a mobile dating, discovery, and romantic networking platform tailored specifically to the socio-cultural realities of Bharat (Tier-2/3 cities such as Lucknow, Gorakhpur, Patna, Meerut, Indore, and Jaipur). By eliminating paywalls and replacing subscription microtransactions with **gamified, rewarded video ads**, UR-Heart provides 100% free relationship access while establishing trust through strict biometric/OCR safety barriers, anti-leak filters, and legal protections.

### 1.2 The Problem in Tier-2/Tier-3 India
1. **Predatory Monetization:** Western-centric dating apps (Tinder, Bumble, Hinge) lock fundamental utility (likes, direct messaging, undo swipe) behind steep monthly subscriptions (₹800–₹2,000/mo), alienating 85%+ of Tier-2/3 users who have zero disposable income for digital dating.
2. **Social Stigma & Privacy Anxiety:** Female users face significant anxiety over screenshot leaks, blackmail, harassment, and off-platform stalking. 
3. **Off-Platform Leakage & Scams:** Bad actors rapidly solicit WhatsApp numbers or Instagram handles to move users off-platform into unmonitored harassment or financial fraud scenarios.
4. **Complex Gestures & Cognitive Barrier:** Ambiguous swipe physics and unlabelled gesture interfaces lead to high churn among first-time dating app users.

### 1.3 The Solution
- **100% Free Forever via Ad Economy:** Users earn DM tokens and unlock contacts via short, opt-in rewarded video clips.
- **Hardware-Enforced Privacy (`FLAG_SECURE`):** Complete prevention of screen recording and screenshot capture on all messaging and profile viewports.
- **AI Anti-Leak Gatekeeper:** Real-time regex and NLP interception that catches phone numbers, handle drops, and external links before delivery.
- **Mutual WhatsApp 3-Ad Reveal Modal:** Phone numbers are only revealed when **both** parties independently complete 3 ad checkpoints, eliminating unilateral stalking and balancing intent.
- **Bilingual Vernacular Affordance:** Explicit 48dp action buttons with synchronized Hindi/Devanagari microcopy.

---

## 2. Target Persona & User Archetypes

### Archetype A: The Cautious Explorer (Priya, 23, Lucknow)
- **Occupation:** Graduate Student / Content Freelancer.
- **Device:** Budget 4G/5G smartphone (Redmi / Realme / Samsung M-series).
- **Core Needs:** Utmost privacy. Needs guarantee that relatives or peers cannot screenshot her profile or messages. Cannot afford paid subscriptions.
- **Success Metric:** Feels safe chatting in-app without being forced to reveal personal contact details prematurely.

### Archetype B: The Sincere Seeker (Aman, 24, Gorakhpur)
- **Occupation:** Small business employee / Junior professional.
- **Device:** Vivo / Oppo / Poco Android device.
- **Core Needs:** Transparent matching mechanics without deceptive "pay to see who liked you" locks. High willingness to watch 15-30s video ads in exchange for direct DMs and contact unlocks.
- **Success Metric:** Genuine connections verified with Video KYC, avoiding fake bot profiles.

---

## 3. Core Product Features & Architectural Modules

### 3.1 Module 1: Onboarding & Age-Gate Authentication (Screen 1)
- **Neutral Wheel Date-of-Birth Picker:** Mandatory $\ge 18$ year validation. No pre-selected defaults to ensure conscious user declaration.
- **Google One-Tap Auth:** Streamlined, secure Single Sign-On (SSO) with cryptographic token exchange.
- **Bilingual Mobile OTP Fallback:** Verification via SMS/WhatsApp OTP for users without active Google Play account bindings.
- **Legal Safeguards:** Enforced agreement with DPDP Act 2023, EULA Terms of Service, and ASI Verticals Zero-Harassment Charter.

### 3.2 Module 2: Trust Engine & Video KYC (Screen 2)
- **Live AI OCR Guard:** Real-time scanner analyzing photo uploads in $<200$ms. Instant rejection of photos containing phone numbers, QR codes, Instagram (@/IG) watermarks, or illicit imagery.
- **1 Hero + 4 Lifestyle Photo Slots:** Minimum 3 approved photos required before feed publishing.
- **5-Second Dynamic Video Selfie KYC:** User must record a 5-second video clip speaking their name and city. Processed by internal liveness detection models and automatically scheduled for deletion within 24 hours pursuant to the DPDP Act 2023.
- **Dynamic Digital Watermarking:** Embeds invisible steganographic and visible semi-transparent user ID watermarks across profile photos.

### 3.3 Module 3: Discovery Swipe Feed & Rewarded DM Dock (Screen 3)
- **High-Affordance Action Dock:**
  - **Pass Button (`✕`):** 56px circular button with red accent.
  - **Like Button (`❤️`):** 56px circular button with Electric Crimson `#FF2E63`.
  - **Direct DM Star Button (`⭐`):** 68px raised gradient button allowing users to watch a 10s video ad to earn 3 instant Direct DMs without matching.
- **Paced Ad Countdown HUD:** Centered pill displaying swipe pacing (e.g., "Ad in 4 swipes / 4 स्वाइप बाद विज्ञापन") preventing surprise interstitial interruptions.
- **Persistent Safety Indicator:** Top badge certifying active hardware DRM protection (`🔒 FLAG_SECURE`).

### 3.4 Module 4: Hardware-Guarded Chat & AI Anti-Leak Filter (Screen 4)
- **FLAG_SECURE Activation:** Window manager flags prevent screenshots and screen capture at OS display compositor level.
- **Real-Time Anti-Leak Gatekeeper:**
  - Phone number pattern matching (10-digit Indian mobile formats: `+91`, `0`, space/dash separators).
  - Social media handles (Instagram, Snapchat, Telegram, Facebook keywords).
  - External URLs and contact obfuscations (e.g., "nine eight seven six...").
- **Violation UX:** Instant message undelivered status, red alert banner explaining policy, and seamless redirect to the safe Mutual WhatsApp Reveal feature.

### 3.5 Module 5: Mutual WhatsApp 3-Ad Reveal Protocol (Screen 5)
- **Bilateral Ad Gate:** Prevents one-sided contact harvesting. Both User A and User B must independently watch 3 short (15–30s) rewarded video clips.
- **Progress Tracking State Machine:**
  - States: `[0/3] Not Started`, `[1/3] In Progress`, `[2/3] Awaiting Partner / 1 Left`, `[3/3] Mutual Match Unlocked`.
  - Nudge Notifications: Allows users to gently ping their match to complete their ad checkpoints.
- **Zero Financial Cost:** 100% free access subsidized by Google AdMob / Unity Ads / AppLovin SDKs.

### 3.6 Module 6: Streak Vault & DPDP One-Tap Erase (Screen 6)
- **Retention Gamification:** Daily streak counters with "Level / Spark" status (e.g., Level 2: Silver Spark).
- **Ad & Token Ledger:** Transparent display of earned Direct DM credits and lifetime sponsored ads watched.
- **Grievance Redressal Officer Portal:** Directly compliant with India's Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021.
- **One-Tap Data Erase (Danger Zone):** Instant, irreversible purge of all biometric vectors, KYC clips, chat transcripts, and photos, returning an auditable DPDP Act compliance certificate token.

---

## 4. Technical Architecture & Non-Functional Requirements (NFR)

| Parameter | Specification | Acceptance Criteria |
| :--- | :--- | :--- |
| **P95 Latency** | $<250$ms for message delivery | WebSocket / gRPC over TLS 1.3 |
| **Cold Start Time** | $<1.8$s on budget devices (Snapdragon 680 / Helio G88) | Tree-shaken Flutter runtime & asset preloading |
| **Screenshot Security** | `FLAG_SECURE` on Android, `isCaptured` API on iOS | Blacked-out bitmap captured on attempt |
| **Data Storage Compliance** | In-country data residency (AWS ap-south-1 Mumbai) | DPDP Act 2023 compliant |
| **Accessibility** | WCAG 2.1 AA | Minimum contrast ratio $>15:1$, touch targets $\ge 48\times48$dp |
| **Offline Resilience** | SQLite local cache for chats & feed items | Smooth degradation with network reconnection banner |

---

## 5. Monetization & Unit Economics (Ad-Driven Flywheel)

1. **Rewarded Interstitial CPMs:**
   - Target Tier-2/3 Indian Rewarded Video eCPM: $1.20 – $2.80 USD.
   - Paced feed ads every 10 swipes + 3 ads per WhatsApp unlock + 1 ad per 3 Direct DMs.
2. **Projected ARPU (Average Revenue Per User):**
   - Active User: Watches 8–14 video ads daily $\approx$ ₹0.80 – ₹1.60 INR / daily active user.
   - Monthly Projected ARPU: ₹24 – ₹48 INR with zero CAC friction compared to paid dating apps.
3. **Retention Flywheel:**
   - Habit-forming daily flame streaks prevent app uninstallation.

---

## 6. Success Metrics & Key Performance Indicators (KPIs)

- **D1 / D7 / D30 Retention:** Targets $\ge 52\%$ (D1), $\ge 28\%$ (D7), $\ge 16\%$ (D30).
- **Female User Safety CSAT:** $\ge 88\%$ positive sentiment regarding privacy & anti-leak filters.
- **KYC Approval Turnaround:** Median $<60$ seconds for automated video KYC.
- **Mutual WhatsApp Conversion:** $\ge 42\%$ completion rate once initiated by User A.
- **Zero-Tolerance Safety SLA:** 100% of reported accounts quarantined within 15 minutes.

---

*Authored and Approved for ASI Verticals / UR-Heart Product Development Team.*
