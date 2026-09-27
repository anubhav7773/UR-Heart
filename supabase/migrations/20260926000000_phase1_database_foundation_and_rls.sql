-- ============================================================================
-- UR-HEART PRODUCTION SCHEMA DEFINITION & RLS ENGINE (PHASE 1)
-- Environment: Supabase PostgreSQL 15/17
-- Compliance: DPDP Act 2023, IT Rules 2021 & Google Play UGC Policies
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. EXTENSIONS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- ----------------------------------------------------------------------------
-- 1. CORE TABLES (MICRO-DATATYPES, CONSTRAINTS & CASCADING KEYS)
-- ----------------------------------------------------------------------------

-- 1.1 USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Profile Essentials
    full_name VARCHAR(60) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(15) NOT NULL CHECK (gender IN ('Woman', 'Man', 'Non-Binary', 'Other')),
    interested_in VARCHAR(15) NOT NULL CHECK (interested_in IN ('Men', 'Women', 'Everyone')),
    whatsapp_encrypted TEXT NOT NULL,
    location_name VARCHAR(100) NOT NULL DEFAULT 'Bandra West, Mumbai',
    latitude NUMERIC(9,6) DEFAULT NULL,
    longitude NUMERIC(9,6) DEFAULT NULL,
    
    -- Mindful Persona Fields
    bio VARCHAR(500) DEFAULT '',
    profession VARCHAR(80) DEFAULT '',
    education VARCHAR(100) DEFAULT '',
    preferred_age_min INT2 NOT NULL DEFAULT 18 CHECK (preferred_age_min >= 18),
    preferred_age_max INT2 NOT NULL DEFAULT 35 CHECK (preferred_age_max <= 100),
    
    -- Gamification & Zero-on-Delete Lifecycle
    streak_count INT2 NOT NULL DEFAULT 0,
    reward_balance INT4 NOT NULL DEFAULT 0,
    swipes_remaining INT2 NOT NULL DEFAULT 25,
    direct_letters_count INT2 NOT NULL DEFAULT 1,
    last_installation_uuid VARCHAR(64) DEFAULT NULL,
    referral_code VARCHAR(16) UNIQUE NOT NULL DEFAULT ('SANCTUARY-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 6))),
    
    -- Privacy & Compliance Flags
    kyc_status BOOLEAN NOT NULL DEFAULT FALSE,
    is_incognito BOOLEAN NOT NULL DEFAULT FALSE,
    discreet_mode BOOLEAN NOT NULL DEFAULT FALSE,
    night_slumber BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Timestamps & Lifecycle
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_feed_filter ON public.users(gender, interested_in, kyc_status) WHERE deleted_at IS NULL;

-- 1.2 SWIPES TABLE
CREATE TABLE IF NOT EXISTS public.swipes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    swipe_type VARCHAR(10) NOT NULL CHECK (swipe_type IN ('like', 'pass', 'superlike')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_actor_target UNIQUE (actor_id, target_id),
    CONSTRAINT check_no_self_swipe CHECK (actor_id <> target_id)
);

CREATE INDEX IF NOT EXISTS idx_swipes_actor_target ON public.swipes(actor_id, target_id);
CREATE INDEX IF NOT EXISTS idx_swipes_target_type ON public.swipes(target_id, swipe_type);
CREATE INDEX IF NOT EXISTS idx_swipes_created_purge ON public.swipes(created_at) WHERE swipe_type = 'pass';

-- 1.3 MATCHES TABLE
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    matched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_match_pair UNIQUE (user1_id, user2_id),
    CONSTRAINT check_different_match_users CHECK (user1_id <> user2_id)
);

CREATE INDEX IF NOT EXISTS idx_matches_user1 ON public.matches(user1_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_matches_user2 ON public.matches(user2_id) WHERE is_active = TRUE;

-- 1.4 MESSAGES TABLE
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

-- 1.5 AD_REWARD_LEDGER TABLE
CREATE TABLE IF NOT EXISTS public.ad_reward_ledger (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ssv_transaction_id VARCHAR(100) UNIQUE NOT NULL,
    network VARCHAR(20) NOT NULL CHECK (network IN ('admob', 'inmobi', 'meta', 'unity', 'applovin')),
    ad_type VARCHAR(20) NOT NULL CHECK (ad_type IN ('quick_reflection', 'deep_resonance', 'whatsapp_reveal', 'morning_harvest_unlock')),
    reward_points INT4 NOT NULL CHECK (reward_points > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ad_reward_user ON public.ad_reward_ledger(user_id);

-- 1.6 PROCESSED_AD_TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.processed_ad_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id VARCHAR(150) UNIQUE NOT NULL,
    network VARCHAR(20) NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ad_type VARCHAR(30) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_processed_ads_tx ON public.processed_ad_transactions(transaction_id);

-- 1.7 WHATSAPP_REVEAL_TOKENS TABLE
CREATE TABLE IF NOT EXISTS public.whatsapp_reveal_tokens (
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

CREATE INDEX IF NOT EXISTS idx_wa_tokens_match ON public.whatsapp_reveal_tokens(match_id);

-- 1.8 BLOCKED_USERS TABLE
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason VARCHAR(50) DEFAULT 'unspecified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_block_pair UNIQUE (blocker_id, blocked_id),
    CONSTRAINT check_no_self_block CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_blocked ON public.blocked_users(blocked_id);

-- 1.9 GRIEVANCE_DOSSIERS TABLE
CREATE TABLE IF NOT EXISTS public.grievance_dossiers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    violation_category VARCHAR(30) NOT NULL CHECK (
        violation_category IN ('harassment', 'explicit_content', 'impersonation', 'underage', 'offplatform_leak')
    ),
    evidence_text VARCHAR(500) DEFAULT '',
    status VARCHAR(15) NOT NULL DEFAULT 'under_review' CHECK (status IN ('under_review', 'actioned', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actioned_at TIMESTAMPTZ DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_grievance_status ON public.grievance_dossiers(status);

-- 1.10 ADMIN_KYC_ESCALATIONS TABLE
CREATE TABLE IF NOT EXISTS public.admin_kyc_escalations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    declared_dob DATE NOT NULL,
    declared_age INT2 NOT NULL,
    groq_match_score INT2 NOT NULL,
    groq_reasoning VARCHAR(255) NOT NULL,
    anchor_photo_url TEXT NOT NULL,
    kyc_video_url TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_at TIMESTAMPTZ DEFAULT NULL,
    reviewed_by VARCHAR(80) DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kyc_escalations_pending ON public.admin_kyc_escalations(status) WHERE status = 'pending';

-- 1.11 UNDERAGE_QUARANTINE_REGISTRY TABLE
CREATE TABLE IF NOT EXISTS public.underage_quarantine_registry (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_hash VARCHAR(64) UNIQUE NOT NULL,
    attempted_dob DATE NOT NULL,
    quarantine_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quarantine_lookup ON public.underage_quarantine_registry(device_hash, quarantine_until);

-- 1.12 DATA_NOMINEES TABLE
CREATE TABLE IF NOT EXISTS public.data_nominees (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    nominee_name VARCHAR(60) NOT NULL,
    nominee_contact VARCHAR(30) NOT NULL,
    relationship VARCHAR(30) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1.13 DATA_EXPORT_REQUESTS TABLE
CREATE TABLE IF NOT EXISTS public.data_export_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(15) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
    export_url TEXT DEFAULT NULL,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_export_user_status ON public.data_export_requests(user_id, status);

-- ----------------------------------------------------------------------------
-- 2. SECURITY DEFINER HELPER FUNCTIONS
-- ----------------------------------------------------------------------------

-- 2.1 Helper: Get internal UUID for current authenticated user
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID AS $$
    SELECT id FROM public.users 
    WHERE auth_id = auth.uid() 
      AND deleted_at IS NULL 
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2.2 Helper: Check if current user is an active participant in match
CREATE OR REPLACE FUNCTION public.is_active_match_participant(target_match_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = target_match_id
          AND is_active = TRUE
          AND (user1_id = public.get_current_user_id() OR user2_id = public.get_current_user_id())
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2.3 Helper: Check if user is blocked or has blocked target user
CREATE OR REPLACE FUNCTION public.is_user_blocked(target_user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE (blocker_id = public.get_current_user_id() AND blocked_id = target_user_id)
           OR (blocker_id = target_user_id AND blocked_id = public.get_current_user_id())
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 3. TRIGGERS & PURGE ROUTINE
-- ----------------------------------------------------------------------------

-- 3.1 Updated At Timestamp Trigger
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_users_updated_at ON public.users;
CREATE TRIGGER tr_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_wa_tokens_updated_at ON public.whatsapp_reveal_tokens;
CREATE TRIGGER tr_wa_tokens_updated_at
BEFORE UPDATE ON public.whatsapp_reveal_tokens
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_data_nominees_updated_at ON public.data_nominees;
CREATE TRIGGER tr_data_nominees_updated_at
BEFORE UPDATE ON public.data_nominees
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 3.2 Automated 30-Day Purge Function
CREATE OR REPLACE FUNCTION public.purge_expired_temporary_records()
RETURNS void AS $$
BEGIN
    -- 1. Hard-delete temporary chat messages older than 30 days
    DELETE FROM public.messages
    WHERE created_at < NOW() - INTERVAL '30 days';

    -- 2. Prune negative 'pass' swipes older than 30 days (Preserves mutual likes)
    DELETE FROM public.swipes
    WHERE swipe_type = 'pass' 
      AND created_at < NOW() - INTERVAL '30 days';

    -- 3. Invalidate and clear expired WhatsApp ephemeral tokens older than 48 hours
    UPDATE public.whatsapp_reveal_tokens
    SET ephemeral_token = NULL,
        is_unlocked = FALSE
    WHERE expires_at IS NOT NULL 
      AND expires_at < NOW() - INTERVAL '48 hours';

    -- 4. Clean up expired data export bundles older than 7 days
    DELETE FROM public.data_export_requests
    WHERE expires_at IS NOT NULL 
      AND expires_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.3 Idempotent pg_cron Schedule (03:00 UTC daily)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-storage-purge-job') THEN
        PERFORM cron.unschedule('daily-storage-purge-job');
    END IF;
END $$;

SELECT cron.schedule(
    'daily-storage-purge-job',
    '0 3 * * *',
    'SELECT public.purge_expired_temporary_records();'
);

-- ----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------

-- Enable RLS across all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_reward_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_ad_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_reveal_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grievance_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_kyc_escalations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.underage_quarantine_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_nominees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;

-- 4.1 USERS POLICIES
DROP POLICY IF EXISTS "users_select_active_profiles" ON public.users;
CREATE POLICY "users_select_active_profiles"
ON public.users FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL 
    AND (
        auth_id = auth.uid()
        OR (
            is_incognito = FALSE 
            AND NOT public.is_user_blocked(id)
        )
    )
);

DROP POLICY IF EXISTS "users_update_own_profile" ON public.users;
CREATE POLICY "users_update_own_profile"
ON public.users FOR UPDATE
TO authenticated
USING (auth_id = auth.uid())
WITH CHECK (auth_id = auth.uid());

DROP POLICY IF EXISTS "users_insert_own_profile" ON public.users;
CREATE POLICY "users_insert_own_profile"
ON public.users FOR INSERT
TO authenticated
WITH CHECK (auth_id = auth.uid());

-- 4.2 SWIPES POLICIES
DROP POLICY IF EXISTS "swipes_insert_own_actions" ON public.swipes;
CREATE POLICY "swipes_insert_own_actions"
ON public.swipes FOR INSERT
TO authenticated
WITH CHECK (
    actor_id = public.get_current_user_id()
    AND actor_id <> target_id
    AND NOT public.is_user_blocked(target_id)
);

DROP POLICY IF EXISTS "swipes_select_own_history" ON public.swipes;
CREATE POLICY "swipes_select_own_history"
ON public.swipes FOR SELECT
TO authenticated
USING (actor_id = public.get_current_user_id());

DROP POLICY IF EXISTS "swipes_delete_own_pass_swipes" ON public.swipes;
CREATE POLICY "swipes_delete_own_pass_swipes"
ON public.swipes FOR DELETE
TO authenticated
USING (
    actor_id = public.get_current_user_id() 
    AND swipe_type = 'pass'
);

-- 4.3 MATCHES POLICIES
DROP POLICY IF EXISTS "matches_select_own_connections" ON public.matches;
CREATE POLICY "matches_select_own_connections"
ON public.matches FOR SELECT
TO authenticated
USING (
    is_active = TRUE 
    AND (
        user1_id = public.get_current_user_id() 
        OR user2_id = public.get_current_user_id()
    )
);

-- 4.4 MESSAGES POLICIES
DROP POLICY IF EXISTS "messages_select_active_dialogue" ON public.messages;
CREATE POLICY "messages_select_active_dialogue"
ON public.messages FOR SELECT
TO authenticated
USING (
    public.is_active_match_participant(match_id)
);

DROP POLICY IF EXISTS "messages_insert_own_dialogue" ON public.messages;
CREATE POLICY "messages_insert_own_dialogue"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = public.get_current_user_id()
    AND public.is_active_match_participant(match_id)
);

DROP POLICY IF EXISTS "messages_update_status_ack" ON public.messages;
CREATE POLICY "messages_update_status_ack"
ON public.messages FOR UPDATE
TO authenticated
USING (
    public.is_active_match_participant(match_id)
)
WITH CHECK (
    public.is_active_match_participant(match_id)
);

-- 4.5 AD_REWARD_LEDGER POLICIES
DROP POLICY IF EXISTS "ad_rewards_select_own_ledger" ON public.ad_reward_ledger;
CREATE POLICY "ad_rewards_select_own_ledger"
ON public.ad_reward_ledger FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

-- 4.6 PROCESSED_AD_TRANSACTIONS POLICIES
DROP POLICY IF EXISTS "processed_ads_select_own_transactions" ON public.processed_ad_transactions;
CREATE POLICY "processed_ads_select_own_transactions"
ON public.processed_ad_transactions FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

-- 4.7 WHATSAPP_REVEAL_TOKENS POLICIES
DROP POLICY IF EXISTS "wa_tokens_select_match_participants" ON public.whatsapp_reveal_tokens;
CREATE POLICY "wa_tokens_select_match_participants"
ON public.whatsapp_reveal_tokens FOR SELECT
TO authenticated
USING (
    public.is_active_match_participant(match_id)
);

DROP POLICY IF EXISTS "wa_tokens_update_match_participants" ON public.whatsapp_reveal_tokens;
CREATE POLICY "wa_tokens_update_match_participants"
ON public.whatsapp_reveal_tokens FOR UPDATE
TO authenticated
USING (
    public.is_active_match_participant(match_id)
)
WITH CHECK (
    public.is_active_match_participant(match_id)
);

-- 4.8 BLOCKED_USERS POLICIES
DROP POLICY IF EXISTS "blocked_users_select_own_list" ON public.blocked_users;
CREATE POLICY "blocked_users_select_own_list"
ON public.blocked_users FOR SELECT
TO authenticated
USING (blocker_id = public.get_current_user_id());

DROP POLICY IF EXISTS "blocked_users_insert_block" ON public.blocked_users;
CREATE POLICY "blocked_users_insert_block"
ON public.blocked_users FOR INSERT
TO authenticated
WITH CHECK (
    blocker_id = public.get_current_user_id()
    AND blocker_id <> blocked_id
);

DROP POLICY IF EXISTS "blocked_users_delete_unblock" ON public.blocked_users;
CREATE POLICY "blocked_users_delete_unblock"
ON public.blocked_users FOR DELETE
TO authenticated
USING (blocker_id = public.get_current_user_id());

-- 4.9 GRIEVANCE_DOSSIERS POLICIES
DROP POLICY IF EXISTS "grievance_insert_dossier" ON public.grievance_dossiers;
CREATE POLICY "grievance_insert_dossier"
ON public.grievance_dossiers FOR INSERT
TO authenticated
WITH CHECK (
    reporter_id = public.get_current_user_id()
    AND reporter_id <> reported_user_id
);

DROP POLICY IF EXISTS "grievance_select_own_dossiers" ON public.grievance_dossiers;
CREATE POLICY "grievance_select_own_dossiers"
ON public.grievance_dossiers FOR SELECT
TO authenticated
USING (reporter_id = public.get_current_user_id());

-- 4.10 ADMIN_KYC_ESCALATIONS POLICIES
DROP POLICY IF EXISTS "admin_kyc_escalations_select_own" ON public.admin_kyc_escalations;
CREATE POLICY "admin_kyc_escalations_select_own"
ON public.admin_kyc_escalations FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

-- 4.11 UNDERAGE_QUARANTINE_REGISTRY POLICIES
-- Zero client access for authenticated role; only accessible via service_role

-- 4.12 DATA_NOMINEES POLICIES
DROP POLICY IF EXISTS "nominees_manage_own_record" ON public.data_nominees;
CREATE POLICY "nominees_manage_own_record"
ON public.data_nominees FOR ALL
TO authenticated
USING (user_id = public.get_current_user_id())
WITH CHECK (user_id = public.get_current_user_id());

-- 4.13 DATA_EXPORT_REQUESTS POLICIES
DROP POLICY IF EXISTS "export_select_own_requests" ON public.data_export_requests;
CREATE POLICY "export_select_own_requests"
ON public.data_export_requests FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

DROP POLICY IF EXISTS "export_insert_request" ON public.data_export_requests;
CREATE POLICY "export_insert_request"
ON public.data_export_requests FOR INSERT
TO authenticated
WITH CHECK (user_id = public.get_current_user_id());
