import os
from uuid import uuid4
from datetime import datetime, date, timedelta, timezone
from unittest.mock import patch, AsyncMock, MagicMock

import pytest
from fastapi import Response, HTTPException
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.core.security import (
    hash_password,
    verify_password,
    set_secure_auth_cookie,
    verify_firebase_token,
    pwd_context
)
from app.core.rate_limiter import limiter
from app.core.bot_shield import (
    validate_installation_uuid_header,
    verify_play_integrity_token
)

client = TestClient(app)

# ==============================================================================
# TEST 1: Rate Limiting & Anti-Brute Force Stress Test (HTTP 429)
# ==============================================================================
def test_rate_limiting_session_sync_stress_triggers_429():
    """
    Stress test: Sending 15 rapid requests to /api/v1/auth/session-sync
    exceeds the 10/minute rate limit threshold and triggers HTTP 429 Too Many Requests.
    """
    # Reset limiter storage for clean state
    limiter.reset()

    install_uuid = str(uuid4())
    headers = {
        "Authorization": "Bearer mock_valid_token",
        "X-Installation-UUID": install_uuid
    }
    dob_24 = (date.today() - timedelta(days=24 * 365 + 6)).isoformat()
    payload = {
        "phone_number": "+919876543210",
        "whatsapp_number": "+919876543210",
        "full_name": "Rate Limit Test User",
        "dob": dob_24,
        "gender": "male",
        "city": "Lucknow",
        "bio": "Testing",
        "android_id": "android_rate_limit_1"
    }

    mock_token_payload = {"uid": "fb_rate_limit_test", "email": "test@example.com"}

    mock_session = AsyncMock()
    mock_res = AsyncMock()
    mock_res.scalar_one_or_none = lambda: None
    mock_session.execute = AsyncMock(return_value=mock_res)
    mock_session.commit = AsyncMock()
    mock_session.refresh = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    responses = []
    with patch("app.api.v1.endpoints.auth.verify_firebase_token", return_value=mock_token_payload):
        for _ in range(15):
            res = client.post(
                "/api/v1/auth/session-sync",
                json=payload,
                headers=headers
            )
            responses.append(res)

    app.dependency_overrides.clear()

    # The 10/minute tier permits 10 requests; the 11th through 15th MUST trigger HTTP 429
    status_codes = [r.status_code for r in responses]
    assert 429 in status_codes, f"Expected 429 in status codes, got: {status_codes}"

    # Verify 429 response structure
    rate_limited_resp = next(r for r in responses if r.status_code == 429)
    assert rate_limited_resp.status_code == 429
    data = rate_limited_resp.json()
    assert "Rate limit exceeded" in data.get("detail", "")
    assert rate_limited_resp.headers.get("Retry-After") is not None


# ==============================================================================
# TEST 2: Token Forgery & Cryptographic Authentication Rejection (HTTP 401)
# ==============================================================================
def test_token_forgery_rejection_without_mock():
    """
    Sending a forged or tampered Firebase token directly to an authenticated endpoint
    must be rejected by verify_firebase_token / firebase_admin.auth with HTTP 401 Unauthorized.
    """
    forged_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJoYWNrZXIifQ.tampered_signature"

    # 1. Direct call to verify_firebase_token
    with pytest.raises(HTTPException) as exc_info:
        verify_firebase_token(forged_token)
    assert exc_info.value.status_code == 401
    assert "Invalid, expired or revoked" in exc_info.value.detail or "Firebase" in exc_info.value.detail

    # 2. HTTP request to protected profile endpoint with forged Bearer token
    resp = client.get(
        "/api/v1/users/profile",
        headers={"Authorization": f"Bearer {forged_token}"}
    )
    assert resp.status_code == 401
    assert "Invalid, expired or revoked" in resp.json()["detail"] or "Firebase" in resp.json()["detail"]


# ==============================================================================
# TEST 3: Secure Password Hashing with Argon2id (Check 10)
# ==============================================================================
def test_argon2id_password_hashing():
    """
    Verifies Argon2id configuration:
    - Scheme is argon2id with time_cost=3, memory_cost=65536 KiB (64MB).
    - Hashes verify correctly for valid passwords and fail for invalid passwords.
    """
    raw_password = "SuperStrongPassword#2026"
    hashed = hash_password(raw_password)

    # Verify argon2id signature and parameters
    assert hashed.startswith("$argon2id$")
    assert "m=65536,t=3,p=2" in hashed

    # Verify password verification
    assert verify_password(raw_password, hashed) is True
    assert verify_password("WrongPassword123!", hashed) is False


# ==============================================================================
# TEST 4: Secure Cookie Standards (Check 9)
# ==============================================================================
def test_secure_auth_cookie_attributes():
    """
    Verifies that set_secure_auth_cookie configures:
    - httponly=True (blocks XSS)
    - secure=True (enforces HTTPS/TLS)
    - samesite="strict" (CSRF mitigation)
    - max_age=3600 (1 hour expiration)
    """
    response = Response()
    set_secure_auth_cookie(response, key="urheart_session", value="mock_session_val", max_age=3600)

    cookie_header = response.headers.get("set-cookie", "")
    assert "urheart_session=mock_session_val" in cookie_header
    assert "HttpOnly" in cookie_header or "httponly" in cookie_header.lower()
    assert "Secure" in cookie_header or "secure" in cookie_header.lower()
    assert "SameSite=strict" in cookie_header or "samesite=strict" in cookie_header.lower()
    assert "Max-Age=3600" in cookie_header or "max-age=3600" in cookie_header.lower()


# ==============================================================================
# TEST 5: Bot Shield & Device Quarantine (Check 12)
# ==============================================================================
@pytest.mark.asyncio
async def test_play_integrity_bot_shield():
    """
    Verifies Android Play Integrity token verification hook:
    - Detects rooted devices and emulator bot farms, raising HTTP 403 Forbidden.
    - Legitimate tokens pass with VERIFIED status.
    """
    # Rooted device detection
    with pytest.raises(HTTPException) as exc_rooted:
        await verify_play_integrity_token("ROOTED_DEVICE", environment="production")
    assert exc_rooted.value.status_code == 403
    assert "Rooted device or emulator" in exc_rooted.value.detail

    # Emulator bot detection
    with pytest.raises(HTTPException) as exc_bot:
        await verify_play_integrity_token("EMULATOR_BOT", environment="production")
    assert exc_bot.value.status_code == 403

    # Missing token in production
    with pytest.raises(HTTPException) as exc_missing:
        await verify_play_integrity_token(None, environment="production")
    assert exc_missing.value.status_code == 403

    # Valid token verification
    result = await verify_play_integrity_token("valid_signed_play_integrity_token", environment="production")
    assert result["verdict"] == "VERIFIED"
    assert result["device_recognition"] == "MEETS_STRONG_INTEGRITY"


def test_installation_uuid_validation():
    """
    Validates that validate_installation_uuid_header rejects missing or non-UUID headers.
    """
    # Missing header
    with pytest.raises(HTTPException) as exc_missing:
        validate_installation_uuid_header(None)
    assert exc_missing.value.status_code == 400
    assert "Missing required X-Installation-UUID" in exc_missing.value.detail

    # Malformed non-UUID
    with pytest.raises(HTTPException) as exc_invalid:
        validate_installation_uuid_header("not-a-valid-uuid")
    assert exc_invalid.value.status_code == 400
    assert "Must be a valid UUIDv4" in exc_invalid.value.detail

    # Valid UUID
    valid_id = uuid4()
    assert validate_installation_uuid_header(str(valid_id)) == valid_id
