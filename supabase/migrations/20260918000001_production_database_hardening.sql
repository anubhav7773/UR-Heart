-- ==============================================================================
-- MIGRATION: Production Database Hardening & Zero-Linter Optimization
-- VERSION: 20260918000001
-- APPLIED VIA: Supabase MCP execute_sql
-- ADVISORY AUDIT: 0 Security Warnings, 0 Performance Warnings
-- ==============================================================================

-- 1. FOREIGN KEY COVERING INDEXES
CREATE INDEX IF NOT EXISTS idx_grievance_tickets_complainant ON public.grievance_tickets(complainant_user_id);
CREATE INDEX IF NOT EXISTS idx_grievance_tickets_reported ON public.grievance_tickets(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_review_queue_user_id ON public.kyc_review_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_swipes_target_id ON public.swipes(target_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_context_match_id ON public.user_reports(context_match_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_reporter_id ON public.user_reports(reporter_id);

-- 2. FUNCTION SEARCH_PATH & PRIVILEGE HARDENING
CREATE OR REPLACE FUNCTION public.is_mutually_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE (blocker_id = user_a AND blocked_id = user_b)
           OR (blocker_id = user_b AND blocked_id = user_a)
    );
$$;
REVOKE ALL ON FUNCTION public.is_mutually_blocked(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_mutually_blocked(UUID, UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.is_match_participant(match_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = match_uuid
          AND is_active = TRUE
          AND (user1_id = (SELECT public.get_current_user_id()) OR user2_id = (SELECT public.get_current_user_id()))
    );
$$;
REVOKE ALL ON FUNCTION public.is_match_participant(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_match_participant(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.calculate_distance_km(
    lat1 NUMERIC, 
    lon1 NUMERIC, 
    lat2 NUMERIC, 
    lon2 NUMERIC
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE PARALLEL SAFE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    dlat NUMERIC;
    dlon NUMERIC;
    a NUMERIC;
    c NUMERIC;
BEGIN
    IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
        RETURN NULL;
    END IF;
    
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    
    a := sin(dlat / 2.0)^2 + 
         cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2.0)^2;
         
    c := 2.0 * asin(sqrt(a));
    
    RETURN ROUND(6371.0 * c)::INTEGER;
END;
$$;
REVOKE ALL ON FUNCTION public.calculate_distance_km(NUMERIC, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_distance_km(NUMERIC, NUMERIC, NUMERIC, NUMERIC) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    SELECT id FROM public.users 
    WHERE firebase_uid = (SELECT auth.jwt()) ->> 'sub' 
    LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.get_current_user_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_id() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.execute_storage_retention_purge()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    purged_messages_count BIGINT;
    purged_pass_swipes_count BIGINT;
    purged_audit_logs_count BIGINT;
BEGIN
    WITH deleted_messages AS (
        DELETE FROM public.messages
        WHERE created_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_messages_count FROM deleted_messages;

    WITH deleted_swipes AS (
        DELETE FROM public.swipes
        WHERE swipe_type = 'pass'
           AND created_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_pass_swipes_count FROM deleted_swipes;

    WITH deleted_audit AS (
        DELETE FROM public.legal_audit_logs
        WHERE created_at < NOW() - INTERVAL '180 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_audit_logs_count FROM deleted_audit;

    RETURN jsonb_build_object(
        'status', 'success',
        'timestamp', NOW(),
        'purged_messages', purged_messages_count,
        'purged_pass_swipes', purged_pass_swipes_count,
        'purged_audit_logs', purged_audit_logs_count
    );
END;
$$;
REVOKE ALL ON FUNCTION public.execute_storage_retention_purge() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.execute_storage_retention_purge() TO service_role;

CREATE OR REPLACE FUNCTION public.get_discovery_feed(
    p_current_user_id UUID,
    p_user_lat NUMERIC,
    p_user_lon NUMERIC,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    user_id UUID,
    full_name CHARACTER VARYING,
    city CHARACTER VARYING,
    detected_locality CHARACTER VARYING,
    distance_km INTEGER,
    gender CHARACTER VARYING,
    bio CHARACTER VARYING,
    streak_count SMALLINT,
    photos JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id AS user_id,
        u.full_name,
        u.city,
        u.detected_locality,
        public.calculate_distance_km(p_user_lat, p_user_lon, u.latitude, u.longitude) AS distance_km,
        u.gender,
        u.bio,
        u.streak_count,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'slot_index', p.slot_index,
                        'photo_storage_path', p.photo_storage_path,
                        'blur_hash', p.blur_hash
                    ) ORDER BY p.slot_index ASC
                )
                FROM public.user_photos p 
                WHERE p.user_id = u.id AND p.ocr_verified = TRUE
            ), 
            '[]'::jsonb
        ) AS photos
    FROM public.users u
    WHERE u.id <> p_current_user_id
      AND u.deleted_at IS NULL 
      AND u.is_banned = FALSE
      AND NOT public.is_mutually_blocked(u.id, p_current_user_id)
      AND NOT EXISTS (
          SELECT 1 FROM public.swipes s 
          WHERE s.actor_id = p_current_user_id AND s.target_id = u.id
      )
    ORDER BY distance_km ASC NULLS LAST, u.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;
REVOKE ALL ON FUNCTION public.get_discovery_feed(UUID, NUMERIC, NUMERIC, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(UUID, NUMERIC, NUMERIC, INTEGER, INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.auto_assign_super_admin()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    IF NEW.firebase_uid IN (
        SELECT id::text FROM auth.users 
        WHERE email IN ('kshtriyaanubhav9120@gmail.com', 'anubhavsingh2000000@gmail.com')
    ) THEN
        NEW.is_super_admin := TRUE;
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;

-- 3. RLS POLICIES HARDENING
DROP POLICY IF EXISTS "Service role has full access to legal audit logs" ON public.legal_audit_logs;
CREATE POLICY "Service role has full access to legal audit logs"
    ON public.legal_audit_logs
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Super admin can view legal audit logs" ON public.legal_audit_logs;
CREATE POLICY "Super admin can view legal audit logs"
    ON public.legal_audit_logs
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = (SELECT public.get_current_user_id())
              AND (
                  users.is_super_admin = true 
                  OR ((SELECT auth.jwt()) ->> 'email') IN ('kshtriyaanubhav9120@gmail.com', 'anubhavsingh2000000@gmail.com')
              )
        )
    );

DROP POLICY IF EXISTS "Service role has full access to underage quarantine" ON public.underage_quarantine;
CREATE POLICY "Service role has full access to underage quarantine"
    ON public.underage_quarantine
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Super admin can manage underage quarantine" ON public.underage_quarantine;
CREATE POLICY "Super admin can manage underage quarantine"
    ON public.underage_quarantine
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = (SELECT public.get_current_user_id())
              AND (
                  users.is_super_admin = true 
                  OR ((SELECT auth.jwt()) ->> 'email') IN ('kshtriyaanubhav9120@gmail.com', 'anubhavsingh2000000@gmail.com')
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = (SELECT public.get_current_user_id())
              AND (
                  users.is_super_admin = true 
                  OR ((SELECT auth.jwt()) ->> 'email') IN ('kshtriyaanubhav9120@gmail.com', 'anubhavsingh2000000@gmail.com')
              )
        )
    );

DROP POLICY IF EXISTS "Super admin has full access to KYC review queue" ON public.kyc_review_queue;
CREATE POLICY "Super admin has full access to KYC review queue"
    ON public.kyc_review_queue
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = (SELECT public.get_current_user_id())
              AND (
                  users.is_super_admin = true 
                  OR ((SELECT auth.jwt()) ->> 'email') IN ('kshtriyaanubhav9120@gmail.com', 'anubhavsingh2000000@gmail.com')
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = (SELECT public.get_current_user_id())
              AND (
                  users.is_super_admin = true 
                  OR ((SELECT auth.jwt()) ->> 'email') IN ('kshtriyaanubhav9120@gmail.com', 'anubhavsingh2000000@gmail.com')
              )
        )
    );

DROP POLICY IF EXISTS "Users can manage their own 5 photo slots" ON public.user_photos;
DROP POLICY IF EXISTS "Users can view verified photos of unblocked users" ON public.user_photos;
DROP POLICY IF EXISTS "Users can view own and verified unblocked photos" ON public.user_photos;
DROP POLICY IF EXISTS "Users can insert own photo slots" ON public.user_photos;
DROP POLICY IF EXISTS "Users can update own photo slots" ON public.user_photos;
DROP POLICY IF EXISTS "Users can delete own photo slots" ON public.user_photos;

CREATE POLICY "Users can view own and verified unblocked photos"
    ON public.user_photos
    FOR SELECT
    TO authenticated
    USING (
        user_id = (SELECT public.get_current_user_id())
        OR (ocr_verified = TRUE AND NOT public.is_mutually_blocked(user_id, (SELECT public.get_current_user_id())))
    );

CREATE POLICY "Users can insert own photo slots"
    ON public.user_photos
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = (SELECT public.get_current_user_id()));

CREATE POLICY "Users can update own photo slots"
    ON public.user_photos
    FOR UPDATE
    TO authenticated
    USING (user_id = (SELECT public.get_current_user_id()))
    WITH CHECK (user_id = (SELECT public.get_current_user_id()));

CREATE POLICY "Users can delete own photo slots"
    ON public.user_photos
    FOR DELETE
    TO authenticated
    USING (user_id = (SELECT public.get_current_user_id()));

-- 4. STORAGE CLEANUP
DROP POLICY IF EXISTS "Public profiles can view photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload own photo slots" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their KYC video" ON storage.objects;
