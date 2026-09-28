# 360° FORENSIC SECURITY, CRYPTOGRAPHIC & STATUTORY LEGAL AUDIT DOSSIER
**Project**: UR-Heart (Mindful Dating Sanctuary)  
**Date**: September 28, 2026  
**Auditor Roles**: Principal DevSecOps Architect, Certified Ethical Hacker (CEH), Regulatory Compliance Counsel  
**Scope**: Full Stack Ecosystem (Flutter Client, FastAPI Core Engine, Supabase PostgreSQL RLS, Firebase Cloud Storage, Groq LPU Cluster, Ad SSV & Billing Webhooks)

---

## 1. EXECUTIVE RISK MATRIX

| ID | Category | Pillar | Vulnerability / Statutory Defect | Severity | CVSS v3.1 | Exploit Surface |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | Authentication Bypass | 2. Auth & Escalation | JWT Signature & Expiration Verification Disabled (`verify_signature: False`) | **CRITICAL** | **10.0** | Backend API |
| **SEC-02** | Privilege Escalation | 2. Auth & Escalation | Supabase RLS Allows Direct Mutation of `kyc_status`, `subscription_tier`, & `reward_balance` | **CRITICAL** | **9.8** | Database / RLS |
| **SEC-03** | Data Exposure / Safety | 3. Privacy Enclaves | Orientation Shield Missing in RLS; Public Enumeration of LGBTQ+ Users & Coordinates | **CRITICAL** | **9.1** | Database / RLS |
| **SEC-04** | Financial Fraud | 5. Cryptography | Unauthenticated InMobi/Meta/Unity SSV Callbacks Granting Unlimited Free Rewards | **CRITICAL** | **9.8** | Billing / SSV API |
| **SEC-05** | Financial Fraud | 6. Revenue Shield | Unauthenticated RevenueCat & Store Audit Webhooks Allowing Arbitrary Lifetime Upgrades | **CRITICAL** | **9.8** | Billing Webhooks |
| **SEC-06** | Statutory Non-Compliance| 1. Statutory Legal | Non-Existent Account Incinerator Backend Endpoint (`DELETE /incinerate-account` 404) | **CRITICAL** | **9.0** | DPDP Act Sec 12 |
| **SEC-07** | Data Exposure | 2. Auth & Escalation | RLS Exposes Encrypted WhatsApp, Coordinates & Installation UUID to All Authenticated Users | **HIGH** | **8.2** | Database / RLS |
| **SEC-08** | Statutory Non-Compliance| 1. Statutory Legal | Underage Quarantine Registry Bypassable via Client Storage Clearance | **HIGH** | **8.5** | DPDP Act Sec 9 |
| **SEC-09** | Statutory Non-Compliance| 1. Statutory Legal | Fake Mock Data Export and Phantom Grievance Submission Endpoints | **HIGH** | **7.8** | DPDP Sec 11 / IT Rules |
| **SEC-10** | Media Integrity | 4. Media Pipeline | Storage Insecurity: Unauthenticated Anon-Key Client Upsert Overwriting Any User Photos | **HIGH** | **8.0** | Cloud Storage |
| **SEC-11** | Prompt Injection / DoS | 10. AI Reasoning | Direct String Interpolation in LLM Prompts & Synthetic Pass-Through on Failure | **HIGH** | **7.5** | AI Services |
| **SEC-12** | Broken Cryptography | 5. Cryptography | Fake Pseudo-Random Curve25519 Key Fingerprint Generation (`Random()`) | **MEDIUM** | **6.5** | Cryptography Layer |
| **SEC-13** | Network / Eavesdropping| 7. Anti-Tamper | Cleartext WebSocket Protocol (`ws://`) Transmitting Raw Messages with Token in URL | **MEDIUM** | **6.8** | Real-Time Engine |
| **SEC-14** | Secrets Hygiene | 5. Cryptography | Hardcoded Superadmin Email in Client Binary & Plaintext DB Connection String | **MEDIUM** | **5.5** | Client & Environment |
| **SEC-15** | DoS / Resource Drain | 8. DoS Resilience | Absence of Rate Limiting Across Public AI, Auth, and Moderation Endpoints | **MEDIUM** | **5.3** | Gateway / Middleware |
| **SEC-16** | Legal Compliance | 1. Statutory Legal | Bundled Age Declaration and Terms of Service Checkbox Dark Pattern | **LOW** | **3.8** | DPDP Act Sec 6 |

---

## 2. STATUTORY LEGAL LIABILITY ASSESSMENT

### 2.1 Digital Personal Data Protection (DPDP) Act, 2023 (India)
1. **Section 6 (Consent Notices & Unbundled Affirmation)**:
   * *Statutory Mandate*: Consent must be freely given, specific, informed, unconditional, and unambiguous with clear affirmative action for specified purposes.
   * *Non-Compliance Identified*: Screen 1 unbundled checkboxes group age confirmation with contractual agreement to Terms of Service and EULA (`"I confirm that I am at least 18 years old and agree to the Terms of Service & Community EULA"`). Under DPDP Section 6(1), bundling statutory consent with contractual acceptance invalidates the consent. Furthermore, consent timestamps and itemized purpose receipts are not recorded in the database upon submission.
   * *Statutory Penalty Liability*: Schedule Section 28: Up to **₹50 Crores** for breach in observing consent notice obligations.

2. **Section 9 (Processing of Personal Data of Children)**:
   * *Statutory Mandate*: Data fiduciaries are prohibited from processing personal data of children (<18 years). Due diligence and age verification mechanisms are compulsory.
   * *Non-Compliance Identified*: Underage detection in `AgeGateController` only sets a local key in `SharedPreferences`. The app does not transmit the device fingerprint to the `underage_quarantine_registry` table in Supabase. A minor can clear app cache, reinstall the app, or manipulate the date picker to gain access.
   * *Statutory Penalty Liability*: Schedule Section 28: Up to **₹200 Crores** for breach of obligations in relation to children.

3. **Section 11 (Right to Access Information & Data Portability)**:
   * *Statutory Mandate*: Data Principal has the statutory right to obtain a summary of personal data and an exportable bundle.
   * *Non-Compliance Identified*: `VaultRepository.requestDataExport()` issues a call to a non-existent endpoint (`/api/v1/vault/export-data`), catches the 404 failure silently, and returns a synthetic dummy URL (`https://vault.urheart.app/exports/$exportId.zip`). The user never receives their actual data.
   * *Statutory Penalty Liability*: Regulatory non-compliance proceedings before the Data Protection Board of India (DPBI).

4. **Section 12 (Right to Correction and Erasure of Personal Data)**:
   * *Statutory Mandate*: Data fiduciary must irrevocably erase personal data upon withdrawal of consent or account deletion request.
   * *Non-Compliance Identified*: `SettingsRepository.incinerateAccountIrrevocably()` calls `DELETE /api/v1/auth/incinerate-account`, which is not registered in FastAPI. The client catches the 404 error, resets the local installation UUID, and displays an account deletion confirmation to the user. The database profile, matches, messages, photos, and KYC video remain fully intact on server infrastructure.
   * *Statutory Penalty Liability*: Severe deceptive practice and breach of Section 12; statutory penalties up to **₹250 Crores** for systemic failure to protect personal data.

5. **Section 14 (Right of Nomination)**:
   * *Statutory Mandate*: Data Principal has the right to nominate an individual to exercise data rights in the event of death or incapacity.
   * *Non-Compliance Identified*: The client UI captures nominee details but swallows the POST request in `VaultRepository.designateNominee()`. Nominee data is retained solely in volatile RAM and is lost upon session termination.

### 2.2 Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021
1. **Rule 3(2) (Grievance Redressal Mechanism)**:
   * *Mandate*: Intermediaries must acknowledge complaints within 24 hours and resolve them within 15 days, maintaining a formal audit log.
   * *Non-Compliance Identified*: `VaultRepository.fileGrievanceDossier()` calls a non-existent route (`/api/v1/vault/grievance`), silently fails, and returns a client-side object. No record is inserted into `public.grievance_dossiers`. Legitimate reports of sexual harassment, impersonation, or underage users are lost.
   * *Liability*: Loss of safe harbor intermediary protection under Section 79 of the Information Technology Act, 2000, exposing platform executives to direct civil and criminal liability for user-generated content.

### 2.3 Google Play Developer & UGC Safety Policies
1. **User-Generated Content (UGC) Policy**:
   * *Mandate*: Apps featuring social interaction must provide in-app user reporting, immediate blocking, and functional moderation enforcement within 24 hours.
   * *Non-Compliance Identified*: The blocking list in `VaultRepository` is hardcoded with 14 static mock profiles (`blk-1` to `blk-14`). Dynamic blocks and grievance dossiers are not synchronized with Supabase backend tables. Google Play app review testers will flag non-functioning moderation endpoints, leading to immediate app rejection or suspension under Google Play Developer Policy.

---

## 3. DETAILED FORENSIC FINDINGS

### 3.1 SEC-01: JWT Signature & Expiration Verification Disabled (CVSS 10.0 - CRITICAL)
* **Location**: `backend/app/core/security.py` (Lines 24–31)
* **Vulnerability Mechanism**:
  ```python
  claims = jwt.decode(
      token,
      options={
          "verify_signature": False,
          "verify_aud": False,
          "verify_exp": False
      }
  )
  ```
* **Exploit Scenario**:
  An attacker crafts a self-signed JWT with arbitrary payload:
  `{"uid": "target-user-uuid", "email": "kshtriyaanubhav9120@gmail.com"}` using any symmetric key. When transmitted via `Authorization: Bearer <forged_token>`, the backend decodes the unverified payload, verifies the user exists in `public.users`, and assigns the identity. If the attacker supplies the hardcoded superadmin email, `require_superadmin` grants full access to the admin KYC queue.
* **Impact**: Total authentication bypass, complete account takeover across all users, and unauthorized superadmin escalation.

---

### 3.2 SEC-02: Supabase RLS Allows Direct Mutation of Sensitive Financial & Administrative Columns (CVSS 9.8 - CRITICAL)
* **Location**: `supabase/migrations/20260927000000_milestone1_database_foundation_sacred_bridge.sql` (Lines 379–382)
* **Vulnerability Mechanism**:
  ```sql
  CREATE POLICY "users_modify_own" ON public.users
      FOR ALL TO authenticated
      USING (auth_id = auth.uid())
      WITH CHECK (auth_id = auth.uid());
  ```
* **Exploit Scenario**:
  Because the policy applies to `FOR ALL` (including `UPDATE`) with no column restrictions, any authenticated user can run via the Supabase client:
  ```javascript
  await supabase.from('users').update({
    kyc_status: true,
    subscription_tier: 'lifetime',
    reward_balance: 999999,
    swipes_remaining: 10000,
    is_ad_free: true
  }).eq('auth_id', supabase.auth.user().id);
  ```
* **Impact**: Users can bypass KYC verification, elevate themselves to lifetime VIP subscriptions, grant themselves infinite ad reward balances, and overwrite verification status without paying or submitting verification videos.

---

### 3.3 SEC-03: Orientation Shield Missing in RLS; Public Enumeration of LGBTQ+ Users & Coordinates (CVSS 9.1 - CRITICAL)
* **Location**: `supabase/migrations/20260927000000_milestone1_database_foundation_sacred_bridge.sql` (Lines 373–376)
* **Vulnerability Mechanism**:
  ```sql
  CREATE POLICY "users_select_active" ON public.users
      FOR SELECT TO authenticated
      USING (deleted_at IS NULL AND (is_incognito = FALSE OR id = public.get_current_user_id()));
  ```
* **Exploit Scenario**:
  While the documentation (`.docs/18_ORIENTATION_SHIELD_AND_LAUNCH_STRATEGY.md`) specifies a strict bi-directional isolation query to prevent forced outing in conservative locations, the Supabase database policy allows any authenticated user to execute:
  ```javascript
  const { data } = await supabase.from('users')
    .select('full_name, dob, gender, interested_in, location_name, latitude, longitude')
    .eq('gender', 'Man')
    .eq('interested_in', 'Men');
  ```
* **Impact**: Malicious actors or stalkers can mass-scrape and dox gay, lesbian, and queer users in regional campuses (Ayodhya, Lucknow), violating statutory privacy and physical safety guarantees.

---

### 3.4 SEC-04: Unauthenticated InMobi/Meta/Unity SSV Callbacks Granting Unlimited Free Rewards (CVSS 9.8 - CRITICAL)
* **Location**: `backend/app/api/v1/endpoints/ads_ssv.py` (Lines 125–127)
* **Vulnerability Mechanism**:
  ```python
  elif network in ("inmobi", "meta", "unity"):
      is_valid = True
  ```
* **Exploit Scenario**:
  An attacker issues repeated GET requests to `/api/v1/ads/verify-reward`:
  ```http
  GET /api/v1/ads/verify-reward?network=unity&transaction_id=fake_tx_999&custom_data=USER_UUID:morning_harvest_unlock HTTP/1.1
  ```
  The endpoint evaluates `is_valid = True`, accepts the custom data, inserts into `processed_ad_transactions`, and grants 20 swipes and 2 direct letters per request.
* **Impact**: Infinite resource exploitation, destruction of ad revenue model, and database bloat.

---

### 3.5 SEC-05: Unauthenticated RevenueCat & Store Audit Webhooks Allowing Arbitrary Lifetime Upgrades (CVSS 9.8 - CRITICAL)
* **Location**: `backend/app/api/v1/endpoints/billing_webhook.py` (Lines 21–25, 81–85)
* **Vulnerability Mechanism**:
  Neither `/webhook/revenuecat` nor `/purchase/audit` enforces webhook authorization tokens, HMAC signature verification, or client authentication.
* **Exploit Scenario**:
  An attacker sends an unauthenticated POST request:
  ```http
  POST /api/v1/billing/webhook/revenuecat HTTP/1.1
  Content-Type: application/json

  {
    "event": {
      "type": "INITIAL_PURCHASE",
      "app_user_id": "VICTIM_OR_ATTACKER_UUID",
      "product_id": "urheart_pass_lifetime",
      "id": "spoofed_rc_txn_001"
    }
  }
  ```
  The backend immediately updates the user record to `subscription_tier = 'lifetime'` and `is_ad_free = True`.
* **Impact**: Total collapse of monetization integrity; any user can acquire premium features freely.

---

### 3.6 SEC-06: Non-Existent Account Incinerator Backend Endpoint (CVSS 9.0 - CRITICAL)
* **Location**: `backend/app/api/v1/endpoints/auth.py` vs `lib/features/settings/data/settings_repository.dart`
* **Vulnerability Mechanism**:
  The client issues a `DELETE` request to `/api/v1/auth/incinerate-account`. No route handler exists on the FastAPI backend for this URL. The client catches the 404 exception in `catch (_) {}`, resets local storage, and presents the user with an account deletion confirmation.
* **Impact**: Statutory violation under DPDP Act 2023 Section 12. User data is never deleted, leaving orphaned records, private chats, KYC videos, and credentials on the server.

---

### 3.7 SEC-07: RLS Exposes Sensitive PII to All Authenticated Users (CVSS 8.2 - HIGH)
* **Location**: `supabase/migrations/20260927000000_milestone1_database_foundation_sacred_bridge.sql` (Line 373)
* **Vulnerability Mechanism**:
  `users_select_active` applies to all columns in `public.users`. There is no column-level security or secure public view separating public persona attributes from sensitive private attributes.
* **Exposed Columns**:
  * `contact_bridge_encrypted` (User's encrypted WhatsApp or social handle)
  * `last_installation_uuid` (Device installation fingerprint)
  * `latitude` & `longitude` (Exact physical GPS coordinates)
  * `reward_balance` (Private financial metric)
  * `auth_id` (Internal identity token)
* **Impact**: Unauthorized profiling, tracking of physical location, and scraping of contact bridges without mutual consent or ad unlock.

---

### 3.8 SEC-08: Underage Quarantine Registry Bypassable via Client Storage Clearance (CVSS 8.5 - HIGH)
* **Location**: `lib/features/auth/presentation/controllers/age_gate_controller.dart` (Lines 76–80)
* **Vulnerability Mechanism**:
  When a user indicates an age under 18, `AgeGateController` saves an expiry timestamp into `SharedPreferences` locally. It never calls a backend API to persist the hardware device hash in `public.underage_quarantine_registry`.
* **Exploit Scenario**:
  A minor inputs a birth date under 18. The app displays the quarantine screen. The user opens Android App Info, taps "Clear Storage", relaunches the app, and inputs a date showing age 19. The app grants full entry.
* **Impact**: Exposure to regulatory action under Section 9 of the DPDP Act 2023.

---

### 3.9 SEC-09: Fake Mock Data Export and Phantom Grievance Submission Endpoints (CVSS 7.8 - HIGH)
* **Location**: `lib/features/legal_vault/data/vault_repository.dart` (Lines 42–108)
* **Vulnerability Mechanism**:
  Calls to `/api/v1/vault/export-data`, `/api/v1/vault/nominee`, and `/api/v1/vault/grievance` fail silently because the backend routes do not exist. Dummy records are returned to the client UI.
* **Impact**: Platform non-compliance under DPDP Act Sections 11 & 14 and IT Rules 2021 Rule 3(2).

---

### 3.10 SEC-10: Storage Insecurity: Unauthenticated Anon-Key Client Upsert Overwriting Any User Photos (CVSS 8.0 - HIGH)
* **Location**: `lib/core/media/supabase_media_uploader.dart` (Lines 37–46)
* **Vulnerability Mechanism**:
  The client uploads photos directly to Supabase Storage using the static public `anonKey` with header `'x-upsert': 'true'` and constructs the target path from the client-supplied `userUuid`:
  `users/$userUuid/moments/slot_$slotNumber.webp`
* **Exploit Scenario**:
  An attacker takes the public `anonKey` and posts arbitrary imagery to `users/<victim_user_uuid>/moments/slot_1.webp`. The storage bucket accepts the upload and overwrites the victim's primary profile photo.
* **Impact**: Arbitrary profile defacement, injection of abusive/explicit imagery, and impersonation.

---

### 3.11 SEC-11: Direct String Interpolation in LLM Prompts & Synthetic Pass-Through on Failure (CVSS 7.5 - HIGH)
* **Location**: `backend/app/services/groq_service.py` (Lines 36–42, 130–134)
* **Vulnerability Mechanism**:
  * In `polish_bio`: `prompt = f"... Bio: {raw_bio} ..."` allows direct prompt injection.
  * In `verify_kyc_liveness`: If both Groq and OpenRouter fail, the function returns a synthetic pass:
    ```python
    return {
        "is_live_human": True,
        "face_match_score": 94,
        "estimated_age_bracket": "24-28",
        "is_underage": False,
        "rejection_reason": ""
    }
    ```
* **Impact**: Attackers can flood the AI service to force failover and bypass KYC biometric checks.

---

### 3.12 SEC-12: Pseudo-Random Curve25519 Key Generation (CVSS 6.5 - MEDIUM)
* **Location**: `lib/features/settings/data/settings_repository.dart` (Lines 57–68)
* **Vulnerability Mechanism**:
  `rotateEncryptionKey()` generates a string using Dart's non-cryptographic `Random()` and labels it `CURVE25519-XXXX-XXXX-XXXX`. No Curve25519 key pair is generated or stored.
* **Impact**: False sense of security; chat messages sent over WebSocket are transmitted in unencrypted plaintext.

---

### 3.13 SEC-13: Cleartext WebSocket Protocol with Token in URL (CVSS 6.8 - MEDIUM)
* **Location**: `lib/features/chat/data/chat_websocket_service.dart` (Lines 26, 38–40)
* **Vulnerability Mechanism**:
  Connects to `ws://10.0.2.2:8000/ws/chat?token=$_authToken` using unencrypted `ws://` rather than `wss://`, transmitting authentication tokens as query parameters.
* **Impact**: Tokens are exposed in intermediate access logs, and traffic is vulnerable to eavesdropping on insecure networks.

---

### 3.14 SEC-14: Hardcoded Superadmin Email in Client Binary & Plaintext DB Password in Local Env (CVSS 5.5 - MEDIUM)
* **Location**: `lib/features/settings/presentation/widgets/superadmin_sentinel_tile.dart` (Line 9) & `backend/.env` (Line 9)
* **Vulnerability Mechanism**:
  `kshtriyaanubhav9120@gmail.com` is embedded in client bytecode. `backend/.env` contains raw database connection strings.
* **Impact**: Reconnaissance aid for targeted phishing or brute-force attempts.

---

### 3.15 SEC-15: Absence of Rate Limiting on API Endpoints (CVSS 5.3 - MEDIUM)
* **Location**: `backend/app/main.py`
* **Vulnerability Mechanism**:
  FastAPI application does not configure slowapi or Redis rate limiting middleware.
* **Impact**: Susceptible to credential stuffing, resource exhaustion on Groq LPU, and Denial of Service.

---

### 3.16 SEC-16: Bundled Age & Terms Checkbox (CVSS 3.8 - LOW)
* **Location**: `lib/features/auth/presentation/widgets/unbundled_checkbox_group.dart` (Line 38)
* **Vulnerability Mechanism**:
  Combines age confirmation (18+) with agreement to Terms of Service and EULA in a single checkbox.
* **Impact**: Technical non-compliance under DPDP Act 2023 Section 6.

---

## 4. STEP-BY-STEP REMEDIATION BLUEPRINT

### Phase A: Core Authentication & Token Hardening (SEC-01, SEC-14)
1. **Enable Strict Cryptographic Token Verification**:
   * Replace the unverified `jwt.decode` in `backend/app/core/security.py` with standard Firebase Admin SDK token verification (`firebase_admin.auth.verify_id_token(token, check_revoked=True)`).
   * For local testing or offline environments, use public key certificates fetched from Google's x509 cert endpoints, verifying algorithm (`RS256`), issuer (`https://securetoken.google.com/<project-id>`), audience (`<project-id>`), and expiry.
2. **Remove Hardcoded Superadmin Email**:
   * Migrate role checks from client-side hardcoded strings to server-side role claims stored in the database (`role = 'superadmin'`) or custom JWT claims (`claims['role'] == 'superadmin'`).

### Phase B: Database RLS Lockdown & Privacy Views (SEC-02, SEC-03, SEC-07)
1. **Restrict User Profile Updates**:
   * Split `users_modify_own` into granular policies or implement a `BEFORE UPDATE` trigger that prevents authenticated clients from altering `kyc_status`, `subscription_tier`, `reward_balance`, `deleted_at`, or `swipes_remaining`. These fields must only be mutable via `service_role` from the backend.
2. **Create Secure Discovery Projection View**:
   * Create a public view `public.discovery_profiles` that exposes only `id`, `full_name`, `age`, `gender`, `bio`, `profession`, `location_name`, `photos`, and `blur_hashes`.
   * Restrict direct `SELECT` on `public.users` so users can only select their own row (`auth_id = auth.uid()`).
3. **Implement Orientation Shield in RLS**:
   * Update the discovery policy on `discovery_profiles` to enforce reciprocal mutual orientation matching:
     ```sql
     (target.gender = current_user.interested_in OR current_user.interested_in = 'Everyone')
     AND
     (current_user.gender = target.interested_in OR target.interested_in = 'Everyone')
     ```
   * Enforce blocked user exclusions directly within the view.

### Phase C: Financial & Billing Security (SEC-04, SEC-05)
1. **Enforce SSV Cryptography**:
   * In `ads_ssv.py`, reject requests for `inmobi`, `meta`, and `unity` unless valid HMAC/signature parameters are verified against configured network secret keys.
   * Fix Google AdMob signature decoding in `verify_admob_ssv` by handling base64url-encoded DER signatures rather than attempting `bytes.fromhex()`.
2. **Secure Webhooks with Signatures & Shared Secrets**:
   * In `billing_webhook.py`, require and validate RevenueCat's Authorization Bearer token header against `REVENUECAT_WEBHOOK_SECRET`.
   * For `/purchase/audit`, verify transaction tokens via Google Play Developer API, Razorpay Webhook Signatures (`hmac_sha256`), or Stripe Webhook Signatures before crediting resources.
   * Handle cancellation events (`CANCELLATION`, `EXPIRATION`) to revert entitlements back to `free`.

### Phase D: Statutory Legal Pipeline Implementation (SEC-06, SEC-08, SEC-09, SEC-16)
1. **Implement Account Incineration (`/api/v1/auth/incinerate-account`)**:
   * Create the `DELETE` endpoint in `backend/app/api/v1/endpoints/auth.py`.
   * The endpoint must delete the user from `public.users`, delete the Firebase Auth / Supabase Auth user record, and trigger a storage cleanup routine that deletes all media blobs from storage buckets.
2. **Implement Data Export & Grievance Endpoints**:
   * Create `/api/v1/vault/export-data` to bundle user data into a password-protected zip file and store a signed, time-limited URL in `public.data_export_requests`.
   * Create `/api/v1/vault/grievance` to insert complaint dossiers directly into `public.grievance_dossiers` and emit notifications to the admin review queue.
   * Create `/api/v1/vault/nominee` to persist nominee details in `public.data_nominees`.
3. **Backend-Enforced Underage Device Quarantine**:
   * When an age under 18 is evaluated, the client must send a hardware-derived device hash to `/api/v1/auth/quarantine-device`, which inserts into `public.underage_quarantine_registry`.
   * On any app launch or registration attempt, the device hash must be validated against `public.underage_quarantine_registry`.
4. **Separate Consent Checkboxes**:
   * Unbundle the Screen 1 checkboxes into three distinct, non-pre-ticked affirmations:
     1. Age confirmation (18+).
     2. Acceptance of Terms of Service & EULA.
     3. DPDP Act 2023 Section 6 specific data processing consent.

### Phase E: Media Pipeline & Storage Isolation (SEC-10)
1. **Enforce Authenticated Storage RLS**:
   * Configure Supabase Storage policies to require valid authenticated user JWTs (`auth.uid() = user_id`) for uploads to `users/{user_id}/*`.
   * Disallow anonymous key uploads with `x-upsert: true` to prevent cross-user file overwrites.

### Phase F: AI Guardrails & Secure Transport (SEC-11, SEC-12, SEC-13, SEC-15)
1. **Prompt Sanitization & Safe Failover**:
   * Wrap user-supplied bio text with explicit delimiters and system instruction enforcement.
   * In `verify_kyc_liveness`, on service failure, route the user to manual human review (`is_live_human = False`, status `"pending_manual_review"`) instead of automatically approving unverified submissions.
2. **Implement Real End-to-End Encryption**:
   * Replace cosmetic fingerprint generator with genuine cryptographic key pairs using `cryptography` / libsodium (X25519 key exchange + ChaCha20-Poly1305 encryption) for messages.
3. **Secure WebSocket & Rate Limiting**:
   * Use `wss://` exclusively and authenticate via short-lived ephemeral tickets rather than passing long-lived tokens in query parameters.
   * Add Redis/memory-backed rate limiting middleware to FastAPI.

---

## 5. AUDIT CONCLUSION & VERIFICATION ROADMAP
The application architecture possesses strong foundational designs (strict DPDP documentation, NullPool database scaling, OpenCV OCR pipelines), but exhibits critical implementation gaps where security enforcement was bypassed or left as client-side simulations.

Following this blueprint in subsequent implementation phases will bring UR-Heart into full statutory alignment with the DPDP Act 2023, IT Rules 2021, and industry-standard DevSecOps zero-trust principles.
