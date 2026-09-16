-- Migration: 002_rls_and_retention_purge
-- Created: 2026-09-16
-- Description: Security Helper Functions, Row Level Security (RLS) on all 14 tables, Granular Access Policies, and Storage Retention Purge Routine

-- =============================================================================
-- UR-HEART: ROW LEVEL SECURITY (RLS), HELPER FUNCTIONS & RETENTION PURGE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: SECURITY HELPER FUNCTIONS
-- -----------------------------------------------------------------------------

-- Helper 1: Extract Internal User UUID using Firebase UID claim from JWT
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID AS $$
    SELECT id FROM public.users 
    WHERE firebase_uid = auth.jwt() ->> 'sub' 
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper 2: Verify if two users have an active mutual block
CREATE OR REPLACE FUNCTION public.is_mutually_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE (blocker_id = user_a AND blocked_id = user_b)
           OR (blocker_id = user_b AND blocked_id = user_a)
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper 3: Verify if current user is an active participant in a match
CREATE OR REPLACE FUNCTION public.is_match_participant(match_uuid UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = match_uuid
          AND is_active = TRUE
          AND (user1_id = public.get_current_user_id() OR user2_id = public.get_current_user_id())
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- STEP 2: ENABLE RLS ON ALL OPERATIONAL & AUDIT TABLES
-- -----------------------------------------------------------------------------
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
ALTER TABLE public.kyc_review_queue ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- STEP 3: CONFIGURE GRANULAR ROW LEVEL SECURITY POLICIES
-- -----------------------------------------------------------------------------

-- 1. USERS TABLE POLICIES
DROP POLICY IF EXISTS "Users can view active, unblocked profiles in discovery" ON public.users;
CREATE POLICY "Users can view active, unblocked profiles in discovery"
ON public.users FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL 
    AND is_banned = FALSE 
    AND NOT public.is_mutually_blocked(id, public.get_current_user_id())
);

DROP POLICY IF EXISTS "Users can update their own profile fields" ON public.users;
CREATE POLICY "Users can update their own profile fields"
ON public.users FOR UPDATE
TO authenticated
USING (id = public.get_current_user_id())
WITH CHECK (id = public.get_current_user_id());

-- 2. USER PHOTOS TABLE POLICIES
DROP POLICY IF EXISTS "Users can view verified photos of unblocked users" ON public.user_photos;
CREATE POLICY "Users can view verified photos of unblocked users"
ON public.user_photos FOR SELECT
TO authenticated
USING (
    ocr_verified = TRUE 
    AND NOT public.is_mutually_blocked(user_id, public.get_current_user_id())
);

DROP POLICY IF EXISTS "Users can manage their own 5 photo slots" ON public.user_photos;
CREATE POLICY "Users can manage their own 5 photo slots"
ON public.user_photos FOR ALL
TO authenticated
USING (user_id = public.get_current_user_id())
WITH CHECK (user_id = public.get_current_user_id());

-- 3. SWIPES TABLE POLICIES
DROP POLICY IF EXISTS "Users can insert their own swipes" ON public.swipes;
CREATE POLICY "Users can insert their own swipes"
ON public.swipes FOR INSERT
TO authenticated
WITH CHECK (actor_id = public.get_current_user_id());

DROP POLICY IF EXISTS "Users can read their own swipe history" ON public.swipes;
CREATE POLICY "Users can read their own swipe history"
ON public.swipes FOR SELECT
TO authenticated
USING (actor_id = public.get_current_user_id());

-- 4. MATCHES TABLE POLICIES
DROP POLICY IF EXISTS "Users can view active matches where they are a participant" ON public.matches;
CREATE POLICY "Users can view active matches where they are a participant"
ON public.matches FOR SELECT
TO authenticated
USING (
    is_active = TRUE AND (
        user1_id = public.get_current_user_id() OR
        user2_id = public.get_current_user_id()
    )
);

-- 5. MESSAGES TABLE POLICIES (Active Matches Only)
DROP POLICY IF EXISTS "Users can read messages belonging to their active matches" ON public.messages;
CREATE POLICY "Users can read messages belonging to their active matches"
ON public.messages FOR SELECT
TO authenticated
USING (public.is_match_participant(match_id));

DROP POLICY IF EXISTS "Users can send messages only to their active matches" ON public.messages;
CREATE POLICY "Users can send messages only to their active matches"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = public.get_current_user_id() 
    AND public.is_match_participant(match_id)
);

-- 6. WHATSAPP REVEAL TOKENS POLICIES
DROP POLICY IF EXISTS "Users can view reveal tokens for their active matches" ON public.whatsapp_reveal_tokens;
CREATE POLICY "Users can view reveal tokens for their active matches"
ON public.whatsapp_reveal_tokens FOR SELECT
TO authenticated
USING (public.is_match_participant(match_id));

-- 7. AD TRANSACTIONS POLICIES
DROP POLICY IF EXISTS "Users can view their own ad rewards ledger" ON public.processed_ad_transactions;
CREATE POLICY "Users can view their own ad rewards ledger"
ON public.processed_ad_transactions FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

-- 8. BLOCKED USERS & REPORTS POLICIES
DROP POLICY IF EXISTS "Users can manage their own blocked list" ON public.blocked_users;
CREATE POLICY "Users can manage their own blocked list"
ON public.blocked_users FOR ALL
TO authenticated
USING (blocker_id = public.get_current_user_id())
WITH CHECK (blocker_id = public.get_current_user_id());

DROP POLICY IF EXISTS "Users can submit UGC reports" ON public.user_reports;
CREATE POLICY "Users can submit UGC reports"
ON public.user_reports FOR INSERT
TO authenticated
WITH CHECK (reporter_id = public.get_current_user_id());

-- 9. KYC REVIEW QUEUE POLICIES (Super Admin Exclusivity)
DROP POLICY IF EXISTS "Super admin has full access to KYC review queue" ON public.kyc_review_queue;
CREATE POLICY "Super admin has full access to KYC review queue"
ON public.kyc_review_queue FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = public.get_current_user_id() 
          AND (users.is_super_admin = TRUE OR auth.jwt() ->> 'email' = 'kshtriyaanubhav9120@gmail.com')
    )
);

-- 10. CONSENT & GRIEVANCE AUDIT POLICIES
DROP POLICY IF EXISTS "Users can view their own consent history" ON public.consent_records;
CREATE POLICY "Users can view their own consent history"
ON public.consent_records FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

DROP POLICY IF EXISTS "Users can view their submitted grievance tickets" ON public.grievance_tickets;
CREATE POLICY "Users can view their submitted grievance tickets"
ON public.grievance_tickets FOR SELECT
TO authenticated
USING (complainant_user_id = public.get_current_user_id());

-- -----------------------------------------------------------------------------
-- STEP 4: AUTOMATED RETENTION & STORAGE CEILING PURGE FUNCTION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.execute_storage_retention_purge()
RETURNS JSONB AS $$
DECLARE
    purged_messages_count BIGINT;
    purged_pass_swipes_count BIGINT;
    purged_audit_logs_count BIGINT;
BEGIN
    -- 1. Purge chat messages older than 30 days (Preserves 500MB DB ceiling)
    WITH deleted_messages AS (
        DELETE FROM public.messages
        WHERE created_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_messages_count FROM deleted_messages;

    -- 2. Purge non-matching pass swipes older than 30 days
    WITH deleted_swipes AS (
        DELETE FROM public.swipes
        WHERE swipe_type = 'pass'
           AND created_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_pass_swipes_count FROM deleted_swipes;

    -- 3. Purge CERT-In statutory access logs older than 180 days
    WITH deleted_audit AS (
        DELETE FROM public.legal_audit_logs
        WHERE created_at < NOW() - INTERVAL '180 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_audit_logs_count FROM deleted_audit;

    RETURN jsonb_build_object(
        'status', 'success',
        'timestamp', NOW(),
        'purged_messages', purged_messages_count,
        'purged_pass_swipes', purged_pass_swipes_count,
        'purged_audit_logs', purged_audit_logs_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
