-- 20261002000000_update_ad_networks_chartboost_liftoff.sql
-- Aligns ad networks strictly to the 5 supported networks: AdMob, Meta, UnityAds, Chartboost, Liftoff.
-- Removes InMobi and AppLovin.

ALTER TABLE public.ad_reward_ledger DROP CONSTRAINT IF EXISTS ad_reward_ledger_network_check;
ALTER TABLE public.ad_reward_ledger ADD CONSTRAINT ad_reward_ledger_network_check
CHECK (network IN ('admob', 'admob_client', 'meta', 'unity', 'chartboost', 'liftoff'));
