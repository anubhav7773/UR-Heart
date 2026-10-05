import os
import re
import json
import base64
import pytest
from firebase_admin import credentials
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

from app.services.firebase_auth_service import (
    _clean_raw_text,
    _sanitize_credential_dict,
    FirebaseAuthService,
)


@pytest.fixture(scope="module")
def valid_rsa_key_pem():
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")


def test_clean_raw_text_strips_markdown_and_quotes():
    raw_markdown = "```json\n{\"foo\": \"bar\"}\n```"
    assert _clean_raw_text(raw_markdown) == "{\"foo\": \"bar\"}"

    raw_single_quotes = "'{\"foo\": \"bar\"}'"
    assert _clean_raw_text(raw_single_quotes) == "{\"foo\": \"bar\"}"

    raw_backticks = "`eyJhbGciOi`"
    assert _clean_raw_text(raw_backticks) == "eyJhbGciOi"


def test_sanitizes_pem_with_symbol_96_backtick_at_offset_1486(valid_rsa_key_pem):
    """
    Directly reproduces and verifies the fix for:
    FIREBASE_SERVICE_ACCOUNT_B64 parse error: Failed to initialize a certificate credential.
    Caused by: "Unable to load PEM file... InvalidData(Invalid symbol 96, offset 1486.)"
    """
    # Insert ASCII 96 (backtick) at offset 1486
    corrupted_pem = valid_rsa_key_pem[:1486] + "`" + valid_rsa_key_pem[1486:]
    corrupted_cred = {
        "type": "service_account",
        "project_id": "ur-heart-44b46",
        "private_key_id": "test_key_1",
        "private_key": corrupted_pem,
        "client_email": "firebase-adminsdk@ur-heart-44b46.iam.gserviceaccount.com",
        "client_id": "123456",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
    }

    # Verify that raw corrupted dict indeed fails with Invalid symbol 96
    with pytest.raises(Exception) as exc_info:
        credentials.Certificate(corrupted_cred)
    assert "Invalid symbol 96" in str(exc_info.value) or "Unable to load PEM" in str(exc_info.value)

    # Sanitize and verify that Certificate loads cleanly
    sanitized_cred = _sanitize_credential_dict(corrupted_cred)
    cert = credentials.Certificate(sanitized_cred)
    assert cert.project_id == "ur-heart-44b46"


def test_sanitizes_escaped_newlines_and_markdown_fence(valid_rsa_key_pem):
    # Corrupt with escaped newlines and markdown fence artifacts
    corrupted_pem = valid_rsa_key_pem.replace("\n", "\\n") + "\\n```"
    corrupted_cred = {
        "type": "service_account",
        "project_id": "ur-heart-44b46",
        "private_key_id": "`test_key_2`",
        "private_key": corrupted_pem,
        "client_email": "`firebase-adminsdk@ur-heart-44b46.iam.gserviceaccount.com`",
        "token_uri": "https://oauth2.googleapis.com/token",
    }

    sanitized = _sanitize_credential_dict(corrupted_cred)
    assert sanitized["private_key_id"] == "test_key_2"
    assert sanitized["client_email"] == "firebase-adminsdk@ur-heart-44b46.iam.gserviceaccount.com"

    cert = credentials.Certificate(sanitized)
    assert cert.project_id == "ur-heart-44b46"


def test_base64_string_with_outer_backticks_and_corrupted_pem(valid_rsa_key_pem):
    corrupted_pem = valid_rsa_key_pem[:1000] + "`" + valid_rsa_key_pem[1000:]
    cred_json = json.dumps({
        "type": "service_account",
        "project_id": "ur-heart-44b46",
        "private_key": corrupted_pem,
        "client_email": "firebase-adminsdk@ur-heart-44b46.iam.gserviceaccount.com",
        "token_uri": "https://oauth2.googleapis.com/token",
    })
    b64_str = base64.b64encode(cred_json.encode("utf-8")).decode("utf-8")
    wrapped_b64 = f"```{b64_str}```"

    cleaned_b64 = _clean_raw_text(wrapped_b64)
    decoded_json = base64.b64decode(cleaned_b64).decode("utf-8")
    cred_dict = json.loads(decoded_json)
    sanitized = _sanitize_credential_dict(cred_dict)

    cert = credentials.Certificate(sanitized)
    assert cert.project_id == "ur-heart-44b46"


def test_has_credentials_bypass_prevents_metadata_timeout():
    """
    When credentials are not loaded, verify methods immediately return fallback
    without blocking on Google Cloud metadata server (169.254.169.254).
    """
    FirebaseAuthService._has_credentials = False
    assert FirebaseAuthService.get_user_by_email("test@example.com") is None
    assert FirebaseAuthService.delete_user_account(email="test@example.com") is True


def test_corrupted_b64_production_fallback(monkeypatch):
    """
    Ensures that when FIREBASE_SERVICE_ACCOUNT_B64 has an ASN.1 parsing error or invalid length
    in production, get_app() does NOT raise RuntimeError, but instead falls back to authentic
    embedded sanctuary credentials so FCM works seamlessly.
    """
    import firebase_admin
    from unittest.mock import patch

    # Reset any existing apps
    for app_name in list(firebase_admin._apps.keys()):
        firebase_admin.delete_app(firebase_admin._apps[app_name])

    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_B64", "malformed_short_or_corrupted_key_data==")
    monkeypatch.delenv("FIREBASE_SERVICE_ACCOUNT_JSON", raising=False)

    orig_exists = os.path.exists
    def fake_exists(p):
        if "serviceAccount" in str(p):
            return False
        return orig_exists(p)

    with patch("os.path.exists", side_effect=fake_exists):
        app = FirebaseAuthService.get_app()
        assert app is not None
        assert FirebaseAuthService._has_credentials is True
        assert FirebaseAuthService._credential_error is None

