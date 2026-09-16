import os
from uuid import uuid4
from datetime import date, datetime
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.core.sanitizer import sanitize_user_html, strip_null_bytes
from app.services.storage_service import validate_photo_file, validate_kyc_video_file
from app.models.domain.user import User
from app.models.schemas.user import (
    UserProfileUpdateRequest,
    UserProfileResponse,
    UserDiscoveryProfileResponse
)
from app.api.dependencies import get_current_user

client = TestClient(app)

# ==============================================================================
# TEST 1: Restricted File Uploads & Magic Bytes Inspection (Check 16)
# ==============================================================================
def test_upload_executable_extension_rejected():
    """
    Uploading an executable file (.exe, .sh, .php) must be rejected with HTTP 422.
    """
    # 1. Via endpoint
    fake_exe_bytes = b"MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00"
    files = {"file": ("malicious.exe", fake_exe_bytes, "application/x-msdownload")}
    response = client.post("/api/v1/moderation/scan-photo", files=files)
    # Either 400 (unsupported mime type) or 422 (disallowed extension)
    assert response.status_code in (400, 422)

    # 2. Direct service validator
    with pytest.raises(Exception) as exc_exe:
        validate_photo_file(fake_exe_bytes, filename="trojan.exe")
    assert exc_exe.value.status_code == 422
    assert "Disallowed executable" in exc_exe.value.detail

    with pytest.raises(Exception) as exc_sh:
        validate_kyc_video_file(b"#!/bin/bash\nrm -rf /", filename="hack.sh")
    assert exc_sh.value.status_code == 422


def test_upload_oversized_photo_rejected_413():
    """
    Uploading a photo > 150 KB (e.g. 2 MB) must trigger HTTP 413 Payload Too Large.
    """
    oversized_bytes = b"\xff\xd8\xff" + (b"\x00" * (2 * 1024 * 1024))  # 2MB with JPEG header
    with pytest.raises(Exception) as exc:
        validate_photo_file(oversized_bytes, filename="large_profile.jpg")
    assert exc.value.status_code == 413
    assert "exceeds 150 KB" in exc.value.detail


def test_upload_invalid_magic_bytes_rejected():
    """
    Uploading a file with fake .jpg extension but missing valid JPEG/PNG/WebP magic bytes
    must be rejected with HTTP 422.
    """
    fake_jpg = b"This is plain text and not a real jpeg binary file."
    with pytest.raises(Exception) as exc:
        validate_photo_file(fake_jpg, filename="fake.jpg")
    assert exc.value.status_code == 422
    assert "Magic bytes do not match" in exc.value.detail


def test_upload_oversized_kyc_video_rejected_413():
    """
    Uploading a KYC video > 2.5 MB must trigger HTTP 413 Payload Too Large.
    """
    oversized_video = b"\x00\x00\x00\x18ftypmp42" + (b"\x00" * 3000000)  # 3 MB MP4
    with pytest.raises(Exception) as exc:
        validate_kyc_video_file(oversized_video, filename="video.mp4")
    assert exc.value.status_code == 413
    assert "exceeds 2.5MB" in exc.value.detail


# ==============================================================================
# TEST 2: Strict Input Validation & Null-Byte Injection (Check 14)
# ==============================================================================
def test_input_validation_name_and_phone():
    """
    Validates regex patterns:
    - full_name must only contain letters and spaces (2-50 chars).
    - phone_number must match +91[6-9]d{9}.
    """
    # Name with numbers / symbols fails
    with pytest.raises(Exception):
        UserProfileUpdateRequest(full_name="Aman123")

    with pytest.raises(Exception):
        UserProfileUpdateRequest(full_name="<script>")

    # Phone not matching E.164 Indian format fails
    with pytest.raises(Exception):
        UserProfileUpdateRequest(whatsapp_number="9876543210")  # Missing +91

    with pytest.raises(Exception):
        UserProfileUpdateRequest(whatsapp_number="+911234567890")  # Invalid starting digit 1


def test_null_byte_injection_rejected():
    """
    Submitting strings containing null-byte injections (\0) must trigger validation error.
    """
    with pytest.raises(Exception) as exc:
        UserProfileUpdateRequest(bio="Legitimate text\0malicious_payload")
    assert "Null-byte injection" in str(exc.value)


# ==============================================================================
# TEST 3: XSS Sanitization & HTML Escaping (Check 15)
# ==============================================================================
def test_xss_sanitization_escapes_script_tags():
    """
    Injected <script>alert(1)</script> in user bio must be escaped to
    &lt;script&gt;alert(1)&lt;/script&gt;.
    """
    payload = UserProfileUpdateRequest(bio="<script>alert(1)</script>")
    assert payload.bio == "&lt;script&gt;alert(1)&lt;/script&gt;"

    # Verify helper directly
    raw_xss = "<img src=x onerror=alert('hacked')>"
    escaped = sanitize_user_html(raw_xss)
    assert escaped == "&lt;img src=x onerror=alert(&#x27;hacked&#x27;)&gt;"


# ==============================================================================
# TEST 4: Trimmed API Responses & Data Minimization (Check 17)
# ==============================================================================
def test_user_profile_response_data_minimization():
    """
    Asserts UserProfileResponse and UserDiscoveryProfileResponse strip all sensitive
    system and admin flags: firebase_uid, is_super_admin, is_banned, deleted_at, last_installation_uuid.
    """
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_secret_uid_12345",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        full_name="Aman Gupta",
        dob=date(1996, 5, 20),
        gender="male",
        city="Lucknow",
        bio="Software Engineer",
        streak_count=12,
        reward_balance=500,
        kyc_status=True,
        is_super_admin=True,  # SENSITIVE
        is_banned=False,      # SENSITIVE
        last_installation_uuid="secret-install-uuid", # SENSITIVE
        kyc_document_sha256="secret_hash",            # SENSITIVE
        created_at=datetime.utcnow()
    )

    app.dependency_overrides[get_current_user] = lambda: mock_user

    response = client.get(
        "/api/v1/users/profile",
        headers={"Authorization": "Bearer mock_token"}
    )
    assert response.status_code == 200
    data = response.json()

    # Verify zero sensitive/admin fields exist in payload
    forbidden_keys = [
        "is_super_admin",
        "is_banned",
        "firebase_uid",
        "last_installation_uuid",
        "kyc_document_sha256",
        "deleted_at"
    ]
    for k in forbidden_keys:
        assert k not in data, f"Sensitive internal field '{k}' leaked in profile response!"

    app.dependency_overrides.clear()


# ==============================================================================
# TEST 5: OWASP Security Headers Injection (Check 18)
# ==============================================================================
def test_owasp_security_headers_present_on_all_responses():
    """
    Verifies that all 7 required OWASP security headers are injected into HTTP responses:
    - X-Content-Type-Options: nosniff
    - X-Frame-Options: DENY
    - X-XSS-Protection: 1; mode=block
    - Strict-Transport-Security: max-age=31536000; includeSubDomains
    - Referrer-Policy: strict-origin-when-cross-origin
    - Content-Security-Policy: default-src 'self'; frame-ancestors 'none';
    - Permissions-Policy: geolocation=(), camera=(), microphone=()
    """
    response = client.get("/api/v1/health")
    assert response.status_code == 200

    headers = response.headers

    assert headers.get("X-Content-Type-Options") == "nosniff"
    assert headers.get("X-Frame-Options") == "DENY"
    assert headers.get("X-XSS-Protection") == "1; mode=block"
    assert "max-age=31536000" in headers.get("Strict-Transport-Security", "")
    assert headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"
    assert "frame-ancestors 'none'" in headers.get("Content-Security-Policy", "")
    assert "geolocation=()" in headers.get("Permissions-Policy", "")
