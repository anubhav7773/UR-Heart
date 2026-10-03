# UR-Heart Sanctuary — Master Admin Panel & Sovereign Command Specification

**Authority**: Asiverticals Pvt Ltd  
**Exclusive Superadmin Identity**: `asiverticals@gmail.com`  
**Security Standard**: Zero-Trust, DPDP Statutory Compliance, Defense-in-Depth  
**Access Model**: Hybrid Architecture (Dedicated Web Portal `https://urheart.asiverticals.me/admin` + Mobile Sentinel Companion)

---

## Architecture & Zero-Vulnerability Access Paradigm

### 1. Primary Command Center: Dedicated Web URL (`/admin`)
- **Isolation**: Admin routes, schemas, and control tools are **NEVER bundled in the consumer mobile APK/AAB**. This completely neutralizes reverse-engineering and APK decompilation attack vectors.
- **Zero-Trust Perimeter**:
  - Exclusively authenticated via Cryptographic Magic Link + Short-Lived JWT (1-hour expiration) issued strictly to `asiverticals@gmail.com`.
  - Rate Limiting via SlowAPI: 5 requests / 15 minutes lockout against brute-force attacks.
  - Strict Content Security Policy (CSP), `X-Frame-Options: DENY`, CSRF tokens, and HttpOnly / SameSite cookies.
  - Desktop-optimized ergonomics: side-by-side video selfie vs anchor photo comparison, multi-column seeker inspection, and live telemetry charts.

### 2. Mobile Sentinel Companion: In-App Emergency Desk
- **Purpose**: Rapid 5-second mobile actions while on the go (approving a high-trust KYC video or freezing a reported scammer).
- **Security**: The "👑 Superadmin KYC Sentinel" tile renders **strictly and exclusively** when `user.email == 'asiverticals@gmail.com'`. It contains zero bulk data export or internal infrastructure code.

---

## 20-Point Feature Matrix (Present & Future Roadmap)

### Tier 1: Core Operations & Trust Sentinel (In-Present Production)

#### 1. User Identity & Seeker Profile Inspector
- **Why you need it**: Customer support, fraud verification, and account moderation require complete visibility into account state.
- **Without it**: Troubleshooting broken profiles or handling user complaints requires manual database SQL queries.
- **Good looks like**: A comprehensive profile inspector showing full name, verified DOB, gender, looking-for, bio, photo gallery with blurhashes, fuzzy GPS coordinates, referral code, and streak metrics with 1-tap Ban, Freeze, or Shadowban controls.

#### 2. KYC Biometric Video Liveness Escalation Desk
- **Why you need it**: When AI Vision (Groq / OpenRouter) detects ambiguous lighting or borderline match scores (40–60%), human sovereign review is required.
- **Without it**: Legitimate seekers are unfairly rejected, or bots spoof the liveness check.
- **Good looks like**: A dedicated desk displaying the profile anchor photo side-by-side with frames from the 3-second live selfie video. 1-tap **Approve** or **Reject** with automated invocation of `purge_ephemeral_kyc_video` to maintain statutory DPDP compliance.

#### 3. Statutory DPDP Grievance & Legal Redressal Desk
- **Why you need it**: India DPDP Act 2023 mandates a formal grievance redressal mechanism with statutory resolution timelines (24-hour initial SLA).
- **Without it**: Heavy statutory fines and platform liability under digital data protection laws.
- **Good looks like**: A priority queue tracking user reports, harassment tickets, nominee registrations, and 1-tap generation of signed cryptographic account incineration certificates (`pdf_generator.py`).

#### 4. Content & Photo Moderation Quarantine Queue
- **Why you need it**: Users may upload inappropriate, copyrighted, violent, or weapon-containing images.
- **Without it**: Harmful content remains visible in discovery feeds, degrading sanctuary trust and violating Google Play policy.
- **Good looks like**: An automated quarantine queue powered by Google Cloud Vision and OpenCV that auto-flags images with high NSFW scores. Admins can review quarantined photos and remove or approve them.

#### 5. Chat Safety & NLP Toxic Message Sentinel
- **Why you need it**: Dating apps face risks of stalking, extortion, off-platform payment scams, and contact-bridge spam.
- **Without it**: Predatory behavior goes unnoticed until an external police report or severe user harm occurs.
- **Good looks like**: A real-time log of messages caught by the pre-storage regex/NLP shield (phone numbers, UPI IDs, hate speech) with context threads and automated scammer freezing.

#### 6. Financial, Store & Sovereign Pass Management
- **Why you need it**: Tracking monetization health, subscription lifecycles, and user billing disputes.
- **Without it**: Discrepancies between RevenueCat, Razorpay, Stripe, and PostgreSQL go unaddressed, leading to chargebacks.
- **Good looks like**: Real-time webhook transaction ledger showing active Sovereign Pass tiers, payment provider IDs, subscription expiration dates, and 1-tap manual tier granting or refund processing.

#### 7. Multi-Network Ads & SSV Monetization Sentinel
- **Why you need it**: Rewarded ads drive daily swipes and revenue; invalid traffic can cause network account bans.
- **Without it**: Bot clicks or spoofed reward callbacks trigger permanent ad provider bans (AdMob, Meta, Unity).
- **Good looks like**: Real-time SSV transaction verification feed for AdMob, Meta Audience Network, Unity Ads, Chartboost, and Liftoff. Displays signature validation status, anti-ban velocity caps, and user reward balances.

#### 8. Push Notifications & Sanctuary Emergency Broadcasts
- **Why you need it**: Critical service announcements, scheduled maintenance alerts, or city-wide engagement boosts.
- **Without it**: Users face unexpected downtime or miss critical safety notifications.
- **Good looks like**: A broadcast console to draft and dispatch instant or scheduled FCM push notifications globally or targeted by city (e.g. Ayodhya, Lucknow, Delhi).

---

### Tier 2: Platform Analytics & System Configuration (In-Present Production)

#### 9. Real-Time Sanctuary Pulse Dashboard
- **Why you need it**: Instant operational awareness of platform vitality.
- **Without it**: Measuring growth requires manually digging through raw database tables or waiting for custom scripts.
- **Good looks like**: A live dashboard surfacing real-time signups today, Daily Active Users (DAU), Monthly Active Users (MAU), swipe velocity, mutual match rate, and daily net revenue.

#### 10. Immutable Audit Logs & Activity History
- **Why you need it**: Strict accountability and security compliance.
- **Without it**: If an account is banned or a setting is altered maliciously or accidentally, there is zero traceability.
- **Good looks like**: An append-only PostgreSQL `admin_audit_logs` table tracking every action taken by `asiverticals@gmail.com` (action, target user, IP address, user-agent, timestamp, and state diff).

#### 11. Dynamic Feature Flags & Remote App Configuration
- **Why you need it**: Operational levers must be adjustable without deploying a new app release.
- **Without it**: Modifying daily swipe quotas or ad cooldowns requires a full development, testing, and app store review cycle.
- **Good looks like**: A remote configuration panel to tune:
  - Daily Free Swipes (Default: 10)
  - Rewarded Ad Cooldown (Default: 120s)
  - Daily Streak Expiration Window (Default: 48h)
  - Rewarded Ad Swipes Bonus (Default: +10)
  - Minimum KYC Age Threshold (Default: 18)

#### 12. Promotional Codes, Gift Passes & Referral Campaign Engine
- **Why you need it**: Growth marketing, influencer partnerships, and offline campus activations.
- **Without it**: Promo campaigns require custom code deployments, slowing down time-sensitive marketing.
- **Good looks like**: A tool to generate high-entropy promo codes (e.g. `SANCTUARY2026`) granting temporary Sovereign Pass access or bonus direct letters, with redemption limits and usage analytics.

#### 13. Vendor, Gateway & Partner Integrations Health Desk
- **Why you need it**: UR-Heart relies on Supabase, Firebase, Resend, Cloudflare R2, Groq, and OpenRouter.
- **Without it**: Third-party outages silently degrade user experience without immediate admin notification.
- **Good looks like**: Live status indicators displaying latency, uptime, and webhook health for all integrated third-party services.

#### 14. Automated Content Moderation Rules & Whitelists
- **Why you need it**: Adapting to evolving slang, regional contact formats, or benign phrases incorrectly flagged.
- **Without it**: False positives annoy genuine seekers, while new spam patterns slip through.
- **Good looks like**: A rules management UI to add or remove regex patterns, modify toxicity score thresholds, and whitelist approved partner domains.

#### 15. Session & Device Security Management
- **Why you need it**: Identifying compromised accounts, credential-stuffing attacks, and multi-accounting abusers.
- **Without it**: Bad actors create dozens of burner accounts on a single physical device to spam discovery feeds.
- **Good looks like**: Device inventory tracking `last_installation_uuid`, active JWT sessions, and client IP addresses, with a 1-tap **Force Logout All Sessions** or **Device Hardware Ban** kill-switch.

#### 16. Force-Update & App Version Gate
- **Why you need it**: Critical security vulnerabilities, database schema migrations, or legal mandates require all users to run the latest app build.
- **Without it**: Outdated client builds continue hitting deprecated endpoints, causing crashes and security risks.
- **Good looks like**: Ability to set `min_supported_version` for Android, iOS, and Web. Also includes an **Emergency Maintenance Mode** toggle that displays a respectful mindful message in the mobile app.

---

### Tier 3: Future-Proof Scaling & AI Operations (Future Roadmap)

#### 17. Eva AI Intelligence & Quota Velocity Monitor
- **Why you need it**: Eva Companion and Identity engines rely on free/tiered API quotas with strict rate limits.
- **Without it**: 429 rate limit spikes silently degrade KYC processing or companion conversations.
- **Good looks like**: Live tracking of Groq and OpenRouter token consumption, 429 error frequency, active model failovers in rotation, and security guardrail refusal triggers.

#### 18. Ephemeral Data & Account Incineration Sentinel
- **Why you need it**: Verifying that deleted accounts and KYC ephemeral videos are genuinely and irrecoverably purged.
- **Without it**: Stale data lingers in S3/R2 storage, violating statutory DPDP "Right to be Forgotten" mandates.
- **Good looks like**: Automated audit dashboard verifying that when a user requests deletion, their moments, blurhashes, chat threads, and biometric tokens are wiped within 24 hours.

#### 19. Anti-Fraud & GPS Spoofing Sentinel
- **Why you need it**: Bad actors use mock location apps to appear in foreign cities for romance scams.
- **Without it**: Trust in "GPS Verified" crests is compromised.
- **Good looks like**: Automated anomaly detection flagging seekers who teleport >200km within 1 hour or exhibit mock location provider flags.

#### 20. Sanctuary Resonance Affinity Matrix Tuning
- **Why you need it**: Fine-tuning the mathematical matchmaking algorithm based on retention and connection outcomes.
- **Without it**: Feed matchmaking cannot adapt to community feedback without redeploying backend code.
- **Good looks like**: Dynamic slider controls to adjust the 5 resonance weights:
  - Interests & Vibe Overlap (Default: 35%)
  - Intentions & Orientation (Default: 25%)
  - Geographic Proximity (Default: 20%)
  - Age Range Harmony (Default: 10%)
  - Sanctuary Presence & Trust (Default: 10%)
