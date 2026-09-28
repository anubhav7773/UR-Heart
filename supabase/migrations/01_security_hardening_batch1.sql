-- ============================================================================
-- MIGRATION: BATCH 1 SECURITY HARDENING & RLS REMEDIATION
-- Solves: SEC-02 (Privileged Tampering), SEC-03 (Orientation Shield), SEC-07 (PII Scraping)
-- ============================================================================

-- Step 1: Add internal administrative role column if not exists
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user' 
CHECK (role IN ('user', 'moderator', 'superadmin'));

-- Step 2: Assign Superadmin Role strictly to the canonical email in database
UPDATE public.users 
SET role = 'superadmin' 
WHERE auth_id IN (
    SELECT id FROM auth.users WHERE email = 'kshtriyaanubhav9120@gmail.com'
);

-- ============================================================================
-- 1. SEC-02: PL/PGSQL TRIGGER BLOCKING PRIVILEGED COLUMN TAMPERING
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prevent_user_field_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    -- Check if query is executed by authenticated client role (Supabase Anon/Auth Key)
    IF current_user = 'authenticated' OR auth.role() = 'authenticated' THEN
        -- Prevent tampering with KYC Verification Status
        IF NEW.kyc_status IS DISTINCT FROM OLD.kyc_status THEN
            RAISE EXCEPTION 'Security Violation: kyc_status can only be updated via verified backend sentinel.';
        END IF;

        -- Prevent tampering with Subscription & VIP Privileges
        IF NEW.subscription_tier IS DISTINCT FROM OLD.subscription_tier THEN
            RAISE EXCEPTION 'Security Violation: subscription_tier mutation requires verified billing receipt.';
        END IF;

        IF NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
            RAISE EXCEPTION 'Security Violation: subscription_expires_at cannot be altered by client.';
        END IF;

        IF NEW.is_ad_free IS DISTINCT FROM OLD.is_ad_free THEN
            RAISE EXCEPTION 'Security Violation: is_ad_free flag is strictly managed by billing gateway.';
        END IF;

        -- Prevent tampering with Balances & Daily Quotas
        IF NEW.reward_balance IS DISTINCT FROM OLD.reward_balance THEN
            RAISE EXCEPTION 'Security Violation: reward_balance can only be credited via cryptographic SSV ledger.';
        END IF;

        IF NEW.swipes_remaining IS DISTINCT FROM OLD.swipes_remaining AND NEW.swipes_remaining > OLD.swipes_remaining THEN
            RAISE EXCEPTION 'Security Violation: Direct increment of swipes_remaining is forbidden.';
        END IF;

        IF NEW.direct_letters_count IS DISTINCT FROM OLD.direct_letters_count AND NEW.direct_letters_count > OLD.direct_letters_count THEN
            RAISE EXCEPTION 'Security Violation: Direct increment of direct_letters_count is forbidden.';
        END IF;

        -- Prevent tampering with System Roles & DPDP Erasure Timestamp
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Security Violation: Escalation of administrative role is strictly prohibited.';
        END IF;

        IF NEW.deleted_at IS DISTINCT FROM OLD.deleted_at THEN
            RAISE EXCEPTION 'Security Violation: deleted_at can only be triggered via official DPDP incinerator.';
        END IF;

        -- Prevent changing immutable DOB verified at onboarding
        IF NEW.dob IS DISTINCT FROM OLD.dob THEN
            RAISE EXCEPTION 'Security Violation: Date of Birth is permanently locked post-age-gate verification.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_prevent_user_tampering ON public.users;
CREATE TRIGGER tr_prevent_user_tampering
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_user_field_tampering();

-- ============================================================================
-- 2. SEC-07: DIRECT PII LOCKDOWN ON public.users TABLE
-- ============================================================================

-- Drop the overly permissive public select policy
DROP POLICY IF EXISTS "users_select_active" ON public.users;

-- Enforce: Authenticated users can ONLY SELECT their own personal row!
-- Zero PII (GPS, installation UUID, encrypted bridge) can be scraped by peers.
DROP POLICY IF EXISTS "users_select_own_record_only" ON public.users;
CREATE POLICY "users_select_own_record_only" ON public.users
    FOR SELECT TO authenticated
    USING (auth_id = auth.uid());

-- Keep the owner modify policy (now strictly protected by the BEFORE UPDATE trigger)
DROP POLICY IF EXISTS "users_modify_own" ON public.users;
CREATE POLICY "users_modify_own" ON public.users
    FOR UPDATE TO authenticated
    USING (auth_id = auth.uid())
    WITH CHECK (auth_id = auth.uid());

-- Allow users to insert their own profile on registration
DROP POLICY IF EXISTS "users_insert_own" ON public.users;
CREATE POLICY "users_insert_own" ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (auth_id = auth.uid());

-- ============================================================================
-- 3. SEC-03: SECURE DISCOVERY PROJECTION VIEW WITH RECIPROCAL ORIENTATION SHIELD
-- ============================================================================

-- Drop existing view if present
DROP VIEW IF EXISTS public.discovery_profiles;

CREATE OR REPLACE VIEW public.discovery_profiles
WITH (security_invoker = false)
AS
SELECT 
    u.id,
    u.full_name,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, u.dob))::INT2 AS age,
    u.gender,
    u.interested_in,
    u.location_name,
    u.bio,
    u.profession,
    u.education,
    u.kyc_status,
    u.streak_count,
    u.passport_city,
    u.created_at
FROM public.users u
WHERE 
    -- 1. Exclude deleted profiles (DPDP Act Sec 12)
    u.deleted_at IS NULL
    
    -- 2. Exclude Incognito / Ghost Cloak profiles
    AND u.is_incognito = FALSE

    -- 3. Exclude the requesting user themselves
    AND u.id <> public.get_current_user_id()

    -- 4. Exclude blocked perimeter in both directions
    AND NOT public.is_user_blocked(u.id)

    -- 5. Exclude profiles already swiped by the current user
    AND NOT EXISTS (
        SELECT 1 FROM public.swipes s 
        WHERE s.actor_id = public.get_current_user_id() 
          AND s.target_id = u.id
    )

    -- 6. STRICT BI-DIRECTIONAL RECIPROCAL ORIENTATION SHIELD
    -- Target must match user's preference AND User must match target's preference!
    AND (
        (
            -- Case A: Specific Gender Pairing (e.g. Man seeking Woman & Woman seeking Man)
            (u.gender = (SELECT interested_in_singular FROM (
                SELECT CASE 
                    WHEN interested_in = 'Men' THEN 'Man'
                    WHEN interested_in = 'Women' THEN 'Woman'
                    ELSE 'Everyone'
                END AS interested_in_singular FROM public.users WHERE id = public.get_current_user_id()
            ) sub_a))
            AND
            ((SELECT gender FROM public.users WHERE id = public.get_current_user_id()) = 
                CASE 
                    WHEN u.interested_in = 'Men' THEN 'Man'
                    WHEN u.interested_in = 'Women' THEN 'Woman'
                    ELSE 'Everyone'
                END
            )
        )
        OR
        (
            -- Case B: Either user or target is seeking 'Everyone'
            (SELECT interested_in FROM public.users WHERE id = public.get_current_user_id()) = 'Everyone'
            AND (u.interested_in = 'Everyone' OR u.interested_in = CASE 
                WHEN (SELECT gender FROM public.users WHERE id = public.get_current_user_id()) = 'Man' THEN 'Men'
                WHEN (SELECT gender FROM public.users WHERE id = public.get_current_user_id()) = 'Woman' THEN 'Women'
                ELSE 'Everyone'
            END)
        )
    );

-- Grant SELECT access on the sanitized view to authenticated users
GRANT SELECT ON public.discovery_profiles TO authenticated;
