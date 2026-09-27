# 02_DATABASE_SCHEMA_OPTIMIZATION.md: PRODUCTION DDL, SACRED BRIDGE & ZERO-COST SCALING
# Project: UR-Heart (Mindful Dating Sanctuary)
# Target Database: Supabase PostgreSQL 15 (PgBouncer Transaction Pooler — Port 6543)
# Storage Budget: 500 MB Permanent Free-Tier Allocation (Zero Spillover Guarantee)
# Strategy: Micro-Datatypes, Cascading Shredding (DPDP Sec 12), Automated Purge Cron & Dual-Engine IAP Audit

---

## 1. STORAGE MATHEMATICS & 500MB CEILING ENFORCEMENT

Supabase free tier 500 MB relational database storage allocate karta hai. Unconstrained datatypes (`TEXT` everywhere, 8-byte `BIGINT` for simple flags, ya unpurged chat tables) 50,000 active users par hi database ko choke kar dete hain.

UR-Heart **Micro-Datatype Architecture** enforce karta hai:

### 1.1 Datatype Efficiency Comparison
| Entity / Field | Naive Design (Anti-Pattern) | UR-Heart Micro-Standard | Storage Savings | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **User Ages & Limits** | `BIGINT` (8 bytes) | `INT2` / `SMALLINT` (2 bytes) | **75% reduction** | Age (18–100) and Swipes (0–100) easily fit in signed 2-byte range (-32,768 to +32,767). |
| **Reward Points** | `BIGINT` (8 bytes) | `INT4` / `INTEGER` (4 bytes) | **50% reduction** | Balances up to 2.14 Billion fit safely in 4 bytes. |
| **Status & Bridges** | `TEXT` (1 byte + var length) | `VARCHAR(15)` / `VARCHAR(20)` | Controlled row size | Prevents arbitrary string injection; enforces strict enum bounds. |
| **Booleans & Flags** | `VARCHAR` / `INTEGER` | `BOOLEAN` (1 byte) | **Up to 87%** | Compact representation for verification, incognito, and discreet flags. |
| **Temporary Chats** | Retained indefinitely | **30-Day Auto-Purge Cron** | **90%+ active table reduction** | Chats older than 30 days are automatically shredded. |

### 1.2 Mathematical Proof of 500MB Budget at Scale
* Average `public.users` row width: **~310 bytes**.
  * 100,000 active users = $100,000 \times 310 \text{ bytes} \approx \mathbf{31 \text{ MB}}$.
* Average `public.swipes` row width: **~36 bytes**.
  * Purged daily for 'pass' swipes (>30 days). Static active footprint = **~15 MB**.
* Average `public.messages` row width: **~120 bytes** (Text-only).
  * With 30-day auto-incineration, rolling messages pool = **~120 MB**.
* Composite & Partial Indexes: **~80 MB** (Partial indexes index only non-null/active records).
* Total Relational Footprint: $31 + 15 + 120 + 80 = \mathbf{246 \text{ MB}}$ (Safely below the 500 MB ceiling, leaving >50% headroom for scale!).

---

## 2. PRODUCTION SCHEMA DDL SPECIFICATION

### 2.1 Extensions & Identity Security Definer Helpers

```sql
-- Enable cryptographic UUID and background cron scheduling extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Helper Function: Get Internal User UUID from Supabase Auth Context
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id FROM public.users 
    WHERE auth_id = auth.uid() 
      AND deleted_at IS NULL 
    LIMIT 1;
$$;

-- Helper Function: Verify Active Match Participation
CREATE OR REPLACE FUNCTION public.is_active_match_participant(target_match_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = target_match_id
          AND is_active = TRUE
          AND (user1_id = public.get_current_user_id() OR user2_id = public.get_current_user_id())
    );
$$;

-- Helper Function: Check Blocked Perimeter Between Two Users
CREATE OR REPLACE FUNCTION public.is_user_blocked(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE (blocker_id = public.get_current_user_id() AND blocked_id = target_user_id)
           OR (blocker_id = target_user_id AND blocked_id = public.get_current_user_id())
    );
$$;
2.2 Core Relational Tables (14 Master Production Tables)
SQL


-- ============================================================================
-- 1. USERS TABLE (Identity, Multi-Platform Bridge & Dual-Engine Billing)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(60) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(15) NOT NULL CHECK (gender IN ('Woman', 'Man', 'Non-Binary', 'Other')),
    interested_in VARCHAR(15) NOT NULL CHECK (interested_in IN ('Men', 'Women', 'Everyone')),
    
    -- MULTI-PLATFORM SACRED CONTACT BRIDGE (Beyond WhatsApp)
    contact_bridge_type VARCHAR(20) NOT NULL DEFAULT 'whatsapp' 
        CHECK (contact_bridge_type IN ('whatsapp', 'instagram', 'snapchat', 'telegram', 'signal')),
    contact_bridge_encrypted TEXT NOT NULL,

    -- GEOLOCATION & SANCTUARY PRESENCE
    location_name VARCHAR(100) NOT NULL DEFAULT 'Saket, Ayodhya',
    latitude NUMERIC(9,6) DEFAULT NULL,
    longitude NUMERIC(9,6) DEFAULT NULL,
    bio VARCHAR(500) DEFAULT '',
    profession VARCHAR(80) DEFAULT '',
    education VARCHAR(100) DEFAULT '',
    
    -- DISCOVERY & PREFERENCES
    preferred_age_min INT2 NOT NULL DEFAULT 18 CHECK (preferred_age_min >= 18),
    preferred_age_max INT2 NOT NULL DEFAULT 35 CHECK (preferred_age_max <= 100),
    streak_count INT2 NOT NULL DEFAULT 0,
    reward_balance INT4 NOT NULL DEFAULT 0,
    swipes_remaining INT2 NOT NULL DEFAULT 25,
    direct_letters_count INT2 NOT NULL DEFAULT 1,
    last_installation_uuid VARCHAR(64) DEFAULT NULL,
    referral_code VARCHAR(16) UNIQUE NOT NULL DEFAULT ('SANCTUARY-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 6))),
    
    -- SYSTEM FLAGS & GOVERNANCE
    kyc_status BOOLEAN NOT NULL DEFAULT FALSE,
    is_incognito BOOLEAN NOT NULL DEFAULT FALSE,
    discreet_mode BOOLEAN NOT NULL DEFAULT FALSE,
    night_slumber BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- DUAL-ENGINE MONETIZATION & SOVEREIGN STATUS (90%+ Margin Model)
    subscription_tier VARCHAR(20) NOT NULL DEFAULT 'free' 
        CHECK (subscription_tier IN ('free', 'weekly', 'monthly', 'quarterly', 'lifetime')),
    subscription_expires_at TIMESTAMPTZ DEFAULT NULL,
    is_ad_free BOOLEAN NOT NULL DEFAULT FALSE,
    passport_city VARCHAR(100) DEFAULT NULL,

    -- DPDP ACT COMPLIANCE
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Strategic Partial Indexes for Ultra-Fast Lookups & Minimal RAM
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_feed_filter ON public.users(gender, interested_in, kyc_status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_sub_tier ON public.users(subscription_tier) WHERE subscription_tier <> 'free';
CREATE INDEX IF NOT EXISTS idx_users_incognito ON public.users(is_incognito) WHERE is_incognito = TRUE;

-- ============================================================================
-- 2. SWIPES TABLE (Card Deck Actions & Revisit History)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.swipes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    swipe_type VARCHAR(10) NOT NULL CHECK (swipe_type IN ('like', 'pass', 'superlike')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_actor_target UNIQUE (actor_id, target_id),
    CONSTRAINT chk_no_self_swipe CHECK (actor_id <> target_id)
);

CREATE INDEX IF NOT EXISTS idx_swipes_actor_target ON public.swipes(actor_id, target_id);
CREATE INDEX IF NOT EXISTS idx_swipes_target_type ON public.swipes(target_id, swipe_type);
CREATE INDEX IF NOT EXISTS idx_swipes_created_purge ON public.swipes(created_at) WHERE swipe_type = 'pass';

-- ============================================================================
-- 3. MATCHES TABLE (Mutual Resonances)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    matched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_matches_pair UNIQUE (user1_id, user2_id),
    CONSTRAINT chk_no_self_match CHECK (user1_id <> user2_id)
);

CREATE INDEX IF NOT EXISTS idx_matches_user1 ON public.matches(user1_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_matches_user2 ON public.matches(user2_id) WHERE is_active = TRUE;

-- ============================================================================
-- 4. MESSAGES TABLE (100% Text-Only Encrypted Stream — 30-Day Auto-Purged)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    encrypted_text TEXT NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_match_chronological ON public.messages(match_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_purge ON public.messages(created_at);

-- ============================================================================
-- 5. AD REWARD LEDGER (Rewarded Video Grants Ledger)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ad_reward_ledger (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ssv_transaction_id VARCHAR(100) UNIQUE NOT NULL,
    network VARCHAR(20) NOT NULL CHECK (network IN ('admob', 'inmobi', 'meta', 'unity', 'applovin')),
    ad_type VARCHAR(30) NOT NULL CHECK (ad_type IN ('quick_reflection', 'deep_resonance', 'sacred_bridge_reveal', 'morning_harvest_unlock')),
    reward_points INT4 NOT NULL CHECK (reward_points > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ad_reward_user ON public.ad_reward_ledger(user_id);

-- ============================================================================
-- 6. PROCESSED AD TRANSACTIONS (Cryptographic Replay Attack Prevention)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.processed_ad_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id VARCHAR(150) UNIQUE NOT NULL,
    network VARCHAR(20) NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ad_type VARCHAR(30) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_processed_ads_tx ON public.processed_ad_transactions(transaction_id);

-- ============================================================================
-- 7. IN-APP PURCHASES & WEB STORE AUDIT (90%+ Net Revenue Ledger)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.in_app_purchases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    transaction_reference VARCHAR(150) UNIQUE NOT NULL, -- RevenueCat ID, Razorpay payment_id, or Stripe session_id
    product_identifier VARCHAR(60) NOT NULL,            -- e.g. 'sanctuary_weekly', 'instant_bridge_key'
    store VARCHAR(30) NOT NULL DEFAULT 'google_play' 
        CHECK (store IN ('google_play', 'web_razorpay_india', 'web_stripe_global')),
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    amount_gross NUMERIC(10,2) NOT NULL,
    platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,   -- 15% Google or 2% Razorpay or 2.9% Stripe
    amount_net NUMERIC(10,2) NOT NULL,                  -- Actual in-hand earnings (90%+)
    status VARCHAR(20) NOT NULL DEFAULT 'completed' 
        CHECK (status IN ('pending', 'completed', 'refunded')),
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_iap_user ON public.in_app_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_iap_store ON public.in_app_purchases(store);

-- ============================================================================
-- 8. SACRED CONTACT REVEAL TOKENS (Bilateral 3-Ad Ritual OR Instant Key)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.contact_reveal_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID UNIQUE NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    user1_consent BOOLEAN NOT NULL DEFAULT FALSE,
    user2_consent BOOLEAN NOT NULL DEFAULT FALSE,
    user1_ads_count INT2 NOT NULL DEFAULT 0 CHECK (user1_ads_count <= 3),
    user2_ads_count INT2 NOT NULL DEFAULT 0 CHECK (user2_ads_count <= 3),
    is_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
    ephemeral_token VARCHAR(64) DEFAULT NULL,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reveal_tokens_match ON public.contact_reveal_tokens(match_id);

-- ============================================================================
-- 9. BLOCKED USERS PERIMETER
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason VARCHAR(50) DEFAULT 'unspecified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_blocker_blocked UNIQUE (blocker_id, blocked_id),
    CONSTRAINT chk_no_self_block CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_blocked ON public.blocked_users(blocked_id);

-- ============================================================================
-- 10. GRIEVANCE DOSSIERS (IT Rules 2021 Statutory Redressal SLA)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.grievance_dossiers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    violation_category VARCHAR(30) NOT NULL 
        CHECK (violation_category IN ('harassment', 'explicit_content', 'impersonation', 'underage', 'offplatform_leak')),
    evidence_text VARCHAR(500) DEFAULT '',
    status VARCHAR(15) NOT NULL DEFAULT 'under_review' 
        CHECK (status IN ('under_review', 'actioned', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actioned_at TIMESTAMPTZ DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_grievance_status ON public.grievance_dossiers(status);

-- ============================================================================
-- 11. ADMIN KYC ESCALATIONS (Queue for kshtriyaanubhav9120@gmail.com)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.admin_kyc_escalations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    declared_dob DATE NOT NULL,
    declared_age INT2 NOT NULL,
    groq_match_score INT2 NOT NULL,
    groq_reasoning VARCHAR(255) NOT NULL,
    anchor_photo_url TEXT NOT NULL,
    kyc_video_url TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_at TIMESTAMPTZ DEFAULT NULL,
    reviewed_by VARCHAR(80) DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kyc_escalations_pending ON public.admin_kyc_escalations(status) WHERE status = 'pending';

-- ============================================================================
-- 12. UNDERAGE QUARANTINE REGISTRY (Anti-Brute-Force 18+ Lockout)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.underage_quarantine_registry (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_hash VARCHAR(64) UNIQUE NOT NULL,
    attempted_dob DATE NOT NULL,
    quarantine_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quarantine_lookup ON public.underage_quarantine_registry(device_hash) WHERE quarantine_until > NOW();

-- ============================================================================
-- 13. DATA NOMINEES (DPDP Act 2023 Section 14)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.data_nominees (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    nominee_name VARCHAR(60) NOT NULL,
    nominee_contact VARCHAR(30) NOT NULL,
    relationship VARCHAR(30) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 14. DATA EXPORT REQUESTS (DPDP Act 2023 Section 11 Data Portability)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.data_export_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(15) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'completed', 'expired')),
    export_url TEXT DEFAULT NULL,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_export_user_status ON public.data_export_requests(user_id, status);
3. AUTOMATED 30-DAY PURGE CRON ENGINE (pg_cron)
Storage footprint ko flat rakhne ke liye pg_cron daily raat 03:00 UTC (08:30 AM IST) par automatic cleanup execute karta hai:

SQL


CREATE OR REPLACE FUNCTION public.purge_expired_temporary_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. Purge messages older than 30 days
    DELETE FROM public.messages
    WHERE created_at < NOW() - INTERVAL '30 days';

    -- 2. Purge passed swipes older than 30 days (Allows natural rediscovery & frees rows)
    DELETE FROM public.swipes
    WHERE swipe_type = 'pass'
      AND created_at < NOW() - INTERVAL '30 days';

    -- 3. Clear expired Sacred Contact Reveal tokens older than 48 hours
    UPDATE public.contact_reveal_tokens
    SET ephemeral_token = NULL,
        is_unlocked = FALSE
    WHERE expires_at IS NOT NULL
      AND expires_at < NOW() - INTERVAL '48 hours';

    -- 4. Purge expired legal data exports older than 7 days
    DELETE FROM public.data_export_requests
    WHERE expires_at IS NOT NULL
      AND expires_at < NOW() - INTERVAL '7 days';

    -- 5. Revert expired subscriptions back to Free Tier
    UPDATE public.users
    SET subscription_tier = 'free',
        is_ad_free = FALSE,
        swipes_remaining = 25
    WHERE subscription_expires_at IS NOT NULL
      AND subscription_expires_at < NOW()
      AND subscription_tier <> 'free'
      AND subscription_tier <> 'lifetime';
END;
$$;

-- Schedule cron to run daily at 03:00 UTC
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('daily-storage-purge-job') 
        FROM cron.job 
        WHERE jobname = 'daily-storage-purge-job';

        PERFORM cron.schedule(
            'daily-storage-purge-job',
            '0 3 * * *',
            'SELECT public.purge_expired_temporary_records();'
        );
    END IF;
END $$;
4. TIMESTAMP AUTO-UPDATE TRIGGERS
SQL


CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_users_updated_at ON public.users;
CREATE TRIGGER tr_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_reveal_tokens_updated_at ON public.contact_reveal_tokens;
CREATE TRIGGER tr_reveal_tokens_updated_at
    BEFORE UPDATE ON public.contact_reveal_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
5. ANTIGRAVITY VERIFICATION & AUDIT ASSERTIONS
Antigravity agent ko Phase 1 execute karte waqt nimn specifications check karni hain:

Table Count Assertion: Supabase schema browser mein exactly 14 tables live honi chahiye.

Sacred Bridge Enforcement: Verify karein ki users.contact_bridge_type check constraint sirf ('whatsapp', 'instagram', 'snapchat', 'telegram', 'signal') allow kare.

IAP Audit Columns: Verify karein ki in_app_purchases table mein store, amount_gross, platform_fee, aur amount_net successfully create huye hain.

Cascading Deletion Check: Har foreign key relation par ON DELETE CASCADE bind hona chahiye taaki parent user delete hone par DPDP Section 12 ke mutabik complete data zero residual storage mein shread ho sake.

Idempotency: Pure SQL script ko dobara run karne par koi crash ya duplicate errors nahi aane chahiye (IF NOT EXISTS assertions).

