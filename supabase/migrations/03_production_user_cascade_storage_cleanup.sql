-- =========================================================================
-- UR-HEART: PRODUCTION-GRADE USER CASCADE & STORAGE CLEANUP TRIGGER
-- Enforces complete, atomic destruction across database, storage, and auth.
-- =========================================================================

-- 1. Create or replace the master cascade cleanup function on public.users
CREATE OR REPLACE FUNCTION public.handle_user_cascade_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage, pg_catalog
AS $$
DECLARE
    v_safe_name text;
    v_photo_url text;
    v_photo_path text;
    v_folder_prefix text;
    v_clean_email text;
BEGIN
    -- Enable direct SQL deletion on storage.objects for this transaction
    PERFORM set_config('storage.allow_delete_query', 'true', true);

    -- Build sanitized safe display name if available
    IF OLD.full_name IS NOT NULL AND trim(OLD.full_name) != '' THEN
        v_safe_name := regexp_replace(trim(OLD.full_name), '[^a-zA-Z0-9_-]', '_', 'g');
    END IF;

    -- A. Delete storage objects matching user ID, auth ID, or owner in storage buckets
    DELETE FROM storage.objects
    WHERE bucket_id IN ('ur-heart-media', 'sanctuary-media')
      AND (
          name LIKE 'users/' || OLD.id::text || '/%'
          OR name LIKE '%/' || OLD.id::text || '/%'
          OR name LIKE '%_' || OLD.id::text || '/%'
          OR (OLD.auth_id IS NOT NULL AND (
              name LIKE 'users/' || OLD.auth_id::text || '/%'
              OR name LIKE '%/' || OLD.auth_id::text || '/%'
              OR name LIKE '%_' || OLD.auth_id::text || '/%'
          ))
          OR (owner IS NOT NULL AND OLD.auth_id IS NOT NULL AND owner = OLD.auth_id)
      );

    -- B. Delete KYC ephemeral, avatars, and audio bio files for this user
    DELETE FROM storage.objects
    WHERE bucket_id IN ('ur-heart-media', 'sanctuary-media')
      AND (
          (name LIKE 'kyc_ephemeral/%' AND (
              name LIKE '%' || OLD.id::text || '%'
              OR (OLD.auth_id IS NOT NULL AND name LIKE '%' || OLD.auth_id::text || '%')
          ))
          OR (name LIKE 'audio_bio/%' AND (
              name LIKE '%' || OLD.id::text || '%'
              OR (OLD.auth_id IS NOT NULL AND name LIKE '%' || OLD.auth_id::text || '%')
          ))
          OR (name LIKE 'avatars/%' AND (
              name LIKE '%' || OLD.id::text || '%'
              OR (OLD.auth_id IS NOT NULL AND name LIKE '%' || OLD.auth_id::text || '%')
          ))
      );

    -- C. Delete storage objects matching folder paths extracted from OLD.photos array
    IF OLD.photos IS NOT NULL AND array_length(OLD.photos, 1) > 0 THEN
        FOREACH v_photo_url IN ARRAY OLD.photos LOOP
            IF v_photo_url IS NOT NULL AND trim(v_photo_url) != '' THEN
                -- Extract relative path from public CDN URL
                IF v_photo_url LIKE '%/ur-heart-media/%' THEN
                    v_photo_path := split_part(v_photo_url, '/ur-heart-media/', 2);
                    v_photo_path := split_part(v_photo_path, '?', 1);
                    DELETE FROM storage.objects WHERE bucket_id = 'ur-heart-media' AND name = v_photo_path;
                    
                    -- Also delete the parent folder (e.g. users/Anushka_Singh_.../)
                    v_folder_prefix := split_part(v_photo_path, '/moments/', 1);
                    IF v_folder_prefix IS NOT NULL AND v_folder_prefix != '' AND v_folder_prefix != 'users' THEN
                        DELETE FROM storage.objects WHERE bucket_id = 'ur-heart-media' AND name LIKE v_folder_prefix || '/%';
                    END IF;
                ELSIF v_photo_url LIKE '%/sanctuary-media/%' THEN
                    v_photo_path := split_part(v_photo_url, '/sanctuary-media/', 2);
                    v_photo_path := split_part(v_photo_path, '?', 1);
                    DELETE FROM storage.objects WHERE bucket_id = 'sanctuary-media' AND name = v_photo_path;
                    
                    v_folder_prefix := split_part(v_photo_path, '/moments/', 1);
                    IF v_folder_prefix IS NOT NULL AND v_folder_prefix != '' AND v_folder_prefix != 'users' THEN
                        DELETE FROM storage.objects WHERE bucket_id = 'sanctuary-media' AND name LIKE v_folder_prefix || '/%';
                    END IF;
                ELSE
                    DELETE FROM storage.objects WHERE name = v_photo_url;
                END IF;
            END IF;
        END LOOP;
    END IF;

    -- D. Delete storage object for OLD.avatar_url
    IF OLD.avatar_url IS NOT NULL AND trim(OLD.avatar_url) != '' THEN
        IF OLD.avatar_url LIKE '%/ur-heart-media/%' THEN
            v_photo_path := split_part(OLD.avatar_url, '/ur-heart-media/', 2);
            v_photo_path := split_part(v_photo_path, '?', 1);
            DELETE FROM storage.objects WHERE bucket_id = 'ur-heart-media' AND name = v_photo_path;
        ELSIF OLD.avatar_url LIKE '%/sanctuary-media/%' THEN
            v_photo_path := split_part(OLD.avatar_url, '/sanctuary-media/', 2);
            v_photo_path := split_part(v_photo_path, '?', 1);
            DELETE FROM storage.objects WHERE bucket_id = 'sanctuary-media' AND name = v_photo_path;
        ELSE
            DELETE FROM storage.objects WHERE name = OLD.avatar_url;
        END IF;
    END IF;

    -- E. Purge auth.users record if exists (protects against orphaned logins)
    -- Guarded by pg_trigger_depth() <= 1 to prevent recursive trigger invocation
    IF pg_trigger_depth() <= 1 THEN
        IF OLD.auth_id IS NOT NULL THEN
            DELETE FROM auth.users WHERE id = OLD.auth_id;
        END IF;
        IF OLD.email IS NOT NULL AND trim(OLD.email) != '' THEN
            v_clean_email := lower(trim(OLD.email));
            DELETE FROM auth.users WHERE lower(email) = v_clean_email;
        END IF;
    END IF;

    RETURN OLD;
END;
$$;

-- 2. Bind BEFORE DELETE trigger to public.users
DROP TRIGGER IF EXISTS trg_user_cascade_cleanup ON public.users;
CREATE TRIGGER trg_user_cascade_cleanup
BEFORE DELETE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_user_cascade_cleanup();

-- 3. Bi-directional sync: Deleting a user from Supabase Auth Dashboard cascades to public.users
CREATE OR REPLACE FUNCTION public.handle_auth_user_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage, pg_catalog
AS $$
BEGIN
    IF pg_trigger_depth() <= 1 THEN
        DELETE FROM public.users 
        WHERE auth_id = OLD.id 
           OR (email IS NOT NULL AND lower(email) = lower(OLD.email));
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_auth_user_deleted ON auth.users;
CREATE TRIGGER trg_auth_user_deleted
AFTER DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_auth_user_delete();

-- 4. Clean up any existing orphaned storage objects (excluding .emptyFolderPlaceholder)
DO $$
BEGIN
    PERFORM set_config('storage.allow_delete_query', 'true', true);
    DELETE FROM storage.objects
    WHERE bucket_id IN ('ur-heart-media', 'sanctuary-media')
      AND name NOT LIKE '%.emptyFolderPlaceholder'
      AND name NOT IN (
          SELECT unnest(photos) FROM public.users WHERE photos IS NOT NULL
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.users u 
          WHERE storage.objects.name LIKE '%' || u.id::text || '%'
             OR (u.auth_id IS NOT NULL AND storage.objects.name LIKE '%' || u.auth_id::text || '%')
      );
END $$;
