-- ============================================================================
-- DATABASE SCHEMA: Project RuralHeart
-- Description: PostgreSQL + PostGIS Schema for High-Intent Local Dating,
--              "Chai Date" Quick Meetups, Safe WhatsApp Bridge, and Sachet Micro-Payments.
-- Target DB: Supabase / PostgreSQL 15+
-- ============================================================================

-- 1. EXTENSIONS SETUP
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. ENUM TYPES
CREATE TYPE gender_enum AS ENUM ('male', 'female', 'other');
CREATE TYPE relationship_intent_enum AS ENUM ('serious', 'casual', 'friendship', 'chai_date');
CREATE TYPE chai_status_enum AS ENUM ('free_for_chai', 'quick_snacks', 'study_partner', 'none');
CREATE TYPE invite_status_enum AS ENUM ('pending', 'accepted', 'declined', 'expired');
CREATE TYPE payment_status_enum AS ENUM ('created', 'captured', 'failed', 'refunded');
CREATE TYPE sachet_plan_enum AS ENUM ('chai_invite_9', 'profile_boost_19', 'day_photo_pass_19', 'monthly_premium_99');

-- 3. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(20) UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    bio VARCHAR(250),
    dob DATE NOT NULL,
    gender gender_enum NOT NULL,
    interested_in gender_enum NOT NULL,
    intent relationship_intent_enum DEFAULT 'serious',
    
    -- "Chai Date" Real-time Intent Status
    chai_status chai_status_enum DEFAULT 'none',
    chai_status_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Location & Privacy Masking
    area_name VARCHAR(100) NOT NULL,
    village_pin_code VARCHAR(10) NOT NULL,
    raw_location GEOGRAPHY(POINT, 4326) NOT NULL,
    
    -- Subscriptions & Ad Engines State
    is_premium BOOLEAN DEFAULT FALSE,
    premium_expires_at TIMESTAMP WITH TIME ZONE,
    photo_pass_expires_at TIMESTAMP WITH TIME ZONE,
    persistent_skip_count INT DEFAULT 0,
    
    -- Safety & Verification
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Spatial Index for Fast Local Radius Searches (2 km - 10 km)
CREATE INDEX IF NOT EXISTS idx_users_raw_location ON users USING GIST (raw_location);
CREATE INDEX IF NOT EXISTS idx_users_gender_interested ON users (gender, interested_in, is_active);

-- 4. USER PHOTOS TABLE
CREATE TABLE IF NOT EXISTS user_photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    is_first_impression BOOLEAN DEFAULT FALSE,
    display_order INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_photos_user ON user_photos(user_id);

-- 5. SWIPES & DISCOVERY ENGINE TABLE
CREATE TABLE IF NOT EXISTS user_swipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    swiper_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(10) NOT NULL CHECK (action IN ('like', 'reject', 'dm', 'chai_invite')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(swiper_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_swipes_swiper ON user_swipes(swiper_id);
CREATE INDEX IF NOT EXISTS idx_swipes_target ON user_swipes(target_id);

-- 6. MATCHES & SAFE WHATSAPP BRIDGE TABLE
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_1 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_2 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Safe WhatsApp Bridge Counter (Unlocks contact exchange at 15 messages)
    mutual_message_count INT DEFAULT 0,
    is_whatsapp_unlocked BOOLEAN DEFAULT FALSE,
    whatsapp_unlocked_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_1, user_2)
);

CREATE INDEX IF NOT EXISTS idx_matches_users ON matches(user_1, user_2);

-- 7. "CHAI DATE" DIRECT INVITES TABLE (₹9 Sachet Feature)
CREATE TABLE IF NOT EXISTS chai_invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proposed_location VARCHAR(150),
    status invite_status_enum DEFAULT 'pending',
    sachet_payment_id VARCHAR(100), -- Connected to ₹9 Razorpay Transaction
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chai_invites_receiver ON chai_invites(receiver_id, status);

-- 8. REAL-TIME CHAT MESSAGES TABLE
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT,
    media_url TEXT,
    is_view_once BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_messages_match ON messages(match_id, created_at DESC);

-- Trigger Function: Auto-Increment mutual message count for WhatsApp Bridge Trigger
CREATE OR REPLACE FUNCTION increment_match_message_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE matches
    SET mutual_message_count = mutual_message_count + 1
    WHERE id = NEW.match_id;

    -- Auto-unlock WhatsApp Bridge when mutual messages >= 15
    UPDATE matches
    SET is_whatsapp_unlocked = TRUE,
        whatsapp_unlocked_at = CURRENT_TIMESTAMP
    WHERE id = NEW.match_id AND mutual_message_count >= 15 AND is_whatsapp_unlocked = FALSE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_increment_message_count
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION increment_match_message_count();

-- 9. SACHET MONETIZATION & PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS sachet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    razorpay_order_id VARCHAR(100) NOT NULL UNIQUE,
    razorpay_payment_id VARCHAR(100),
    amount_inr DECIMAL(10, 2) NOT NULL,
    plan_type sachet_plan_enum NOT NULL,
    status payment_status_enum DEFAULT 'created',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_transactions_user ON sachet_transactions(user_id);

-- 10. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_photos ENABLE ROW LEVEL SECURITY;

-- Allow users to read active profiles for discovery feed
CREATE POLICY "Public profiles discovery policy" ON users 
    FOR SELECT USING (is_active = TRUE);

-- Users can only read and insert messages belonging to their matches
CREATE POLICY "Chat message security policy" ON messages
    FOR ALL USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );