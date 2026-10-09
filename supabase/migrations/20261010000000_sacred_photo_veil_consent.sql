-- 20261010000000_sacred_photo_veil_consent.sql
-- Sacred Photo Veil: Bilateral mutual consent photo shield to protect against analog physical phone camera piracy.

-- 1. Add is_photo_veiled toggle to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_photo_veiled BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Create bilateral photo reveal consent ledger
CREATE TABLE IF NOT EXISTS public.photo_reveal_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_photo_reveal_pair UNIQUE (requester_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_photo_reveal_target ON public.photo_reveal_consents(target_id, status);
CREATE INDEX IF NOT EXISTS idx_photo_reveal_requester ON public.photo_reveal_consents(requester_id, target_id);
