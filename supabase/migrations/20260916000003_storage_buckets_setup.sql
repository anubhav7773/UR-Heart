-- Migration: 003_storage_buckets_setup
-- Created: 2026-09-16
-- Description: Storage buckets setup and RLS access control for user-photos and kyc-temp

-- 1. Insert Storage Buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('user-photos', 'user-photos', TRUE, 150000, ARRAY['image/webp']),
    ('kyc-temp', 'kyc-temp', FALSE, 2500000, ARRAY['video/mp4'])
ON CONFLICT (id) DO NOTHING;

-- 2. Storage Policies for user-photos (Public Read, Owner Upload)
DO $$ BEGIN
    CREATE POLICY "Public profiles can view photos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'user-photos');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Authenticated users can upload own photo slots"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'user-photos' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update and replace own photo slots"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'user-photos' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can delete own photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'user-photos' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3. Storage Policies for kyc-temp (Strictly Private - Service Role only)
DO $$ BEGIN
    CREATE POLICY "Users can upload their KYC video"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'kyc-temp' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Deny public access to KYC videos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id != 'kyc-temp');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
