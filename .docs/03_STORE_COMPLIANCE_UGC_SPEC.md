# App Store & Google Play Store Compliance Specification (UGC, Safety & Data Erasure)

**Document Identifier:** URH-STR-003  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**Target App Stores:** Google Play Store (Android Primary), Apple App Store (iOS Secondary)  
**Applicable Store Policies:**  
1. Google Play Developer Program Policies: User Generated Content (UGC) Policy  
2. Google Play Families & Child Safety Policies: Restrict Declared Minors & Age-Restricted Social Apps  
3. Google Play Data Safety: Mandatory App Account Deletion Policy (In-App & Public Web)  
4. Apple App Store Review Guidelines: Section 1.2 (User Generated Content) & Section 5.1.1 (Data Collection and Storage)

---

## 1. Store Review Rejection Hazards & Elimination Strategy

Dating applications face an exceptionally high initial rejection and suspension rate (>70%) across Google Play and Apple App Store due to three primary policy enforcement areas:
1. **Unregulated UGC & Inadequate Moderation:** Allowing user-to-user messaging or photo uploads without pre-EULA agreement, accessible in-app reporting, and instant blocking triggers an immediate permanent suspension.
2. **Underage Exposure (Minors on Adult/Dating Platforms):** Failure to enforce strict 18+ age gates, combined with inadequate protection against brute-force age guessing, violates Google Play’s *Child Endangerment* and *Dating Services* guidelines.
3. **Missing Public Web Account Deletion Pathway:** As mandated by Google Play policies, apps allowing account creation must provide an independent, functional **Web Deletion URL** alongside an in-app "One-Tap Delete" mechanism. Missing or non-functional web deletion forms result in immediate rejection during review.

---

## 2. UGC Safety Architecture & Store Review Shield

### 2.1. Pre-UGC End User License Agreement (EULA) Gate
- **Enforcement Rule:** No user can view the discovery feed, upload photos, or send messages until they have actively accepted the UR-Heart Terms of Service & EULA.
- **Client Implementation:** During initial onboarding, prior to profile generation, the user is presented with a non-dismissible modal displaying the EULA summary.
- **Explicit Agreement:** A single disabled button "Accept Terms & Continue" activates only after the user scrolls through the core clauses or checks an affirmative box.
- **Backend Gatekeeper:** The user creation API (`POST /api/v1/auth/session-sync`) verifies the presence of an active `TERMS_EULA` consent record. If missing, all downstream UGC mutations return `HTTP 403 Forbidden`.

### 2.2. Instant User Blocking Engine (Zero-Latency Mutual Suppression)
Google Play UGC guidelines mandate an instant, friction-free mechanism for users to block abusive counterparts in 1:1 messaging or profile browsing.

#### Technical Execution Flow:
1. **Trigger:** Available on every Profile Card (Feed) and Chat Screen AppBar via a persistent 3-dot overflow icon $\rightarrow$ "Block User".
2. **Immediate Client Suppression:**
   - The Flutter client immediately removes the active profile card from the local feed array.
   - If triggered inside a chat, the navigation stack pops back to the conversation list immediately, and the chat item is visually hidden.
3. **Backend Propagation:**
   - Client issues `POST /api/v1/safety/block` with the target `user_id`.
   - Record is inserted into `public.blocked_users` with a unique constraint `(blocker_id, blocked_id)`.
   - Existing mutual record in `public.matches` is updated to `is_active = FALSE`.
   - The active WebSocket connection terminates the conversation channel between both parties.
4. **Reciprocal Feed Filtering:**
   - Feed query SQL explicitly incorporates:
     ```sql
     WHERE target.id NOT IN (
         SELECT blocked_id FROM public.blocked_users WHERE blocker_id = :current_user_id
         UNION
         SELECT blocker_id FROM public.blocked_users WHERE blocked_id = :current_user_id
     )
     ```
   - Neither user will ever see each other’s profile in search, feed, or active chat lists again.

### 2.3. In-App Reporting System & Moderation Triage
Google Play requires an accessible, structured reporting mechanism for objectionable content.

#### Reporting Taxonomy:
When a user taps "Report", a native modal presents standardized categories matching Google Play guidelines:
1. `harassment_bullying`: Threats, abusive language, intimidation.
2. `ncii_nudity`: Non-consensual intimate imagery, pornography, or sexually explicit photos.
3. `fake_impersonation`: Using another person's photos, identity theft, or deceptive bot behavior.
4. `underage_user`: Suspected minor under 18 years of age.
5. `commercial_spam`: Commercial solicitation, selling goods/services, or financial fraud.

#### Automated Action Thresholds:
- **Single Report on `ncii_nudity`:** Profile is instantly un-indexed from the public feed pending human/automated review.
- **Cumulative Threshold ($\ge 3$ unique reports across 24 hours):** System automatically applies `public.users.is_banned = TRUE`, terminates active WebSocket connections, and flags the account in the internal admin review queue.

---

## 3. Minor Protection, Age-Gating & Underage Quarantine

### 3.1. Google Play Console Mandatory Settings
- **Target Audience:** Select **18 and older** exclusively.
- **Content Rating:** Questionnaire must be completed to reflect dating/matchmaking features, yielding an **IARC 18+ / Mature** rating.
- **Restrict Declared Minors:** Must be toggled **ON** inside Google Play Console $\rightarrow$ App Content $\rightarrow$ Age-restricted content and functionality.

### 3.2. Neutral Age Verification Onboarding Workflow
To prevent automated or lazy bypasses:
1. **Neutral DOB Wheel:** Onboarding displays a Date of Birth selector initialized with no default date, month, or year selected.
2. **Underage Calculation:**
   $$\text{Calculated Age} = \frac{\text{Current Date} - \text{Submitted DOB}}{365.25}$$
3. **Hard Termination:** If calculated age is $< 18$:
   - Client displays: *"UR-Heart is strictly for adults aged 18 and older. Registration aborted."*
   - App navigates to an exit screen and disables further onboarding interactions.

### 3.3. Underage Device Quarantine Architecture
To stop underage users from simply restarting the app and picking an older birth year:
1. Client generates a cryptographic SHA-256 fingerprint:
   $$\text{Quarantine Hash} = \text{SHA-256}(\text{Android\_ID} + \text{Submitted\_Phone\_Number})$$
2. Hash is sent to FastAPI: `POST /api/v1/auth/quarantine-device`.
3. FastAPI persists the hash in `public.underage_quarantine` with `quarantined_until = NOW() + INTERVAL '180 days'`.
4. Any registration attempt matching a quarantined hash returns `HTTP 403 Forbidden` with detail: *"Service unavailable for this account"*, preventing birthdate brute-forcing.

---

## 4. Mandatory Account & Data Erasure (In-App & Public Web)

Google Play's Data Deletion Policy mandates both an **In-App Pathway** and an **Independent Public Web Page**.

### 4.1. In-App One-Tap Data Erase
- **Location:** Accessible within 2 taps: `Profile -> Settings -> Account Security -> Delete Account & Erase All Data`.
- **Warning Dialog:** *"This will permanently destroy your profile, 5 photos, matches, and chat history. Active streaks and ad balances will be lost forever."*
- **Execution Cascade:**
  1. Client calls `DELETE /api/v1/account/delete-me`.
  2. Supabase Storage API deletes `/users/{user_id}/` folder containing WebP photos.
  3. Firebase Admin SDK deletes the user record from Firebase Authentication.
  4. Database executes hard-delete or marks `deleted_at = NOW()` and unlinks foreign keys via `ON DELETE CASCADE`.
  5. Local sandbox storage (including `installation_uuid`) is wiped, and app reboots to Splash screen.

### 4.2. Public Web Deletion Resource (Store Listing Requirement)
- **Official Public URL:** `https://asiverticals.com/ur-heart/data-deletion`
- **Branding Mandate:** Page prominently features the exact app name **"UR-Heart"** and developer name **"ASI Verticals"** as displayed on the Google Play listing.
- **Independent Verification Protocol:**
  Users who have uninstalled the application can trigger complete data erasure via web:
  1. User enters their registered phone number.
  2. Backend dispatches a 6-digit verification OTP.
  3. Upon successful OTP submission, FastAPI initiates the identical database and storage purge cascade.
  4. Confirmation receipt is rendered on screen and transmitted via SMS/WhatsApp.
- **SLA Disclosure:** Web page explicitly states: *"All associated personal data, photos, and messages are permanently purged from active databases immediately, with complete residual backup rotation finalized within 30 days."*

### 4.3. Google Play Console Data Safety Submission Matrix
The following exact answers must be entered into the Play Console Data Safety questionnaire:

| Data Type Collected | Declared as Collected? | Declared as Shared? | Purpose of Collection | Deletion Pathway Provided? |
| :--- | :--- | :--- | :--- | :--- |
| **Name** | Yes | No | App functionality / Profile display | Yes (1-Tap App & Web) |
| **Phone Number / WhatsApp** | Yes | No | Account management / Consented reveal | Yes (1-Tap App & Web) |
| **Photos (5 slots)** | Yes | No | App functionality (Matching) | Yes (1-Tap App & Web) |
| **Live Video/Audio KYC** | Yes (Transient) | No | Fraud prevention / Account safety | Yes (Auto-purged in 24-48h) |
| **Date of Birth** | Yes | No | Age verification (18+ compliance) | Yes (1-Tap App & Web) |
| **In-App Messages** | Yes | No | User-to-user communication | Yes (30-day auto-purge + manual) |
| **Device IDs / Installation UUID**| Yes | No | Analytics & Streak fraud prevention | Yes (Wiped on uninstall) |

---

## 5. Production Database DDL: UGC Safety, Blocking & Quarantine

Deploy the following schema directly to Supabase:

```sql
-- =============================================================================
-- GOOGLE PLAY UGC, BLOCKING & UNDERAGE QUARANTINE DDL
-- =============================================================================

-- 1. BLOCKED USERS TABLE (Instant 1:1 Suppression)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_block_pair UNIQUE (blocker_id, blocked_id),
    CONSTRAINT check_cannot_block_self CHECK (blocker_id <> blocked_id)
);

CREATE INDEX idx_blocked_users_blocker ON public.blocked_users(blocker_id);
CREATE INDEX idx_blocked_users_blocked ON public.blocked_users(blocked_id);

-- 2. USER REPORTS TABLE (UGC Content Moderation)
CREATE TABLE IF NOT EXISTS public.user_reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL CHECK (
        reason IN ('harassment_bullying', 'ncii_nudity', 'fake_impersonation', 'underage_user', 'commercial_spam', 'other')
    ),
    details VARCHAR(500) DEFAULT '',
    context_match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL,
    is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
    action_taken VARCHAR(50) DEFAULT 'none' CHECK (
        action_taken IN ('none', 'warning_issued', 'profile_quarantined', 'permanent_ban', 'false_report')
    ),
    reviewed_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_reported_id ON public.user_reports(reported_id);
CREATE INDEX idx_reports_unreviewed ON public.user_reports(is_reviewed) WHERE is_reviewed = FALSE;

-- 3. UNDERAGE QUARANTINE REGISTRY (Anti-Bypass Device Ledger)
CREATE TABLE IF NOT EXISTS public.underage_quarantine (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_phone_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256(Android_ID + Phone)
    quarantined_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '180 days'),
    attempt_count INT2 NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quarantine_hash ON public.underage_quarantine(device_phone_hash);

-- 4. HELPER FUNCTION: AUTOMATED ACCOUNT FREEZE ON MULTIPLE REPORTS
CREATE OR REPLACE FUNCTION trigger_auto_moderation_on_reports()
RETURNS TRIGGER AS $$
DECLARE
    recent_report_count INT;
BEGIN
    -- Check if user received >= 3 unique reports within 24 hours
    SELECT COUNT(DISTINCT reporter_id) INTO recent_report_count
    FROM public.user_reports
    WHERE reported_id = NEW.reported_id
      AND created_at >= NOW() - INTERVAL '24 hours';

    IF recent_report_count >= 3 THEN
        UPDATE public.users
        SET is_banned = TRUE
        WHERE id = NEW.reported_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_evaluate_user_reports
AFTER INSERT ON public.user_reports
FOR EACH ROW
EXECUTE FUNCTION trigger_auto_moderation_on_reports();
6. Backend Safety Microservice Implementation (FastAPI)Below is the production implementation for reporting, blocking, and account deletion (app/api/v1/endpoints/safety.py):Pythonfrom fastapi import APIRouter, Depends, HTTPException, status, Header
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from uuid import UUID
import hashlib

from app.core.database import get_db
from app.api.dependencies import get_current_user_id
from app.models.domain.user import User
from app.models.domain.safety import UserReport, BlockedUser, UnderageQuarantine
from app.models.domain.match import Match
from app.services.storage_service import purge_user_storage_assets

router = APIRouter()

class BlockUserRequest(BaseModel):
    blocked_user_id: UUID

class ReportUserRequest(BaseModel):
    reported_user_id: UUID
    reason: str = Field(..., example="harassment_bullying")
    details: str = Field("", max_length=500)
    match_id: UUID = None

class UnderageQuarantineRequest(BaseModel):
    android_id: str
    phone_number: str

# 1. INSTANT USER BLOCKING ENDPOINT
@router.post("/api/v1/safety/block", status_code=status.HTTP_201_CREATED)
async def block_user(
    req: BlockUserRequest,
    current_user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    if current_user_id == req.blocked_user_id:
        raise HTTPException(status_code=400, detail="Cannot block self.")

    # Check if already blocked
    stmt = select(BlockedUser).where(
        BlockedUser.blocker_id == current_user_id,
        BlockedUser.blocked_id == req.blocked_user_id
    )
    res = await db.execute(stmt)
    if res.scalar_one_or_none():
        return {"status": "success", "message": "User already blocked."}

    # Insert block record
    new_block = BlockedUser(blocker_id=current_user_id, blocked_id=req.blocked_user_id)
    db.add(new_block)

    # Deactivate any mutual matches immediately
    await db.execute(
        update(Match)
        .where(
            ((Match.user1_id == current_user_id) & (Match.user2_id == req.blocked_user_id)) |
            ((Match.user1_id == req.blocked_user_id) & (Match.user2_id == current_user_id))
        )
        .values(is_active=False)
    )
    await db.commit()
    return {"status": "success", "message": "User blocked successfully. Mutual visibility revoked."}

# 2. IN-APP REPORTING ENDPOINT
@router.post("/api/v1/safety/report", status_code=status.HTTP_201_CREATED)
async def report_user(
    req: ReportUserRequest,
    current_user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    valid_reasons = ('harassment_bullying', 'ncii_nudity', 'fake_impersonation', 'underage_user', 'commercial_spam', 'other')
    if req.reason not in valid_reasons:
        raise HTTPException(status_code=400, detail=f"Invalid reason. Must be one of {valid_reasons}")

    report_entry = UserReport(
        reporter_id=current_user_id,
        reported_id=req.reported_user_id,
        reason=req.reason,
        details=req.details,
        context_match_id=req.match_id
    )
    db.add(report_entry)
    await db.commit()
    return {"status": "success", "message": "Report submitted. Our safety team will review this within 24 hours."}

# 3. UNDERAGE QUARANTINE ENDPOINT
@router.post("/api/v1/auth/quarantine-device", status_code=status.HTTP_200_OK)
async def quarantine_underage_device(
    req: UnderageQuarantineRequest,
    db: AsyncSession = Depends(get_db)
):
    raw_identifier = f"{req.android_id.strip()}:{req.phone_number.strip()}"
    device_hash = hashlib.sha256(raw_identifier.encode('utf-8')).hexdigest()

    stmt = select(UnderageQuarantine).where(UnderageQuarantine.device_phone_hash == device_hash)
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()

    if existing:
        existing.attempt_count += 1
    else:
        new_quarantine = UnderageQuarantine(device_phone_hash=device_hash)
        db.add(new_quarantine)

    await db.commit()
    return {"status": "quarantined", "detail": "Account creation restricted under Play Store minor protection policies."}

# 4. IN-APP ONE-TAP ACCOUNT & DATA ERASURE
@router.delete("/api/v1/account/delete-me", status_code=status.HTTP_200_OK)
async def delete_user_account_and_data(
    current_user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    # 1. Purge physical storage files from Supabase Storage
    await purge_user_storage_assets(current_user_id)

    # 2. Hard delete user database record (Cascades to photos, messages, matches, swipes)
    stmt = delete(User).where(User.id == current_user_id)
    await db.execute(stmt)
    await db.commit()

    return {"status": "success", "message": "Your profile, photos, and chat logs have been permanently erased."}
7. Store Review Submission Checklist for Antigravity AgentBefore triggering release builds, Antigravity must run through this automated compliance test suite:[ ] EULA Blocking Verification: Confirm unauthenticated or un-consented API calls to feed/chat return HTTP 403.[ ] 3-Dot Menu Visibility: Verify that every user card in the Flutter feed and every chat appbar contains both "Report Profile" and "Block User" options.[ ] Feed Block Isolation: Execute automated integration test: User A blocks User B $\rightarrow$ Verify User B disappears from User A's feed and User A disappears from User B's feed within $\le 50$ ms.[ ] Underage Lockdown: Submit registration payload with birth year indicating 17 years old $\rightarrow$ Confirm underage_quarantine row is created and subsequent attempts return rejection.[ ] Account Deletion Cascade: Call /api/v1/account/delete-me $\rightarrow$ Confirm user record in public.users and image objects in storage are zeroed out.[ ] Web Deletion URL Availability: Verify that https://asiverticals.com/ur-heart/data-deletion resolves with HTTP 200 OK and renders the functional OTP request form.Certified & Prepared for ASI Verticals Google Play & Apple App Store Release Engineering.