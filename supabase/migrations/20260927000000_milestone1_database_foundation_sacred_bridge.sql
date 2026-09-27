-- ================================================================================
-- MILESTONE 1: SUPABASE DATABASE FOUNDATION, SACRED BRIDGE & RLS ENGINE
-- Target Documents: .docs/02_DATABASE_SCHEMA_OPTIMIZATION.md & .docs/03_SUPABASE_RLS_SECURITY_POLICIES.md
-- ================================================================================

-- ================================================================================
-- 1. EXTENSIONS & SECURITY DEFINER HELPERS
-- ================================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Helper: Get internal user UUID from auth.uid()
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

-- Helper: Verify active match participation
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

-- Helper: Check blocked perimeter
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

-- ================================================================================
-- 2. MASTER RELATIONAL TABLES (14 TABLES)
-- ================================================================================

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(60) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(15) NOT NULL CHECK (gender IN ('Woman', 'Man', 'Non-Binary', 'Other')),
    interested_in VARCHAR(15) NOT NULL CHECK (interested_in IN ('Men', 'Women', 'Everyone')),
    contact_bridge_type VARCHAR(20) NOT NULL DEFAULT 'whatsapp' 
        CHECK (contact_bridge_type IN ('whatsapp', 'instagram', 'snapchat', 'telegram', 'signal')),
    contact_bridge_encrypted TEXT NOT NULL,
    location_name VARCHAR(100) NOT NULL DEFAULT 'Saket, Ayodhya',
    latitude NUMERIC(9,6) DEFAULT NULL,
    longitude NUMERIC(9,6) DEFAULT NULL,
    bio VARCHAR(500) DEFAULT '',
    profession VARCHAR(80) DEFAULT '',
    education VARCHAR(100) DEFAULT '',
    preferred_age_min INT2 NOT NULL DEFAULT 18 CHECK (preferred_age_min >= 18),
    preferred_age_max INT2 NOT NULL DEFAULT 35 CHECK (preferred_age_max <= 100),
    streak_count INT2 NOT NULL DEFAULT 0,
    reward_balance INT4 NOT NULL DEFAULT 0,
    swipes_remaining INT2 NOT NULL DEFAULT 25,
    direct_letters_count INT2 NOT NULL DEFAULT 1,
    last_installation_uuid VARCHAR(64) DEFAULT NULL,
    referral_code VARCHAR(16) UNIQUE NOT NULL DEFAULT ('SANCTUARY-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 6))),
    kyc_status BOOLEAN NOT NULL DEFAULT FALSE,
    is_incognito BOOLEAN NOT NULL DEFAULT FALSE,
    discreet_mode BOOLEAN NOT NULL DEFAULT FALSE,
    night_slumber BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_tier VARCHAR(20) NOT NULL DEFAULT 'free' 
        CHECK (subscription_tier IN ('free', 'weekly', 'monthly', 'quarterly', 'lifetime')),
    subscription_expires_at TIMESTAMPTZ DEFAULT NULL,
    is_ad_free BOOLEAN NOT NULL DEFAULT FALSE,
    passport_city VARCHAR(100) DEFAULT NULL,
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_feed_filter ON public.users(gender, interested_in, kyc_status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_sub_tier ON public.users(subscription_tier) WHERE subscription_tier <> 'free';
CREATE INDEX IF NOT EXISTS idx_users_incognito ON public.users(is_incognito) WHERE is_incognito = TRUE;

-- 2. SWIPES TABLE
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

-- 3. MATCHES TABLE
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

-- 4. MESSAGES TABLE (30-Day Storage Controlled)
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

-- 5. AD REWARD LEDGER
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

-- 6. PROCESSED AD TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.processed_ad_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id VARCHAR(150) UNIQUE NOT NULL,
    network VARCHAR(20) NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ad_type VARCHAR(30) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_processed_ads_tx ON public.processed_ad_transactions(transaction_id);

-- 7. IN-APP PURCHASES & WEB STORE AUDIT
CREATE TABLE IF NOT EXISTS public.in_app_purchases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    transaction_reference VARCHAR(150) UNIQUE NOT NULL,
    product_identifier VARCHAR(60) NOT NULL,
    store VARCHAR(30) NOT NULL DEFAULT 'google_play' 
        CHECK (store IN ('google_play', 'web_razorpay_india', 'web_stripe_global')),
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    amount_gross NUMERIC(10,2) NOT NULL,
    platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    amount_net NUMERIC(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed' 
        CHECK (status IN ('pending', 'completed', 'refunded')),
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_iap_user ON public.in_app_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_iap_store ON public.in_app_purchases(store);

-- 8. SACRED CONTACT REVEAL TOKENS
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

-- 9. BLOCKED USERS PERIMETER
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

-- 10. GRIEVANCE DOSSIERS (IT Rules 2021)
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

-- 11. ADMIN KYC ESCALATIONS
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

-- 12. UNDERAGE QUARANTINE REGISTRY
CREATE TABLE IF NOT EXISTS public.underage_quarantine_registry (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_hash VARCHAR(64) UNIQUE NOT NULL,
    attempted_dob DATE NOT NULL,
    quarantine_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quarantine_lookup ON public.underage_quarantine_registry(device_hash, quarantine_until);

-- 13. DATA NOMINEES (DPDP Act 2023 Sec 14)
CREATE TABLE IF NOT EXISTS public.data_nominees (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    nominee_name VARCHAR(60) NOT NULL,
    nominee_contact VARCHAR(30) NOT NULL,
    relationship VARCHAR(30) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. DATA EXPORT REQUESTS (DPDP Act 2023 Sec 11)
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

-- ================================================================================
-- 3. TIMESTAMPS & 30-DAY PURGE CRON ENGINE
-- ================================================================================

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

CREATE OR REPLACE FUNCTION public.purge_expired_temporary_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.messages WHERE created_at < NOW() - INTERVAL '30 days';
    DELETE FROM public.swipes WHERE swipe_type = 'pass' AND created_at < NOW() - INTERVAL '30 days';
    UPDATE public.contact_reveal_tokens
    SET ephemeral_token = NULL, is_unlocked = FALSE
    WHERE expires_at IS NOT NULL AND expires_at < NOW() - INTERVAL '48 hours';
    DELETE FROM public.data_export_requests WHERE expires_at IS NOT NULL AND expires_at < NOW() - INTERVAL '7 days';
    UPDATE public.users
    SET subscription_tier = 'free', is_ad_free = FALSE, swipes_remaining = 25
    WHERE subscription_expires_at IS NOT NULL 
      AND subscription_expires_at < NOW() 
      AND subscription_tier <> 'free' 
      AND subscription_tier <> 'lifetime';
END;
$$;

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

-- ================================================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ================================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_reward_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_ad_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.in_app_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_reveal_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grievance_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_kyc_escalations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.underage_quarantine_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_nominees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;

-- users
DROP POLICY IF EXISTS "users_select_active" ON public.users;
CREATE POLICY "users_select_active" ON public.users
    FOR SELECT TO authenticated
    USING (deleted_at IS NULL AND (is_incognito = FALSE OR id = public.get_current_user_id()));

DROP POLICY IF EXISTS "users_modify_own" ON public.users;
CREATE POLICY "users_modify_own" ON public.users
    FOR ALL TO authenticated
    USING (auth_id = auth.uid())
    WITH CHECK (auth_id = auth.uid());

-- swipes
DROP POLICY IF EXISTS "swipes_actor_access" ON public.swipes;
CREATE POLICY "swipes_actor_access" ON public.swipes
    FOR ALL TO authenticated
    USING (actor_id = public.get_current_user_id())
    WITH CHECK (actor_id = public.get_current_user_id() AND NOT public.is_user_blocked(target_id));

-- matches
DROP POLICY IF EXISTS "matches_participant_access" ON public.matches;
CREATE POLICY "matches_participant_access" ON public.matches
    FOR SELECT TO authenticated
    USING (user1_id = public.get_current_user_id() OR user2_id = public.get_current_user_id());

-- messages
DROP POLICY IF EXISTS "messages_participant_select" ON public.messages;
CREATE POLICY "messages_participant_select" ON public.messages
    FOR SELECT TO authenticated
    USING (public.is_active_match_participant(match_id));

DROP POLICY IF EXISTS "messages_sender_insert" ON public.messages;
CREATE POLICY "messages_sender_insert" ON public.messages
    FOR INSERT TO authenticated
    WITH CHECK (sender_id = public.get_current_user_id() AND public.is_active_match_participant(match_id));

DROP POLICY IF EXISTS "messages_status_update" ON public.messages;
CREATE POLICY "messages_status_update" ON public.messages
    FOR UPDATE TO authenticated
    USING (public.is_active_match_participant(match_id))
    WITH CHECK (public.is_active_match_participant(match_id));

-- service ledgers & tokens
DROP POLICY IF EXISTS "ad_reward_own_read" ON public.ad_reward_ledger;
CREATE POLICY "ad_reward_own_read" ON public.ad_reward_ledger
    FOR SELECT TO authenticated
    USING (user_id = public.get_current_user_id());

DROP POLICY IF EXISTS "iap_own_read" ON public.in_app_purchases;
CREATE POLICY "iap_own_read" ON public.in_app_purchases
    FOR SELECT TO authenticated
    USING (user_id = public.get_current_user_id());

DROP POLICY IF EXISTS "reveal_tokens_participant_access" ON public.contact_reveal_tokens;
CREATE POLICY "reveal_tokens_participant_access" ON public.contact_reveal_tokens
    FOR ALL TO authenticated
    USING (public.is_active_match_participant(match_id))
    WITH CHECK (public.is_active_match_participant(match_id));

-- perimeter & legal compliance
DROP POLICY IF EXISTS "blocked_users_own" ON public.blocked_users;
CREATE POLICY "blocked_users_own" ON public.blocked_users
    FOR ALL TO authenticated
    USING (blocker_id = public.get_current_user_id())
    WITH CHECK (blocker_id = public.get_current_user_id());

DROP POLICY IF EXISTS "grievance_reporter_access" ON public.grievance_dossiers;
CREATE POLICY "grievance_reporter_access" ON public.grievance_dossiers
    FOR ALL TO authenticated
    USING (reporter_id = public.get_current_user_id())
    WITH CHECK (reporter_id = public.get_current_user_id());

DROP POLICY IF EXISTS "data_nominees_own" ON public.data_nominees;
CREATE POLICY "data_nominees_own" ON public.data_nominees
    FOR ALL TO authenticated
    USING (user_id = public.get_current_user_id())
    WITH CHECK (user_id = public.get_current_user_id());

DROP POLICY IF EXISTS "data_export_own" ON public.data_export_requests;
CREATE POLICY "data_export_own" ON public.data_export_requests
    FOR ALL TO authenticated
    USING (user_id = public.get_current_user_id())
    WITH CHECK (user_id = public.get_current_user_id());
