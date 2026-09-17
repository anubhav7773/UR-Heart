-- Migration: 004_geospatial_privacy_engine
-- Created: 2026-09-17
-- Description: Geospatial Privacy Engine, Identity Extensions ('lgbtq+'), and Proximity Discovery RPC

-- 1. Extend Gender Constraint to support 'lgbtq+'
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_gender_check;
ALTER TABLE public.users 
ADD CONSTRAINT users_gender_check 
CHECK (gender IN ('male', 'female', 'lgbtq+'));

-- 2. Add Private Spatial Coordinates & Locality Columns
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS latitude NUMERIC(9, 6) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS longitude NUMERIC(9, 6) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS detected_locality VARCHAR(100) DEFAULT NULL;

-- 3. Composite Spatial B-Tree Index for Bounded Distance Scans
CREATE INDEX IF NOT EXISTS idx_users_geospatial ON public.users(latitude, longitude) 
WHERE deleted_at IS NULL AND is_banned = FALSE;

-- 4. High-Performance Haversine Distance Calculation Function (In Kilometers)
CREATE OR REPLACE FUNCTION public.calculate_distance_km(
    lat1 NUMERIC, lon1 NUMERIC, lat2 NUMERIC, lon2 NUMERIC
) RETURNS INT AS $$
DECLARE
    dlat NUMERIC;
    dlon NUMERIC;
    a NUMERIC;
    c NUMERIC;
BEGIN
    IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Convert decimal degrees to radians
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    
    a := sin(dlat / 2.0)^2 + 
         cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2.0)^2;
         
    c := 2.0 * asin(sqrt(a));
    
    -- Earth's mean radius = 6371 km
    RETURN ROUND(6371.0 * c);
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- 5. Secure Discovery Feed RPC Function (Privacy-Locked)
-- Guarantees exact coordinates never leak to client; emits only relative distance & city name
CREATE OR REPLACE FUNCTION public.get_discovery_feed(
    p_current_user_id UUID,
    p_user_lat NUMERIC,
    p_user_lon NUMERIC,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    user_id UUID,
    full_name VARCHAR(50),
    city VARCHAR(50),
    detected_locality VARCHAR(100),
    distance_km INT,
    gender VARCHAR(10),
    bio VARCHAR(250),
    streak_count INT2,
    photos JSONB
) AS $$
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
      -- Exclude profiles already swiped by the current user
      AND NOT EXISTS (
          SELECT 1 FROM public.swipes s 
          WHERE s.actor_id = p_current_user_id AND s.target_id = u.id
      )
    ORDER BY distance_km ASC NULLS LAST, u.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
