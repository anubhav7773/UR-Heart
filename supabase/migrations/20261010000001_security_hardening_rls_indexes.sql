-- Migration: 20261010000001_security_hardening_rls_indexes.sql
-- Description: Security Hardening Wave 1 - Enforce Row Level Security (RLS) across 7 un-RLS tables,
-- restrict anonymous inserts into underage quarantine registry, and add performance/uniqueness indexes.
-- Remediates: VULN-DB-01, VULN-DB-02, VULN-DB-03.

-- ============================================================================
-- 1. Table: device_fcm_tokens (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.device_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_fcm_tokens_owner_select" ON public.device_fcm_tokens;
CREATE POLICY "device_fcm_tokens_owner_select" ON public.device_fcm_tokens
    FOR SELECT TO authenticated
    USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

DROP POLICY IF EXISTS "device_fcm_tokens_owner_insert" ON public.device_fcm_tokens;
CREATE POLICY "device_fcm_tokens_owner_insert" ON public.device_fcm_tokens
    FOR INSERT TO authenticated
    WITH CHECK (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

DROP POLICY IF EXISTS "device_fcm_tokens_owner_delete" ON public.device_fcm_tokens;
CREATE POLICY "device_fcm_tokens_owner_delete" ON public.device_fcm_tokens
    FOR DELETE TO authenticated
    USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- ============================================================================
-- 2. Table: photo_reveal_consents (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.photo_reveal_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "photo_reveal_consents_participant_select" ON public.photo_reveal_consents;
CREATE POLICY "photo_reveal_consents_participant_select" ON public.photo_reveal_consents
    FOR SELECT TO authenticated
    USING (
        requester_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()) OR
        target_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
    );

DROP POLICY IF EXISTS "photo_reveal_consents_requester_insert" ON public.photo_reveal_consents;
CREATE POLICY "photo_reveal_consents_requester_insert" ON public.photo_reveal_consents
    FOR INSERT TO authenticated
    WITH CHECK (requester_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

DROP POLICY IF EXISTS "photo_reveal_consents_target_update" ON public.photo_reveal_consents;
CREATE POLICY "photo_reveal_consents_target_update" ON public.photo_reveal_consents
    FOR UPDATE TO authenticated
    USING (target_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()))
    WITH CHECK (target_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- ============================================================================
-- 3. Table: blind_date_sessions (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.blind_date_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blind_date_sessions_participant_access" ON public.blind_date_sessions;
CREATE POLICY "blind_date_sessions_participant_access" ON public.blind_date_sessions
    FOR SELECT TO authenticated
    USING (
        user1_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()) OR
        user2_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
    );

-- ============================================================================
-- 4. Table: blind_date_messages (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.blind_date_messages ADD COLUMN IF NOT EXISTS recipient_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.blind_date_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blind_date_messages_participant_access" ON public.blind_date_messages;
CREATE POLICY "blind_date_messages_participant_access" ON public.blind_date_messages
    FOR ALL TO authenticated
    USING (
        sender_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()) OR
        recipient_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.blind_date_sessions s
            WHERE s.id = session_id AND (
                s.user1_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()) OR
                s.user2_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
            )
        )
    );

-- ============================================================================
-- 5. Table: blind_date_queue (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.blind_date_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blind_date_queue_owner_access" ON public.blind_date_queue;
CREATE POLICY "blind_date_queue_owner_access" ON public.blind_date_queue
    FOR ALL TO authenticated
    USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()))
    WITH CHECK (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- ============================================================================
-- 6. Table: admin_audit_logs (Superadmin Only) (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_audit_logs_superadmin_only" ON public.admin_audit_logs;
CREATE POLICY "admin_audit_logs_superadmin_only" ON public.admin_audit_logs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE auth_id = auth.uid() AND role = 'superadmin'
        )
    );

-- ============================================================================
-- 7. Table: pending_web_entitlements (Owner & Superadmin Access) (VULN-DB-01)
-- ============================================================================
ALTER TABLE public.pending_web_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pending_web_entitlements_owner_select" ON public.pending_web_entitlements;
CREATE POLICY "pending_web_entitlements_owner_select" ON public.pending_web_entitlements
    FOR SELECT TO authenticated
    USING (
        email = (SELECT email FROM public.users WHERE auth_id = auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE auth_id = auth.uid() AND role = 'superadmin'
        )
    );

-- ============================================================================
-- 8. Restrict Public Anonymous Inserts into Underage Quarantine Registry (VULN-DB-02)
-- ============================================================================
ALTER TABLE public.underage_quarantine_registry ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quarantine_public_insert" ON public.underage_quarantine_registry;
DROP POLICY IF EXISTS "quarantine_public_check" ON public.underage_quarantine_registry;
DROP POLICY IF EXISTS "quarantine_authenticated_check" ON public.underage_quarantine_registry;

-- Restrict all insertions and selections exclusively to backend service role (bypasses RLS)
-- Direct client access to device hashes is prohibited to prevent device fingerprint harvesting.
-- Verification is performed solely via backend service API (/api/v1/auth/quarantine-device).

-- ============================================================================
-- 9. Performance & Uniqueness Indexes on High-Frequency Queries (VULN-DB-03)
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_device_fcm_tokens_last_seen ON public.device_fcm_tokens(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_photo_reveal_consents_reverse ON public.photo_reveal_consents(target_id, requester_id);
