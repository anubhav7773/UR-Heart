-- Migration: 20260919000001_message_delivery_read_ticks.sql
-- Goal ROOT-07: 3-Stage WhatsApp Ticks (Sent, Delivered, Read)

ALTER TABLE public.direct_messages
ADD COLUMN IF NOT EXISTS is_delivered BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Index for instant lookup of unread messages per match
CREATE INDEX IF NOT EXISTS idx_direct_messages_unread_status 
ON public.direct_messages(match_id, recipient_id, is_read);
