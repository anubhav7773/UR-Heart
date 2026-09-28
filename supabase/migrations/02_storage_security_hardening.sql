-- ============================================================================
-- STORAGE HARDENING MIGRATION: SEC-10 REMEDIATION
-- Target: storage.objects
-- Scope: Public read for moments, strictly isolated authenticated owner-only write.
-- ============================================================================

-- 1. Ensure 'sanctuary-media' bucket exists with private write restrictions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'sanctuary-media', 
    'sanctuary-media', 
    TRUE,                     -- Public read allowed for card hydration
    102400,                   -- Hard limit: 100 KB per photo (100 * 1024 bytes)
    ARRAY['image/webp']       -- Strictly WebP format only
)
ON CONFLICT (id) DO UPDATE SET
    public = TRUE,
    file_size_limit = 102400,
    allowed_mime_types = ARRAY['image/webp'];

-- Also harden existing 'ur-heart-media' bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'ur-heart-media', 
    'ur-heart-media', 
    TRUE,
    102400,
    ARRAY['image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = TRUE,
    file_size_limit = 102400,
    allowed_mime_types = ARRAY['image/webp'];

-- 2. Drop any legacy insecure storage policies
DROP POLICY IF EXISTS "Public Upload Moments" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow user slot update" ON storage.objects;
DROP POLICY IF EXISTS "ur_heart_media_delete" ON storage.objects;
DROP POLICY IF EXISTS "ur_heart_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "ur_heart_media_public_select" ON storage.objects;
DROP POLICY IF EXISTS "ur_heart_media_update" ON storage.objects;
DROP POLICY IF EXISTS "Public Read Approved Moments" ON storage.objects;
DROP POLICY IF EXISTS "Strict Owner Moments Upload" ON storage.objects;
DROP POLICY IF EXISTS "Strict Owner Moments Update" ON storage.objects;
DROP POLICY IF EXISTS "Strict Owner Moments Delete" ON storage.objects;

-- 3. Policy: Public Read for Profile Moments
CREATE POLICY "Public Read Approved Moments" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id IN ('sanctuary-media', 'ur-heart-media') AND (storage.foldername(name))[1] = 'users');

-- 4. Policy: STRICT OWNER-ONLY UPLOAD (SEC-10 FIX)
-- Checks:
-- a) User must be authenticated.
-- b) Path must strictly match: users/{auth.uid()}/moments/slot_[1-5].webp
-- c) Cross-user directory overwrites are physically impossible.
CREATE POLICY "Strict Owner Moments Upload" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id IN ('sanctuary-media', 'ur-heart-media')
        AND (storage.foldername(name))[1] = 'users'
        AND (storage.foldername(name))[2] = (auth.uid())::TEXT
        AND (storage.foldername(name))[3] = 'moments'
        AND (storage.filename(name)) ~ '^slot_[1-5]\.webp$'
    );

-- 5. Policy: STRICT OWNER-ONLY UPDATE (In-place slot overwrite)
CREATE POLICY "Strict Owner Moments Update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id IN ('sanctuary-media', 'ur-heart-media')
        AND (storage.foldername(name))[1] = 'users'
        AND (storage.foldername(name))[2] = (auth.uid())::TEXT
        AND (storage.foldername(name))[3] = 'moments'
    )
    WITH CHECK (
        bucket_id IN ('sanctuary-media', 'ur-heart-media')
        AND (storage.foldername(name))[1] = 'users'
        AND (storage.foldername(name))[2] = (auth.uid())::TEXT
        AND (storage.foldername(name))[3] = 'moments'
    );

-- 6. Policy: STRICT OWNER-ONLY DELETE (For DPDP Sec 12 Erasure)
CREATE POLICY "Strict Owner Moments Delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id IN ('sanctuary-media', 'ur-heart-media')
        AND (storage.foldername(name))[1] = 'users'
        AND (storage.foldername(name))[2] = (auth.uid())::TEXT
    );
