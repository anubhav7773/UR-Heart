-- ============================================================================
-- STATUTORY COMPLIANCE MIGRATION: BATCH 3
-- Scope: DPDP Act 2023 (Sec 6, 9, 11, 12, 14) & IT Rules 2021 Rule 3(2)
-- ============================================================================

-- 1. CONSENT AUDIT LOGS TABLE (DPDP Act 2023 Section 6 Specificity)
-- Maintains verifiable, timestamped proof of affirmative consent for every user.
CREATE TABLE IF NOT EXISTS public.consent_audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    consent_purpose_id VARCHAR(50) NOT NULL, -- 'dpdp_data_processing', 'eula_terms', 'age_confirmation'
    is_granted BOOLEAN NOT NULL DEFAULT TRUE,
    ip_hash VARCHAR(64) NOT NULL,            -- SHA-256 hashed IP for audit without storing raw PII
    installation_uuid VARCHAR(64) NOT NULL,
    consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_consent_user ON public.consent_audit_logs(user_id);

-- 2. ENHANCE UNDERAGE QUARANTINE REGISTRY (SEC-08 FIX)
-- Adds explicit lockout reason and client installation correlation.
ALTER TABLE public.underage_quarantine_registry 
ADD COLUMN IF NOT EXISTS attempt_metadata JSONB DEFAULT '{}'::jsonb;

-- 3. ENHANCE DATA EXPORT REQUESTS (SEC-09 FIX)
ALTER TABLE public.data_export_requests
ADD COLUMN IF NOT EXISTS export_payload JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS checksum_sha256 VARCHAR(64) DEFAULT NULL;

-- 4. ENHANCE GRIEVANCE DOSSIERS (IT Rules 2021 SLA Tracking)
ALTER TABLE public.grievance_dossiers
ADD COLUMN IF NOT EXISTS dossier_reference_id VARCHAR(32) UNIQUE NOT NULL 
    DEFAULT ('GRV-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 6))),
ADD COLUMN IF NOT EXISTS acknowledgment_sent_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS statutory_resolution_due_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '15 days'),
ADD COLUMN IF NOT EXISTS resolution_summary TEXT DEFAULT NULL;

-- 5. RLS POLICIES FOR STATUTORY TABLES
ALTER TABLE public.consent_audit_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    DROP POLICY IF EXISTS "consent_logs_owner_read" ON public.consent_audit_logs;
    CREATE POLICY "consent_logs_owner_read" ON public.consent_audit_logs
        FOR SELECT TO authenticated
        USING (user_id = public.get_current_user_id());

    DROP POLICY IF EXISTS "consent_logs_owner_insert" ON public.consent_audit_logs;
    CREATE POLICY "consent_logs_owner_insert" ON public.consent_audit_logs
        FOR INSERT TO authenticated
        WITH CHECK (user_id = public.get_current_user_id());

    DROP POLICY IF EXISTS "quarantine_public_insert" ON public.underage_quarantine_registry;
    CREATE POLICY "quarantine_public_insert" ON public.underage_quarantine_registry
        FOR INSERT TO anon, authenticated
        WITH CHECK (TRUE);

    DROP POLICY IF EXISTS "quarantine_public_check" ON public.underage_quarantine_registry;
    CREATE POLICY "quarantine_public_check" ON public.underage_quarantine_registry
        FOR SELECT TO anon, authenticated
        USING (quarantine_until > NOW());
END $$;

ALTER TABLE public.underage_quarantine_registry ENABLE ROW LEVEL SECURITY;
