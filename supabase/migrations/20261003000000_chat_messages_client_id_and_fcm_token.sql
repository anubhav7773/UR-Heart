-- Migration: Add client_id to messages and expand fcm_token length on users
-- Date: 2026-10-03
-- Purpose: Fix chat persistence deduplication and robust FCM background notification delivery

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS client_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_messages_client_id ON public.messages(client_id);

ALTER TABLE public.users ALTER COLUMN fcm_token TYPE VARCHAR(512);
