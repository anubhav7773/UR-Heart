-- =============================================================================
-- UR-HEART: SUPABASE STORAGE BUCKETS & ISOLATION POLICIES
-- =============================================================================

-- 1. Create 'user-photos' Bucket (Publicly readable for verified media, authenticated write)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-photos',
    'user-photos',
    true,
    153600, -- 150 KB maximum hard ceiling per image
    ARRAY['image/webp', 'image/jpeg']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Create 'kyc-temp' Bucket (Strictly Private: No public access, 48h ephemeral retention)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'kyc-temp',
    'kyc-temp',
    false,
    2621440, -- 2.5 MB maximum ceiling for 5s KYC clip
    ARRAY['video/mp4']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 3. Storage Row Level Security: user-photos
DROP POLICY IF EXISTS "Users can upload their own profile photos" ON storage.objects;
CREATE POLICY "Users can upload their own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'user-photos' 
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

DROP POLICY IF EXISTS "Public read verified profile photos" ON storage.objects;
CREATE POLICY "Public read verified profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'user-photos');

DROP POLICY IF EXISTS "Users can delete their own profile photos" ON storage.objects;
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'user-photos' 
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- 4. Storage Row Level Security: kyc-temp
DROP POLICY IF EXISTS "Users can upload their own KYC selfie video" ON storage.objects;
CREATE POLICY "Users can upload their own KYC selfie video"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'kyc-temp' 
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

DROP POLICY IF EXISTS "Super admin and backend service read kyc-temp" ON storage.objects;
CREATE POLICY "Super admin and backend service read kyc-temp"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'kyc-temp' 
    AND (
        auth.jwt() ->> 'email' = 'kshtriyaanubhav9120@gmail.com'
        OR (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
    )
);

DROP POLICY IF EXISTS "Super admin and backend service delete kyc-temp" ON storage.objects;
CREATE POLICY "Super admin and backend service delete kyc-temp"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'kyc-temp' 
    AND (
        auth.jwt() ->> 'email' = 'kshtriyaanubhav9120@gmail.com'
        OR (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
    )
);
