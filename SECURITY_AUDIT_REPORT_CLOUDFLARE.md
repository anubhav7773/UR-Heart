# Official Cloudflare Security Audit Report: UR-Heart Ecosystem

> **Audit Framework**: [Cloudflare Security Audit Skill](https://github.com/cloudflare/security-audit-skill)  
> **Repository**: `UR-Heart` (`c:\Project\UR-Heart`)  
> **Source Commit**: `f166f4dc14bc0ed41333c8f8bbc469ae13824484`  
> **Audit Run ID**: `run-1` | **Profile**: `standard` | **Mode**: Full Audit Mode  
> **Status**: **COMPLETE & VERIFIED** (12 Schema Units, 0 Validation Errors)

---

## Executive Summary & Threat Model Scorecard

The Cloudflare Security Audit Skill conducted a comprehensive, source-grounded vulnerability assessment across the full UR-Heart stack:
- **FastAPI Backend Core** (`backend/app/api/`, `backend/app/core/`, `backend/app/services/`)
- **Supabase PostgreSQL Models & Schemas** (`backend/app/models/`, `supabase/`)
- **Flutter Mobile & Web Client** (`lib/features/`, `android/`)
- **Eva AI Orchestration & Cryptographic Vaults** (`SanctuaryCryptoVault`, `AiOrchestrator`)

### Core Findings Breakdown
- **Total Ledger Units**: 12
- **Confirmed Vulnerabilities**: 10 (3 Critical, 1 High, 4 Medium, 2 Low)
- **External Hypotheses Needing Validation**: 1 (Reverse Proxy Edge TLS/HSTS)
- **Refuted Claims**: 1 (IDOR in Chat API refuted by participant validation check)
- **Validator Pass Rate**: **100%** on both `validate-coverage-ledger.cjs` and `validate-findings.cjs`

---

## Confirmed Vulnerabilities Matrix

| ID | Severity | Boundary | Vulnerability Title | Impact / Consequence |
| :--- | :--- | :--- | :--- | :--- |
| **URH-AUTH-BACKDOOR-001** | **CRITICAL** | Authentication Gate | Hardcoded Test Credentials Superadmin Backdoor | Unauthenticated attacker authenticates as `asiverticals@gmail.com` using test passwords in production |
| **URH-AUTH-VERIFY-002** | **CRITICAL** | Session Gate | Insecure Magic Link Verification Polling | Intercepts full JWT session tokens using solely target email address with zero proof of possession |
| **URH-AUTH-GOOGLESYNC-003** | **CRITICAL** | Identity Binding | Unauthenticated Google Sync Account Hijacking | Arbitrary user account hijacked by overwriting database `auth_id` with attacker UID without Google token check |
| **URH-CRYPTO-PLAINTEXT-004** | **HIGH** | Sacred Bridge Enclave | Cleartext Storage of Contact Handles at Rest | WhatsApp handles and phone numbers saved in plaintext in `contact_bridge_encrypted` column |
| **URH-CRYPTO-FALLBACK-005** | **MEDIUM** | E2EE Enclave | Hardcoded Fallback Key for Storage Encryption | Message storage falls back to static key `"urheart_default_super_secret_sanctuary_2026"` if env unset |
| **URH-STORE-REPLAY-006** | **MEDIUM** | Store Entitlements | In-Memory UTR Replay Race Condition | RAM-only replay cache allows duplicate UTR claims across workers or post-restart |
| **URH-ADMIN-TIMING-007** | **MEDIUM** | Sovereign Access Gate | Timing Side-Channel in Admin Secret Check | Non-constant-time comparison leaks admin master key prefix / length variations |
| **URH-PASS-EXPLOIT-008** | **MEDIUM** | Monetization & Passes | Unlimited Blind Date Passes via Rewarded Route | `POST /claim-ad-pass` credits passes without requiring AdMob SSV verification |
| **URH-CORS-HTTP-009** | **LOW** | Network Perimeter | Permissive CORS Regex Allows Cleartext HTTP | `allow_origin_regex` permits `http://` production domains with `allow_credentials=True` |
| **URH-CLIENT-CACHE-010** | **LOW** | Client Storage | Unencrypted Flutter SharedPreferences Cache | Entire user profile JSON (name, DOB, bio) cached in cleartext on device storage |

---

## Detailed Vulnerability Analysis & Minimal Source Fixes

### 1. [CRITICAL] URH-AUTH-BACKDOOR-001: Superadmin Test Credential Backdoor
- **Location**: [`backend/app/api/v1/endpoints/auth.py:267-270`](file:///c:/Project/UR-Heart/backend/app/api/v1/endpoints/auth.py#L267-L270)
- **Defect**:
  ```python
  if getattr(settings, "ENVIRONMENT", "").lower() != "production" or "example.com" in clean_email or "test" in clean_email or clean_email == "asiverticals@gmail.com":
      is_authenticated = True
  ```
  The condition `or clean_email == "asiverticals@gmail.com"` evaluates to `True` regardless of the `ENVIRONMENT` setting. An attacker providing `"dev_test_password_2026"` immediately receives a superadmin token.
- **Immediate Fix**:
  ```python
  if not is_authenticated and getattr(settings, "ENVIRONMENT", "").lower() in ("development", "test", "testing"):
      if provided_password in ("dev_test_password_2026", "SanctuaryDevPassword#2026"):
          if "example.com" in clean_email or "test" in clean_email:
              is_authenticated = True
  ```

---

### 2. [CRITICAL] URH-AUTH-VERIFY-002: Insecure Magic Link Verification Polling
- **Location**: [`backend/app/api/v1/endpoints/auth.py:470-605`](file:///c:/Project/UR-Heart/backend/app/api/v1/endpoints/auth.py#L470-L605)
- **Defect**: The endpoint `GET /api/v1/auth/verification-status?email={email}` checks if the email is confirmed in Supabase or Firebase, and if confirmed, mints a new JWT access token and returns it in the HTTP response body without requiring any secret challenge or polling nonce.
- **Immediate Fix**: Require an unguessable `poll_token` issued only to the client that requested the magic link.

---

### 3. [CRITICAL] URH-AUTH-GOOGLESYNC-003: Unauthenticated Google Sync Account Hijacking
- **Location**: [`backend/app/api/v1/endpoints/auth.py:114-150`](file:///c:/Project/UR-Heart/backend/app/api/v1/endpoints/auth.py#L114-L150)
- **Defect**: The endpoint `POST /api/v1/auth/google-sync` overwrites `user_row.auth_id` with `payload.user_id` without cryptographically verifying `payload.id_token` against Google public certificates. An attacker can rebind any account to their own Firebase UID and subsequently log in as that user.
- **Immediate Fix**: Verify Google ID tokens with Google OAuth public keys before modifying any database records.

---

### 4. [HIGH] URH-CRYPTO-PLAINTEXT-004: Cleartext Contact Handle Storage at Rest
- **Location**: [`backend/app/api/v1/endpoints/profile.py:324, 530`](file:///c:/Project/UR-Heart/backend/app/api/v1/endpoints/profile.py#L324) & [`backend/app/models/domain/user.py:34`](file:///c:/Project/UR-Heart/backend/app/models/domain/user.py#L34)
- **Defect**: Seeker telephone numbers and WhatsApp handles are saved directly as cleartext into `users.contact_bridge_encrypted`, violating TB-4 and DPDP Act 2023 requirements.
- **Immediate Fix**: Use AES-256-GCM authenticated encryption before persisting handles to PostgreSQL.

---

## Architectural Strengths Verified Clean
- **Match Dialogue Isolation**: [`backend/app/api/v1/endpoints/chat_api.py:370`](file:///c:/Project/UR-Heart/backend/app/api/v1/endpoints/chat_api.py#L370) strictly validates match participants; non-participants receive HTTP 403 Forbidden.
- **Bilateral Consent Enforcement**: Sacred contact reveal cannot be triggered unilaterally.
- **Eva AI Input Sanitization**: Prompt inputs are hard-capped at 300 characters, rate limited, and chain-of-thought tokens are purged.

---

## Official Skill Artifact Locations
All standardized Cloudflare Security Audit artifacts are generated, schema-validated, and available in:
- `.audit_output/run-1/coverage-ledger.json` (Validated with `validate-coverage-ledger.cjs`)
- `.audit_output/run-1/findings.json` (Validated with `validate-findings.cjs`)
- `.audit_output/run-1/architecture.md` (Trust boundary & principal model)
- `.audit_output/run-1/REPORT.md` (Executive report)
- `.audit_output/run-1/FINDINGS-DETAIL.md` (Technical proof of defects & patches)
- `.audit_output/run-1/NEEDS-VALIDATION.md` (External deployment validation items)
- `.audit_output/run-1/run-metadata.json` (Audit metadata)
