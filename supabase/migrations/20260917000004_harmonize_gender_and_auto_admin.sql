-- =============================================================================
-- UR-HEART: HARMONIZE GENDER CONSTRAINTS & AUTO-ADMIN SEED (GOAL FIX-01)
-- Parent Entity: ASI Verticals
-- =============================================================================

-- 1. Drop existing gender constraint and recreate with universal coverage
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_gender_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_gender_check 
CHECK (gender IN ('male', 'female', 'lgbtq+', 'other'));

-- 2. Ensure default value for gender is valid
ALTER TABLE public.users 
ALTER COLUMN gender SET DEFAULT 'other';

-- 3. Designate Master Admin permanently for kshtriyaanubhav9120@gmail.com
-- This triggers both on existing rows and grants super admin flag
UPDATE public.users 
SET is_super_admin = TRUE 
WHERE firebase_uid IN (
    SELECT id::text FROM auth.users WHERE email = 'kshtriyaanubhav9120@gmail.com'
);

-- 4. Create trigger to auto-grant super_admin if user signs up with master email
CREATE OR REPLACE FUNCTION public.auto_assign_super_admin()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.firebase_uid IN (
        SELECT id::text FROM auth.users WHERE email = 'kshtriyaanubhav9120@gmail.com'
    ) THEN
        NEW.is_super_admin := TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_assign_super_admin ON public.users;
CREATE TRIGGER trg_assign_super_admin
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.auto_assign_super_admin();
