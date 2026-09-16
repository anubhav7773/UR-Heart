# Database Schema, Storage Optimization & Row Level Security (RLS) Specification

**Document Identifier:** URH-DAT-005  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**Database Engine:** PostgreSQL 15+ (Hosted via Supabase Free Tier Quota)  
**Target Infrastructure Ceiling:** 500 MB Database Storage Ceiling ($0.00/month)  
**Integration Protocol:** Supabase MCP (Model Context Protocol) via Antigravity Agent  
**Authentication Identity Provider:** Firebase Authentication (Mapped via `firebase_uid`)

---

## 1. Zero-Cost Storage Architecture (500 MB Database Limit)

To operate UR-Heart for up to 25,000 Monthly Active Users (MAU) within Supabase's strict 500 MB free database quota, data types and table allocations are mathematically constrained:

### 1.1. Data Type Optimization Rules
- **Primary / Foreign Keys:** Standard `UUID` (16 bytes) or auto-incrementing `BIGINT` (8 bytes). Heavy string-based random IDs are strictly prohibited.
- **Counters & Flags:** `INT2` / `SMALLINT` (2 bytes, supports values up to 32,767) for counters like `streak_count`, `user1_ads_count`, `user2_ads_count`. `BOOLEAN` (1 byte) for all binary states.
- **Strings:** Bounded `VARCHAR(10)` to `VARCHAR(64)` rather than unbounded `TEXT` across high-velocity operational tables. Unbounded `TEXT` is permitted only for client-encrypted message payloads (`encrypted_text`).

### 1.2. Mathematical Storage Model (25,000 MAU)
- `users` (25,000 rows × ~280 bytes) $\approx$ **7.0 MB**
- `user_photos` (125,000 rows × ~160 bytes) $\approx$ **20.0 MB**
- `matches` (50,000 active pairs × ~80 bytes) $\approx$ **4.0 MB**
- `messages` (Rolling 30-day active window $\approx$ 1,000,000 messages × ~150 bytes) $\approx$ **150.0 MB**
- `swipes` (Active likes + rolling 30-day passes $\approx$ 500,000 rows × ~48 bytes) $\approx$ **24.0 MB**
- `processed_ad_transactions` (Rolling 60-day ledger $\approx$ 300,000 rows × ~110 bytes) $\approx$ **33.0 MB**
- `legal_audit_logs` (Rolling 180-day CERT-In metadata $\approx$ 600,000 rows × ~90 bytes) $\approx$ **54.0 MB**
- Indexes & System Overhead $\approx$ **75.0 MB**
- **Total Projected Footprint:** $\approx$ **367.0 MB** (Comfortably below the 500 MB hard limit).

---

## 2. Complete Production PostgreSQL DDL

Run the following consolidated DDL script directly via the Supabase MCP or SQL Editor. It creates all tables, foreign key constraints, indexes, and custom validation checks:

```sql
-- =============================================================================
-- UR-HEART (URBAN AND RURAL HEART) - CONSOLIDATED PRODUCTION DATABASE DDL
-- Organization: ASI Verticals
-- Target Engine: PostgreSQL 15+ (Supabase)
-- =============================================================================

-- Enable Cryptographic Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. USERS CORE TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL, -- Mapped from Firebase Auth ID Token
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    whatsapp_number VARCHAR(15) NOT NULL,
    full_name VARCHAR(50) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(10) NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    city VARCHAR(50) NOT NULL,
    bio VARCHAR(250) DEFAULT '',
    streak_count INT2 NOT NULL DEFAULT 0 CHECK (streak_count >= 0),
    reward_balance INT4 NOT NULL DEFAULT 0 CHECK (reward_balance >= 0),
    kyc_status BOOLEAN NOT NULL DEFAULT FALSE,
    kyc_verified_at TIMESTAMPTZ DEFAULT NULL,
    kyc_document_sha256 VARCHAR(64) DEFAULT NULL,
    last_installation_uuid VARCHAR(64) DEFAULT NULL,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partial indexes for optimal querying
CREATE INDEX idx_users_firebase_uid ON public.users(firebase_uid) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_feed_discovery ON public.users(city, gender) WHERE deleted_at IS NULL AND is_banned = FALSE;

-- =============================================================================
-- 2. USER PHOTOS TABLE (Slots 1 to 5)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.user_photos (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    slot_index INT2 NOT NULL CHECK (slot_index BETWEEN 1 AND 5),
    photo_storage_path TEXT NOT NULL, -- Supabase Storage object path: user-photos/{user_id}/slot_{x}.webp
    blur_hash VARCHAR(64) NOT NULL,
    ocr_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_photo_slot UNIQUE (user_id, slot_index)
);

CREATE INDEX idx_user_photos_user ON public.user_photos(user_id);

-- =============================================================================
-- 3. SWIPES TABLE (With Rolling 30-Day Retention on Passes)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.swipes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    swipe_type VARCHAR(10) NOT NULL CHECK (swipe_type IN ('like', 'pass', 'direct_dm')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_actor_target_swipe UNIQUE (actor_id, target_id),
    CONSTRAINT check_cannot_swipe_self CHECK (actor_id <> target_id)
);

CREATE INDEX idx_swipes_actor_target ON public.swipes(actor_id, target_id);
CREATE INDEX idx_swipes_pass_cleanup ON public.swipes(created_at) WHERE swipe_type = 'pass';

-- =============================================================================
-- 4. MATCHES TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_match_pair UNIQUE (user1_id, user2_id),
    CONSTRAINT check_distinct_match_users CHECK (user1_id <> user2_id)
);

CREATE INDEX idx_matches_user1 ON public.matches(user1_id) WHERE is_active = TRUE;
CREATE INDEX idx_matches_user2 ON public.matches(user2_id) WHERE is_active = TRUE;

-- =============================================================================
-- 5. MESSAGES TABLE (Encrypted Payloads, 30-Day Purge Window)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    encrypted_text TEXT NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_match_chronological ON public.messages(match_id, created_at DESC);
CREATE INDEX idx_messages_purge ON public.messages(created_at);

-- =============================================================================
-- 6. WHATSAPP REVEAL TOKENS TABLE (Dual 3-Ad State Machine)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.whatsapp_reveal_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID UNIQUE NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    user1_consent BOOLEAN NOT NULL DEFAULT FALSE,
    user2_consent BOOLEAN NOT NULL DEFAULT FALSE,
    user1_ads_count INT2 NOT NULL DEFAULT 0 CHECK (user1_ads_count BETWEEN 0 AND 3),
    user2_ads_count INT2 NOT NULL DEFAULT 0 CHECK (user2_ads_count BETWEEN 0 AND 3),
    is_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
    ephemeral_token VARCHAR(64) DEFAULT NULL,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wa_tokens_match ON public.whatsapp_reveal_tokens(match_id);

-- =============================================================================
-- 7. PROCESSED AD TRANSACTIONS (Replay-Proof Idempotency Ledger)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.processed_ad_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id TEXT UNIQUE NOT NULL, -- Network-supplied unique transaction/event ID
    network VARCHAR(20) NOT NULL CHECK (network IN ('admob', 'inmobi', 'meta', 'applovin', 'unity')),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ad_type VARCHAR(30) NOT NULL CHECK (ad_type IN ('feed_interstitial', 'direct_dm_reward', 'whatsapp_reveal')),
    reward_amount INT4 NOT NULL DEFAULT 1,
    raw_custom_data TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ad_tx_user ON public.processed_ad_transactions(user_id);
CREATE INDEX idx_ad_tx_created ON public.processed_ad_transactions(created_at);

-- =============================================================================
-- 8. UGC: BLOCKED USERS & REPORTS (Play Store Review Shield)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_block_relation UNIQUE (blocker_id, blocked_id),
    CONSTRAINT check_cannot_block_self CHECK (blocker_id <> blocked_id)
);

CREATE INDEX idx_blocked_users_blocker ON public.blocked_users(blocker_id);
CREATE INDEX idx_blocked_users_blocked ON public.blocked_users(blocked_id);

CREATE TABLE IF NOT EXISTS public.user_reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL CHECK (
        reason IN ('harassment_bullying', 'ncii_nudity', 'fake_impersonation', 'underage_user', 'commercial_spam', 'other')
    ),
    details VARCHAR(500) DEFAULT '',
    context_match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL,
    is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
    action_taken VARCHAR(50) DEFAULT 'none' CHECK (
        action_taken IN ('none', 'warning_issued', 'profile_quarantined', 'permanent_ban', 'false_report')
    ),
    reviewed_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_reported_id ON public.user_reports(reported_id);
CREATE INDEX idx_reports_unreviewed ON public.user_reports(is_reviewed) WHERE is_reviewed = FALSE;

-- =============================================================================
-- 9. UNDERAGE QUARANTINE REGISTRY (18+ Device Lock)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.underage_quarantine (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_phone_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256(Android_ID + Phone)
    quarantined_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    attempt_count INT2 NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quarantine_hash ON public.underage_quarantine(device_phone_hash);

-- =============================================================================
-- 10. STATUTORY LEGAL & AUDIT TABLES (DPDP Act & CERT-In 180-Day Mandate)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.legal_audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL, -- 'AUTH_LOGIN', 'KYC_SUBMIT', 'WA_REVEAL_UNLOCK', 'ACCOUNT_PURGE'
    ip_address INET NOT NULL,
    client_port INT4 DEFAULT NULL,
    user_agent TEXT NOT NULL,
    installation_uuid VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user ON public.legal_audit_logs(user_id);
CREATE INDEX idx_audit_logs_ip ON public.legal_audit_logs(ip_address);
CREATE INDEX idx_audit_logs_created ON public.legal_audit_logs(created_at);

CREATE TABLE IF NOT EXISTS public.consent_records (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    consent_purpose VARCHAR(50) NOT NULL, -- 'VIDEO_KYC_BIOMETRIC', 'WHATSAPP_DATA_SHARE', 'TERMS_EULA'
    consent_given BOOLEAN NOT NULL DEFAULT TRUE,
    consent_notice_version VARCHAR(20) NOT NULL,
    ip_address INET NOT NULL,
    user_agent TEXT NOT NULL,
    withdrawn_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consent_user ON public.consent_records(user_id);

CREATE TABLE IF NOT EXISTS public.grievance_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number VARCHAR(32) UNIQUE NOT NULL,
    complainant_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    complainant_email VARCHAR(255) NOT NULL,
    complainant_phone VARCHAR(20) DEFAULT NULL,
    reported_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    category VARCHAR(50) NOT NULL CHECK (
        category IN ('ncii_nudity', 'impersonation', 'harassment', 'underage', 'fraud_scam', 'other')
    ),
    incident_description TEXT NOT NULL,
    evidence_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_urgent_24h_sla BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'received' CHECK (
        status IN ('received', 'acknowledged', 'under_investigation', 'resolved', 'rejected')
    ),
    resolution_notes TEXT DEFAULT NULL,
    acknowledged_at TIMESTAMPTZ DEFAULT NULL,
    resolved_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_grievance_status ON public.grievance_tickets(status);
CREATE INDEX idx_grievance_24h_sla ON public.grievance_tickets(is_urgent_24h_sla) WHERE status != 'resolved';
3. Database Security Helper FunctionsFastAPI communicates with Supabase using custom JWTs (or headers) mapping Firebase Authentication. The following helper functions ensure that Row Level Security policies execute efficiently:SQL-- Helper Function 1: Extract Internal User UUID from Firebase UID claim
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID AS $$     SELECT id FROM public.users      WHERE firebase_uid = auth.jwt() ->> 'sub'      LIMIT 1; $$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper Function 2: Check if two users have an active mutual block
CREATE OR REPLACE FUNCTION public.is_mutually_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN AS $$SELECT EXISTS (         SELECT 1 FROM public.blocked_users         WHERE (blocker_id = user_a AND blocked_id = user_b)            OR (blocker_id = user_b AND blocked_id = user_a)     );$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper Function 3: Check if current user is an active participant in a match
CREATE OR REPLACE FUNCTION public.is_match_participant(match_uuid UUID)
RETURNS BOOLEAN AS $$     SELECT EXISTS (         SELECT 1 FROM public.matches         WHERE id = match_uuid           AND is_active = TRUE           AND (user1_id = public.get_current_user_id() OR user2_id = public.get_current_user_id())     ); $$ LANGUAGE sql STABLE SECURITY DEFINER;
4. Comprehensive Row Level Security (RLS) PoliciesAll public tables must have RLS explicitly enabled. The Service Role (used by the FastAPI backend microservice) bypasses RLS automatically. These policies protect direct client-side reads via Supabase Flutter Client:SQL-- Enable RLS across all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_reveal_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_ad_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.underage_quarantine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grievance_tickets ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- POLICIES: USERS
-- =============================================================================
CREATE POLICY "Users can view active, unblocked profiles in discovery"
ON public.users FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL 
    AND is_banned = FALSE 
    AND NOT public.is_mutually_blocked(id, public.get_current_user_id())
);

CREATE POLICY "Users can update their own profile fields"
ON public.users FOR UPDATE
TO authenticated
USING (id = public.get_current_user_id())
WITH CHECK (id = public.get_current_user_id());

-- =============================================================================
-- POLICIES: USER PHOTOS
-- =============================================================================
CREATE POLICY "Users can view verified photos of unblocked users"
ON public.user_photos FOR SELECT
TO authenticated
USING (
    ocr_verified = TRUE 
    AND NOT public.is_mutually_blocked(user_id, public.get_current_user_id())
);

CREATE POLICY "Users can manage their own 5 photo slots"
ON public.user_photos FOR ALL
TO authenticated
USING (user_id = public.get_current_user_id())
WITH CHECK (user_id = public.get_current_user_id());

-- =============================================================================
-- POLICIES: SWIPES
-- =============================================================================
CREATE POLICY "Users can insert their own swipes"
ON public.swipes FOR INSERT
TO authenticated
WITH CHECK (actor_id = public.get_current_user_id());

CREATE POLICY "Users can read their own swipe history"
ON public.swipes FOR SELECT
TO authenticated
USING (actor_id = public.get_current_user_id());

-- =============================================================================
-- POLICIES: MATCHES
-- =============================================================================
CREATE POLICY "Users can view active matches where they are a participant"
ON public.matches FOR SELECT
TO authenticated
USING (
    is_active = TRUE AND (
        user1_id = public.get_current_user_id() OR
        user2_id = public.get_current_user_id()
    )
);

-- =============================================================================
-- POLICIES: MESSAGES (Active Matches Only)
-- =============================================================================
CREATE POLICY "Users can read messages belonging to their active matches"
ON public.messages FOR SELECT
TO authenticated
USING (public.is_match_participant(match_id));

CREATE POLICY "Users can send messages only to their active matches"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = public.get_current_user_id() 
    AND public.is_match_participant(match_id)
);

-- =============================================================================
-- POLICIES: WHATSAPP REVEAL TOKENS
-- =============================================================================
CREATE POLICY "Users can view reveal tokens for their active matches"
ON public.whatsapp_reveal_tokens FOR SELECT
TO authenticated
USING (public.is_match_participant(match_id));

-- =============================================================================
-- POLICIES: AD TRANSACTIONS
-- =============================================================================
CREATE POLICY "Users can view their own ad rewards ledger"
ON public.processed_ad_transactions FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

-- =============================================================================
-- POLICIES: BLOCKED USERS & REPORTS
-- =============================================================================
CREATE POLICY "Users can manage their own blocked list"
ON public.blocked_users FOR ALL
TO authenticated
USING (blocker_id = public.get_current_user_id())
WITH CHECK (blocker_id = public.get_current_user_id());

CREATE POLICY "Users can submit UGC reports"
ON public.user_reports FOR INSERT
TO authenticated
WITH CHECK (reporter_id = public.get_current_user_id());
5. Storage Ceiling Protection: Automated Purge FunctionsTo prevent database bloating beyond 500 MB, the following maintenance procedures run automatically via Supabase Edge Functions or PostgreSQL extensions:SQL-- =============================================================================
-- STORAGE MAINTENANCE & PURGE ROUTINES
-- =============================================================================

CREATE OR REPLACE FUNCTION public.execute_storage_retention_purge()
RETURNS JSONB AS $$ DECLARE     purged_messages_count BIGINT;     purged_pass_swipes_count BIGINT;     purged_audit_logs_count BIGINT; BEGIN     -- 1. Purge chat messages older than 30 days (Preserves storage ceiling)     WITH deleted_rows AS (         DELETE FROM public.messages         WHERE created_at < NOW() - INTERVAL '30 days'         RETURNING id     )     SELECT COUNT(*) INTO purged_messages_count FROM deleted_rows;      -- 2. Purge non-matching pass swipes older than 30 days     WITH deleted_rows AS (         DELETE FROM public.swipes         WHERE swipe_type = 'pass'            AND created_at < NOW() - INTERVAL '30 days'         RETURNING id     )     SELECT COUNT(*) INTO purged_pass_swipes_count FROM deleted_rows;      -- 3. Purge statutory CERT-In audit logs older than 180 days     WITH deleted_rows AS (         DELETE FROM public.legal_audit_logs         WHERE created_at < NOW() - INTERVAL '180 days'         RETURNING id     )     SELECT COUNT(*) INTO purged_audit_logs_count FROM deleted_rows;      -- Return execution summary log     RETURN jsonb_build_object(         'status', 'success',         'timestamp', NOW(),         'purged_messages', purged_messages_count,         'purged_pass_swipes', purged_pass_swipes_count,         'purged_audit_logs', purged_audit_logs_count     ); END; $$ LANGUAGE plpgsql SECURITY DEFINER;
6. Antigravity MCP Execution ChecklistThe Antigravity Autonomous Agent must verify the following database milestones before building client dependencies:[ ] MCP Connection Check: Execute SELECT current_database(), current_user; via Supabase MCP to confirm active write permissions.[ ] DDL Script Execution: Deploy all 10 core tables and verify zero relation collision errors.[ ] Constraint Verification:Verify that attempting to insert a row into public.swipes with identical actor_id and target_id raises a check constraint error (check_cannot_swipe_self).Verify that user1_ads_count and user2_ads_count cannot exceed 3.[ ] RLS Isolation Test:Authenticate as User A and attempt to SELECT messages belonging to a match between User B and User C $\rightarrow$ Confirm zero rows are returned.[ ] Storage Purge Dry-Run:Insert dummy records older than 31 days into public.messages $\rightarrow$ Execute SELECT public.execute_storage_retention_purge(); $\rightarrow$ Confirm records are deleted and JSON status returns status: success.Authorized & Validated for ASI Verticals / UR-Heart Database Engineering Pipeline.