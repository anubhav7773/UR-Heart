-- TARGET FILE: supabase/migrations/20261010010000_web_deletion_tokens.sql
-- Description: Persistent storage for DPDP Act 2023 Section 12 web account deletion tokens

CREATE TABLE IF NOT EXISTS public.web_deletion_tokens (
    token VARCHAR(64) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    auth_id UUID NULL,
    reason TEXT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique index required for ON CONFLICT (email) clause
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_deletion_tokens_email ON public.web_deletion_tokens(email);
CREATE INDEX IF NOT EXISTS idx_web_deletion_tokens_expires ON public.web_deletion_tokens(expires_at);

-- Restrict direct PostgREST access via RLS
ALTER TABLE public.web_deletion_tokens ENABLE ROW LEVEL SECURITY;
