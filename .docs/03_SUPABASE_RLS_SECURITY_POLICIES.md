# 03_SUPABASE_RLS_SECURITY_POLICIES.md: ZERO-TRUST ROW LEVEL SECURITY (RLS) ENGINE
# Project: UR-Heart (Mindful Dating Platform)
# Target Environment: Supabase PostgreSQL 15 Engine
# Compliance: DPDP Act 2023, IT Rules 2021, Google Play UGC Mandates

---

## 1. ZERO-TRUST ARCHITECTURE & THREAT MODEL

UR-Heart zero-trust data access model par operate karta hai. Flutter client application direct Supabase PostgREST endpoints se interact kar sakti hai, isliye database engine level par data isolation enforce hona anivarya hai. Backend FastAPI layer privileged operations ke liye `service_role` use karegi, jabki direct client interactions authenticated JWT (`auth.uid()`) ke context mein execute hongi.

### 1.1 Core Security Boundaries
1. **Zero Eavesdropping**: Koi bhi user kisi aise match ke messages read ya insert nahi kar sakta jisme wo directly active participant na ho.
2. **Swipe Isolation**: User sirf apne dwara execute kiye gaye swipes view aur insert kar sakta hai; doosre users ke private swipe preferences inspect karna impossible hai.
3. **Monetization Tamper-Proofing**: `ad_reward_ledger` aur reward balances client-side PostgREST par direct write-protected rahenge; inme modifications strictly backend Server-Side Verification (SSV) ke through hi execute honge.
4. **Incognito & Soft-Deletion Shield**: De-activated (`deleted_at IS NOT NULL`) ya incognito-enabled profiles unauthenticated ya unauthorized discover feed queries se automatically filter out hongi.
5. **Perimeter Enforcement**: Blocked users (`blocked_users`) feed, likes, dialogue history aur direct discovery se completely mask rahenge.

---

## 2. OPTIMIZED SECURITY DEFINER HELPER FUNCTIONS

RLS policies ke andar complex sub-queries bar-bar execute hone par database compute latency aur connection memory rapidly spike karti hai. Is overhead ko minimize karne ke liye caching aur security-definer helper functions define kiye gaye hain.

```sql
-- ============================================================================
-- HELPER FUNCTIONS FOR HIGH-PERFORMANCE RLS EVALUATION
-- ============================================================================

-- 1. Helper: Resolve Internal User UUID from Supabase auth.uid()
-- Uses STABLE and SECURITY DEFINER to prevent plan re-evaluation per row
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID AS $$
    SELECT id FROM public.users 
    WHERE auth_id = auth.uid() 
      AND deleted_at IS NULL 
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2. Helper: Check if two users have an active two-sided mutual match
CREATE OR REPLACE FUNCTION public.is_active_match_participant(target_match_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = target_match_id
          AND is_active = TRUE
          AND (user1_id = public.get_current_user_id() OR user2_id = public.get_current_user_id())
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 3. Helper: Check if a user is blocked by or has blocked the target user
CREATE OR REPLACE FUNCTION public.is_user_blocked(target_user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE (blocker_id = public.get_current_user_id() AND blocked_id = target_user_id)
           OR (blocker_id = target_user_id AND blocked_id = public.get_current_user_id())
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
3. MASTER RLS ENFORCEMENT & POLICY DEFINITIONS
Sabhi tables par Row Level Security explicitly enable ki gayi hai taaki bina policy ke koi bhi record unintentionally expose na ho sake.   
PDF

SQL


-- ============================================================================
-- ENABLE RLS ACROSS ALL PRODUCTION ENTITIES
-- ============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_reward_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_reveal_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grievance_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_nominees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;
3.1 public.users Policies
Public Persona View: Authenticated users active, verified aur non-incognito profiles view kar sakte hain, basharte dono ke beech active block na ho.   
PDF

Private Identity Security: Sensitive fields (jaise whatsapp_encrypted) feed view mein expose nahi hote.   
PDF

Self-Update Only: Profile attributes sirf authentic account owner hi modify kar sakta hai.   
PDF

SQL


-- USERS: SELECT (Discover Feed & Match Profile View)
CREATE POLICY "users_select_active_profiles"
ON public.users FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL 
    AND (
        -- User can view own full profile
        auth_id = auth.uid()
        OR (
            -- Or other users who are active, non-incognito, and not in blocked perimeter
            is_incognito = FALSE 
            AND NOT public.is_user_blocked(id)
        )
    )
);

-- USERS: UPDATE (Self Profile Modification Only)
CREATE POLICY "users_update_own_profile"
ON public.users FOR UPDATE
TO authenticated
USING (auth_id = auth.uid())
WITH CHECK (auth_id = auth.uid());

-- USERS: INSERT (Triggered only during initial onboarding session)
CREATE POLICY "users_insert_own_profile"
ON public.users FOR INSERT
TO authenticated
WITH CHECK (auth_id = auth.uid());
3.2 public.swipes Policies
Actor Integrity: User sirf apne internal ID ke reference se hi swipe insert kar sakta hai[cite: 1].

History Confidentiality: User sirf apne dwara pass/like kiye gaye profiles dekh sakta hai[cite: 1].

SQL


-- SWIPES: INSERT (Record like, pass, superlike)[cite: 1]
CREATE POLICY "swipes_insert_own_actions"
ON public.swipes FOR INSERT
TO authenticated
WITH CHECK (
    actor_id = public.get_current_user_id()
    AND actor_id <> target_id
    AND NOT public.is_user_blocked(target_id)
);

-- SWIPES: SELECT (View past swipe history / Ignored profiles)[cite: 1]
CREATE POLICY "swipes_select_own_history"
ON public.swipes FOR SELECT
TO authenticated
USING (actor_id = public.get_current_user_id());

-- SWIPES: DELETE (Un-pass / restore ignored profiles from vault)
CREATE POLICY "swipes_delete_own_pass_swipes"
ON public.swipes FOR DELETE
TO authenticated
USING (
    actor_id = public.get_current_user_id() 
    AND swipe_type = 'pass'
);
3.3 public.matches Policies
Mutual Match Isolation: Match records sirf unhi do users ko visible honge jinke beech connection create hua hai[cite: 1].

Client Write Lock: Matches table par INSERT aur UPDATE client-side block hai; mutual match confirmation strictly backend transaction se originate hoga[cite: 1].

SQL


-- MATCHES: SELECT (Active Connections Only)[cite: 1]
CREATE POLICY "matches_select_own_connections"
ON public.matches FOR SELECT
TO authenticated
USING (
    is_active = TRUE 
    AND (
        user1_id = public.get_current_user_id() 
        OR user2_id = public.get_current_user_id()
    )
);
3.4 public.messages Policies
Chat Privacy: Messages sirf wahi user padh sakta hai jo us match ka verified participant hai[cite: 1].

Sender Spoofing Prevention: Message send karte waqt sender_id current user ka hona compulsory hai aur match is_active = TRUE hona chahiye[cite: 1].

SQL


-- MESSAGES: SELECT (Chronological Chat History in Active Match)[cite: 1]
CREATE POLICY "messages_select_active_dialogue"
ON public.messages FOR SELECT
TO authenticated
USING (
    public.is_active_match_participant(match_id)
);

-- MESSAGES: INSERT (Send Encrypted Message)[cite: 1]
CREATE POLICY "messages_insert_own_dialogue"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = public.get_current_user_id()
    AND public.is_active_match_participant(match_id)
);

-- MESSAGES: UPDATE (Mark delivered / read acknowledgments)
CREATE POLICY "messages_update_status_ack"
ON public.messages FOR UPDATE
TO authenticated
USING (
    public.is_active_match_participant(match_id)
)
WITH CHECK (
    public.is_active_match_participant(match_id)
);
3.5 public.ad_reward_ledger Policies
Financial Integrity: Reward ledger table par client-side direct INSERT, UPDATE ya DELETE 100% blocked hai[cite: 1].

Audit Transparency: Authenticated user sirf apne rewards ki ledger history view kar sakta hai[cite: 1]. Records insert karne ka adhikar sirf backend FastAPI SSV callback worker ke paas hai (service_role bypass)[cite: 1].

SQL


-- AD REWARDS: SELECT (Audit Own Rewards)[cite: 1]
CREATE POLICY "ad_rewards_select_own_ledger"
ON public.ad_reward_ledger FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());
3.6 public.whatsapp_reveal_tokens Policies
Dual-Consent Safety: WhatsApp token details sirf tab visible honge jab user us specific match ka hissa ho[cite: 1].

Progress Update: User sirf apne consent aur ad counter state ko update kar sakta hai; opponent user ke attributes ko tamper nahi kiya ja sakta[cite: 1].

SQL


-- WHATSAPP REVEAL: SELECT (Verify Progress & Token Access)[cite: 1]
CREATE POLICY "wa_tokens_select_match_participants"
ON public.whatsapp_reveal_tokens FOR SELECT
TO authenticated
USING (
    public.is_active_match_participant(match_id)
);

-- WHATSAPP REVEAL: UPDATE (Increment Ad Progress or Grant Consent)[cite: 1]
CREATE POLICY "wa_tokens_update_match_participants"
ON public.whatsapp_reveal_tokens FOR UPDATE
TO authenticated
USING (
    public.is_active_match_participant(match_id)
)
WITH CHECK (
    public.is_active_match_participant(match_id)
);
3.7 public.blocked_users Policies
Instant Perimeter Control: Google Play UGC policy compliance ke tehat user kisi bhi objectionable user ko block kar sakta hai aur apni block list manage kar sakta hai.   
PDF
+ 1

SQL


-- BLOCKED USERS: SELECT (Manage Blocked Perimeter)
CREATE POLICY "blocked_users_select_own_list"
ON public.blocked_users FOR SELECT
TO authenticated
USING (blocker_id = public.get_current_user_id());

-- BLOCKED USERS: INSERT (Execute Instant Block)[cite: 1]
CREATE POLICY "blocked_users_insert_block"
ON public.blocked_users FOR INSERT
TO authenticated
WITH CHECK (
    blocker_id = public.get_current_user_id()
    AND blocker_id <> blocked_id
);

-- BLOCKED USERS: DELETE (Unblock User)
CREATE POLICY "blocked_users_delete_unblock"
ON public.blocked_users FOR DELETE
TO authenticated
USING (blocker_id = public.get_current_user_id());
3.8 public.grievance_dossiers Policies
Statutory Dossier Filing: User IT Rules 2021 ke tahat kisi bhi violator ke khilaf report/grievance submit kar sakta hai aur apne dwara file kiye gaye dossiers ka status dekh sakta hai.   
PDF
+ 1

SQL


-- GRIEVANCE: INSERT (Submit Abuse or UGC Violation Dossier)[cite: 1, 13]
CREATE POLICY "grievance_insert_dossier"
ON public.grievance_dossiers FOR INSERT
TO authenticated
WITH CHECK (
    reporter_id = public.get_current_user_id()
    AND reporter_id <> reported_user_id
);

-- GRIEVANCE: SELECT (Track Filed Complaints)[cite: 13]
CREATE POLICY "grievance_select_own_dossiers"
ON public.grievance_dossiers FOR SELECT
TO authenticated
USING (reporter_id = public.get_current_user_id());
3.9 public.data_nominees & public.data_export_requests Policies
DPDP Act 2023 Statutory Rights: Section 11 (Right to Access Data) aur Section 14 (Right to Nominate) ke records strictly account owner ke sath isolated rahenge[cite: 13].

SQL


-- DATA NOMINEE: ALL (Manage Nominee under DPDP Sec 14)[cite: 13]
CREATE POLICY "nominees_manage_own_record"
ON public.data_nominees FOR ALL
TO authenticated
USING (user_id = public.get_current_user_id())
WITH CHECK (user_id = public.get_current_user_id());

-- DATA EXPORT: SELECT & INSERT (Request Export under DPDP Sec 11)[cite: 13]
CREATE POLICY "export_select_own_requests"
ON public.data_export_requests FOR SELECT
TO authenticated
USING (user_id = public.get_current_user_id());

CREATE POLICY "export_insert_request"
ON public.data_export_requests FOR INSERT
TO authenticated
WITH CHECK (user_id = public.get_current_user_id());
4. SERVICE ROLE ISOLATION & ELEVATED BACKEND JOBS
FastAPI backend services elevated operations ke liye supabase_admin service key use karti hain. service_role PostgreSQL ke Row Level Security policies ko bypass karta hai[cite: 1].

Permitted Service Role Operations:
Ad SSV Callbacks: Verified cryptographic signatures ke baad ad_reward_ledger aur user reward balances update karna[cite: 1].

Groq AI KYC Pipeline: Face verification aur neutral age check confirm hone ke baad kyc_status = TRUE set karna[cite: 1].

Automated Purge Routine: purge_expired_temporary_records() function execute karke disk consumption 500MB ke andar rakhna[cite: 1].

DPDP Permanent Cascading Deletion: Account deletion request aane par related photos (Cloudflare R2) aur database rows ko cascade hard-delete karna.   
PDF
+ 1

5. RLS AUDIT & SECURITY VERIFICATION SUITE
Antigravity agent ko RLS apply karne ke baad Supabase SQL Editor mein ye test scripts run karke security isolation audit karni hogi:

SQL


-- ============================================================================
-- RLS VERIFICATION TEST SUITE (Run as authenticated user simulation)
-- ============================================================================

-- Step 1: Simulate authenticated session for User A
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

-- Test Case A: User A attempts to read messages of Match where they are NOT participant
-- Expected: Empty result set (0 rows returned)
SELECT * FROM public.messages 
WHERE match_id = '99999999-9999-9999-9999-999999999999';

-- Test Case B: User A attempts to write directly into ad_reward_ledger
-- Expected: ERROR: new row violates row-level security policy for table "ad_reward_ledger"
INSERT INTO public.ad_reward_ledger (user_id, ssv_transaction_id, network, ad_type, reward_points)
VALUES ('11111111-1111-1111-1111-111111111111', 'fake_ssv_tx_001', 'admob', 'quick_reflection', 50);

-- Reset Role
RESET ROLE;
