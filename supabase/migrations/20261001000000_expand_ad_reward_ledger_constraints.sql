-- 20261001000000_expand_ad_reward_ledger_constraints.sql
-- Expands ad_reward_ledger check constraints to accept whatsapp_reveal, sacred_bridge_reveal, daily_streak_boost, and admob_client.

ALTER TABLE public.ad_reward_ledger DROP CONSTRAINT IF EXISTS ad_reward_ledger_ad_type_check;
ALTER TABLE public.ad_reward_ledger ADD CONSTRAINT ad_reward_ledger_ad_type_check
CHECK (ad_type IN ('quick_reflection', 'deep_resonance', 'sacred_bridge_reveal', 'whatsapp_reveal', 'morning_harvest_unlock', 'daily_streak_boost'));

ALTER TABLE public.ad_reward_ledger DROP CONSTRAINT IF EXISTS ad_reward_ledger_network_check;
ALTER TABLE public.ad_reward_ledger ADD CONSTRAINT ad_reward_ledger_network_check
CHECK (network IN ('admob', 'admob_client', 'inmobi', 'meta', 'unity', 'applovin'));
