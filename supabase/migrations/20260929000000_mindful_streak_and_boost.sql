-- 20260929000000_mindful_streak_and_boost.sql
-- Adds 24h Mindful Streak, Profile Boost, and Social Handle Reveal Token state to users table.

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS boost_points INT4 NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_streak_ad_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS streak_expires_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS reveal_tokens_count INT2 NOT NULL DEFAULT 1;

-- Index for Discovery Deck feed ordering optimization
CREATE INDEX IF NOT EXISTS idx_users_discovery_boost 
ON public.users (boost_points DESC, streak_count DESC, created_at DESC)
WHERE deleted_at IS NULL AND is_profile_completed = TRUE;
