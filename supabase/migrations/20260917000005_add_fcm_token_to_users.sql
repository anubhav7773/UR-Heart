-- ============================================================================
-- MIGRATION: Add fcm_token column for WhatsApp-style push notifications
-- ============================================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255) NULL;
