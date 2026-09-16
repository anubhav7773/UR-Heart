-- Migration: 001_core_relational_schema
-- Created: 2026-09-16
-- Description: Core relational schema, extensions, enum types, indexes, and constraints for UR-Heart

-- Enable Cryptographic Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Custom Enum Types
DO $$ BEGIN     CREATE TYPE kyc_review_state AS ENUM ('pending_ai', 'verified', 'pending_manual_review', 'rejected'); EXCEPTION     WHEN duplicate_object THEN null; END $$;

-- 1. USERS CORE TABLE (With Firebase Auth & KYC Extensions)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    whatsapp_number VARCHAR(15) NOT NULL,
    full_name VARCHAR(50) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(10) NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    city VARCHAR(50) NOT NULL,
    bio VARCHAR(250) DEFAULT '',
    streak_count INT2 NOT NULL DEFAULT 0 CHECK (streak_count >= 0),
    reward_balance INT4 NOT NULL DEFAULT 0 CHECK (reward_balance >= 0),
    kyc_status BOOLEAN NOT NULL DEFAULT FALSE,
    kyc_state kyc_review_state NOT NULL DEFAULT 'pending_ai',
    kyc_ai_confidence NUMERIC(3, 2) DEFAULT NULL,
    kyc_transcript TEXT DEFAULT NULL,
    kyc_failure_reason TEXT DEFAULT NULL,
    kyc_verified_at TIMESTAMPTZ DEFAULT NULL,
    kyc_document_sha256 VARCHAR(64) DEFAULT NULL,
    last_installation_uuid VARCHAR(64) DEFAULT NULL,
    is_super_admin BOOLEAN NOT NULL DEFAULT FALSE,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON public.users(firebase_uid) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_feed_discovery ON public.users(city, gender) WHERE deleted_at IS NULL AND is_banned = FALSE;

-- 2. USER PHOTOS TABLE (Slots 1 to 5)
CREATE TABLE IF NOT EXISTS public.user_photos (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    slot_index INT2 NOT NULL CHECK (slot_index BETWEEN 1 AND 5),
    photo_storage_path TEXT NOT NULL,
    blur_hash VARCHAR(64) NOT NULL,
    ocr_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_photo_slot UNIQUE (user_id, slot_index)
);

CREATE INDEX IF NOT EXISTS idx_user_photos_user ON public.user_photos(user_id);

-- 3. SWIPES TABLE
CREATE TABLE IF NOT EXISTS public.swipes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    swipe_type VARCHAR(10) NOT NULL CHECK (swipe_type IN ('like', 'pass', 'direct_dm')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_actor_target_swipe UNIQUE (actor_id, target_id),
    CONSTRAINT check_cannot_swipe_self CHECK (actor_id <> target_id)
);

CREATE INDEX IF NOT EXISTS idx_swipes_actor_target ON public.swipes(actor_id, target_id);
CREATE INDEX IF NOT EXISTS idx_swipes_pass_cleanup ON public.swipes(created_at) WHERE swipe_type = 'pass';

-- 4. MATCHES TABLE
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_match_pair UNIQUE (user1_id, user2_id),
    CONSTRAINT check_distinct_match_users CHECK (user1_id <> user2_id)
);

CREATE INDEX IF NOT EXISTS idx_matches_user1 ON public.matches(user1_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_matches_user2 ON public.matches(user2_id) WHERE is_active = TRUE;

-- 5. MESSAGES TABLE (Encrypted Payloads)
CREATE TABLE IF NOT EXISTS public.messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    encrypted_text TEXT NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_match_chronological ON public.messages(match_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_purge ON public.messages(created_at);

-- 6. WHATSAPP REVEAL TOKENS TABLE (Dual 3-Ad Progression)
CREATE TABLE IF NOT EXISTS public.whatsapp_reveal_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID UNIQUE NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    user1_consent BOOLEAN NOT NULL DEFAULT FALSE,
    user2_consent BOOLEAN NOT NULL DEFAULT FALSE,
    user1_ads_count INT2 NOT NULL DEFAULT 0 CHECK (user1_ads_count BETWEEN 0 AND 3),
    user2_ads_count INT2 NOT NULL DEFAULT 0 CHECK (user2_ads_count BETWEEN 0 AND 3),
    is_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
    ephemeral_token VARCHAR(64) DEFAULT NULL,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wa_tokens_match ON public.whatsapp_reveal_tokens(match_id);

-- 7. PROCESSED AD TRANSACTIONS (Replay-Proof Ledger)
CREATE TABLE IF NOT EXISTS public.processed_ad_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id TEXT UNIQUE NOT NULL,
    network VARCHAR(20) NOT NULL CHECK (network IN ('admob', 'inmobi', 'meta', 'applovin', 'unity')),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ad_type VARCHAR(30) NOT NULL CHECK (ad_type IN ('feed_interstitial', 'direct_dm_reward', 'whatsapp_reveal')),
    reward_amount INT4 NOT NULL DEFAULT 1,
    raw_custom_data TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ad_tx_user ON public.processed_ad_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_ad_tx_created ON public.processed_ad_transactions(created_at);

-- 8. UGC: BLOCKED USERS & REPORTS
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_block_relation UNIQUE (blocker_id, blocked_id),
    CONSTRAINT check_cannot_block_self CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON public.blocked_users(blocked_id);

CREATE TABLE IF NOT EXISTS public.user_reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL CHECK (
        reason IN ('harassment_bullying', 'ncii_nudity', 'fake_impersonation', 'underage_user', 'commercial_spam', 'other')
    ),
    details VARCHAR(500) DEFAULT '',
    context_match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL,
    is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
    action_taken VARCHAR(50) DEFAULT 'none' CHECK (
        action_taken IN ('none', 'warning_issued', 'profile_quarantined', 'permanent_ban', 'false_report')
    ),
    reviewed_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_reported_id ON public.user_reports(reported_id);
CREATE INDEX IF NOT EXISTS idx_reports_unreviewed ON public.user_reports(is_reviewed) WHERE is_reviewed = FALSE;

-- 9. UNDERAGE QUARANTINE REGISTRY (18+ Device Lock)
CREATE TABLE IF NOT EXISTS public.underage_quarantine (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_phone_hash VARCHAR(64) UNIQUE NOT NULL,
    quarantined_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    attempt_count INT2 NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quarantine_hash ON public.underage_quarantine(device_phone_hash);

-- 10. STATUTORY LEGAL & AUDIT TABLES
CREATE TABLE IF NOT EXISTS public.legal_audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL,
    ip_address INET NOT NULL,
    client_port INT4 DEFAULT NULL,
    user_agent TEXT NOT NULL,
    installation_uuid VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.legal_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_ip ON public.legal_audit_logs(ip_address);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.legal_audit_logs(created_at);

CREATE TABLE IF NOT EXISTS public.consent_records (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    consent_purpose VARCHAR(50) NOT NULL,
    consent_given BOOLEAN NOT NULL DEFAULT TRUE,
    consent_notice_version VARCHAR(20) NOT NULL,
    ip_address INET NOT NULL,
    user_agent TEXT NOT NULL,
    withdrawn_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_consent_user ON public.consent_records(user_id);

CREATE TABLE IF NOT EXISTS public.grievance_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number VARCHAR(32) UNIQUE NOT NULL,
    complainant_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    complainant_email VARCHAR(255) NOT NULL,
    complainant_phone VARCHAR(20) DEFAULT NULL,
    reported_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    category VARCHAR(50) NOT NULL CHECK (
        category IN ('ncii_nudity', 'impersonation', 'harassment', 'underage', 'fraud_scam', 'other')
    ),
    incident_description TEXT NOT NULL,
    evidence_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_urgent_24h_sla BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'received' CHECK (
        status IN ('received', 'acknowledged', 'under_investigation', 'resolved', 'rejected')
    ),
    resolution_notes TEXT DEFAULT NULL,
    acknowledged_at TIMESTAMPTZ DEFAULT NULL,
    resolved_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_grievance_status ON public.grievance_tickets(status);
CREATE INDEX IF NOT EXISTS idx_grievance_24h_sla ON public.grievance_tickets(is_urgent_24h_sla) WHERE status != 'resolved';

-- 11. KYC MANUAL REVIEW QUEUE TABLE (Admin Review Hub)
CREATE TABLE IF NOT EXISTS public.kyc_review_queue (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    video_storage_path TEXT NOT NULL,
    registered_name VARCHAR(50) NOT NULL,
    registered_city VARCHAR(50) NOT NULL,
    extracted_transcript TEXT DEFAULT '',
    ai_confidence_score NUMERIC(3, 2) DEFAULT 0.00,
    ai_flags TEXT[] DEFAULT ARRAY[]::TEXT[],
    status VARCHAR(20) NOT NULL DEFAULT 'unreviewed' CHECK (status IN ('unreviewed', 'approved', 'rejected')),
    reviewed_by VARCHAR(100) DEFAULT NULL,
    rejection_reason TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_kyc_queue_status ON public.kyc_review_queue(status) WHERE status = 'unreviewed';
