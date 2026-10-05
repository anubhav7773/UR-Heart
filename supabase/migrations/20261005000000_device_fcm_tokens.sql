-- Store one active FCM registration per installation instead of one token per user.
CREATE TABLE IF NOT EXISTS public.device_fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token VARCHAR(512) NOT NULL,
  platform VARCHAR(20) NOT NULL DEFAULT 'unknown',
  installation_id VARCHAR(128),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_device_fcm_tokens_user_token UNIQUE (user_id, token),
  CONSTRAINT uq_device_fcm_tokens_token UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_device_fcm_tokens_user_active
  ON public.device_fcm_tokens(user_id, active);
