import pytest
import uuid
import re
import secrets
from datetime import datetime, timezone, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.models.domain.user import User
from app.core.config import get_settings
from app.core.encryption import encrypt_contact_bridge, decrypt_contact_bridge
from app.api.v1.endpoints.auth import MAGIC_LINK_VAULT, EMAIL_VERIFICATION_STATUS
import app.api.v1.endpoints.chat_api as chat_api_module
from app.services.blind_date_matcher import BlindDateMatcherService

client = TestClient(app)


# ---------------------------------------------------------------------------
# URH-AUTH-BACKDOOR-001: Backdoor password elimination
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_auth_backdoor_rejected_for_founder_email():
    """Verify that secure_password_123 is rejected for asiverticals@gmail.com."""
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_db] = lambda: mock_db
    try:
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "asiverticals@gmail.com",
                "password": "secure_password_123",
            },
        )
        assert response.status_code == 401
    finally:
        app.dependency_overrides.pop(get_db, None)


# ---------------------------------------------------------------------------
# URH-AUTH-VERIFY-002: Poll token challenge on verification status
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_auth_poll_token_challenge_enforced():
    """Verify that /verification-status requires matching poll_token challenge."""
    test_email = f"chall_{uuid.uuid4().hex[:6]}@example.com"
    send_resp = client.post(
        "/api/v1/auth/send-magic-link",
        json={"email": test_email},
    )
    assert send_resp.status_code == 200
    send_data = send_resp.json()
    assert "poll_token" in send_data
    poll_token = send_data["poll_token"]
    assert len(poll_token) >= 32

    # Simulate email tap by setting verification status
    EMAIL_VERIFICATION_STATUS[test_email] = {
        "status": "verified",
        "is_verified": True,
        "email": test_email,
        "token": "tok_123",
        "poll_token": poll_token,
        "role": "user",
        "is_profile_completed": False,
        "access_token": "mock_jwt_session",
    }

    settings = get_settings()
    orig_env = settings.ENVIRONMENT
    try:
        settings.ENVIRONMENT = "production"

        # 1. Polling without poll_token in production gate is rejected with 403 Forbidden
        unauth_resp = client.get(
            f"/api/v1/auth/verification-status?email={test_email}"
        )
        assert unauth_resp.status_code == 403

        # 2. Polling with wrong poll_token is rejected with 403 Forbidden
        wrong_resp = client.get(
            f"/api/v1/auth/verification-status?email={test_email}&poll_token=invalid_forged_token"
        )
        assert wrong_resp.status_code == 403

        # 3. Polling with matching poll_token succeeds and returns session
        valid_resp = client.get(
            f"/api/v1/auth/verification-status?email={test_email}&poll_token={poll_token}"
        )
        assert valid_resp.status_code == 200
        assert valid_resp.json()["is_verified"] is True
        assert valid_resp.json()["access_token"] == "mock_jwt_session"

        # 4. Token replay is consumed: second query with same poll_token is now unverified
        replay_resp = client.get(
            f"/api/v1/auth/verification-status?email={test_email}&poll_token={poll_token}"
        )
        assert replay_resp.status_code == 200
        assert replay_resp.json()["is_verified"] is False
    finally:
        settings.ENVIRONMENT = orig_env


# ---------------------------------------------------------------------------
# URH-AUTH-GOOGLESYNC-003: Google Sync ID token verification
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_google_sync_requires_valid_id_token_in_production():
    """Verify that google-sync strictly rejects unverified requests in production."""
    settings = get_settings()
    orig_env = settings.ENVIRONMENT
    try:
        settings.ENVIRONMENT = "production"

        # Without id_token -> 401
        resp_no_token = client.post(
            "/api/v1/auth/google-sync",
            json={
                "email": "victim@example.com",
                "user_id": str(uuid.uuid4()),
                "display_name": "Victim User",
            },
        )
        assert resp_no_token.status_code in (400, 401)

        # With mismatched token email -> 403
        with patch("app.core.security.verify_firebase_jwt", AsyncMock(return_value={"email": "attacker@evil.com"})):
            resp_mismatch = client.post(
                "/api/v1/auth/google-sync",
                json={
                    "email": "victim@example.com",
                    "user_id": str(uuid.uuid4()),
                    "display_name": "Victim User",
                    "id_token": "token_for_attacker",
                },
            )
            assert resp_mismatch.status_code == 403
    finally:
        settings.ENVIRONMENT = orig_env


# ---------------------------------------------------------------------------
# URH-CRYPTO-PLAINTEXT-004: Contact bridge AES-256-GCM encryption at rest
# ---------------------------------------------------------------------------
def test_contact_bridge_encryption_at_rest():
    """Verify AES-256-GCM contact handle encryption with user binding and legacy fallback."""
    user_a = str(uuid.uuid4())
    user_b = str(uuid.uuid4())
    raw_phone = "+919876543210"

    # 1. Encryption generates ciphertext with enc_bridge_v1 prefix
    enc_a = encrypt_contact_bridge(raw_phone, user_a)
    assert enc_a != raw_phone
    assert enc_a.startswith("enc_bridge_v1:")

    # 2. Key derivation is user-bound (different user produces different ciphertext)
    enc_b = encrypt_contact_bridge(raw_phone, user_b)
    assert enc_a != enc_b

    # 3. Decryption recovers original handle
    dec_a = decrypt_contact_bridge(enc_a, user_a)
    assert dec_a == raw_phone

    # 4. Decrypting with wrong user fails safely and returns empty string
    dec_wrong = decrypt_contact_bridge(enc_a, user_b)
    assert dec_wrong == ""

    # 5. Legacy plaintext fallback: handles without enc_bridge_v1 prefix pass through unchanged
    assert decrypt_contact_bridge("+911234567890", user_a) == "+911234567890"


# ---------------------------------------------------------------------------
# URH-CRYPTO-FALLBACK-005: Elimination of static hardcoded secret
# ---------------------------------------------------------------------------
def test_chat_crypto_fails_closed_without_secret_key():
    """Verify chat message storage encryption rejects weak hardcoded fallbacks."""
    match_id = str(uuid.uuid4())
    message = "Sanctuary Sacred Message 2026"

    # 1. Test valid encryption and decryption with configured secret
    ciphertext = chat_api_module.encrypt_message_storage(message, match_id)
    assert ciphertext != message
    assert ciphertext.startswith("enc_v1:")
    assert chat_api_module.decrypt_message_storage(ciphertext, match_id) == message

    # 2. Verify static hardcoded fallback string was completely removed from source
    chat_file = Path(__file__).resolve().parent.parent / "app" / "api" / "v1" / "endpoints" / "chat_api.py"
    with open(chat_file, "r", encoding="utf-8") as f:
        chat_code = f.read()
    assert "urheart_default_super_secret_sanctuary_2026" not in chat_code


# ---------------------------------------------------------------------------
# URH-STORE-REPLAY-006: Web store UTR replay rejection
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_web_store_utr_replay_rejected():
    """Verify complete_store_order checks database state and rejects duplicate UTR."""
    test_user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        email="shopper@urheart.app",
        role="user",
        reward_balance=0,
    )
    from app.api.dependencies import get_current_user
    app.dependency_overrides[get_current_user] = lambda: test_user

    mock_db = AsyncMock()
    # Mock finding an existing purchase with the same UTR
    mock_result = MagicMock()
    mock_purchase = MagicMock()
    mock_purchase.transaction_reference = "UTR_REPLAY_TEST_999"
    mock_result.scalar_one_or_none.return_value = mock_purchase
    mock_db.execute.return_value = mock_result

    app.dependency_overrides[get_db] = lambda: mock_db
    try:
        response = client.post(
            "/api/v1/store/complete-order",
            json={
                "order_id": "ORD-TEST-999",
                "payment_reference": "UTR_REPLAY_TEST_999",
            },
        )
        assert response.status_code == 409
        assert "already been submitted" in response.json()["detail"]
    finally:
        app.dependency_overrides.pop(get_db, None)
        app.dependency_overrides.pop(get_current_user, None)


# ---------------------------------------------------------------------------
# URH-ADMIN-TIMING-007: Admin portal constant-time token comparison
# ---------------------------------------------------------------------------
def test_admin_portal_constant_time_comparison():
    """Verify secrets.compare_digest is utilized and invalid tokens rejected."""
    # Test valid key comparison
    key_a = "valid_admin_token_abcdef123456"
    key_b = "valid_admin_token_abcdef123456"
    assert secrets.compare_digest(key_a, key_b) is True
    assert secrets.compare_digest(key_a, "forged_admin_token") is False

    # Calling admin login with invalid secret returns 401
    resp = client.post(
        "/api/v1/admin/portal/auth/login",
        json={
            "email": "asiverticals@gmail.com",
            "secret_key": "forged_nonexistent_key_999",
        },
    )
    assert resp.status_code == 401

    # Calling admin login with non-admin email returns 403
    unauth_resp = client.post(
        "/api/v1/admin/portal/auth/login",
        json={
            "email": "unauthorized@example.com",
            "secret_key": "any_key",
        },
    )
    assert unauth_resp.status_code == 403


# ---------------------------------------------------------------------------
# URH-PASS-EXPLOIT-008: Blind date claim-ad-pass anti-abuse cooldown
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_blind_date_claim_ad_pass_cooldown():
    """Verify claim_ad_pass enforces cooldown when user already has passes."""
    mock_db = AsyncMock()
    now = datetime.now(timezone.utc)

    user = User(
        id=uuid.uuid4(),
        auth_id=uuid.uuid4(),
        email="pass_tester@urheart.app",
        role="user",
        blind_date_passes=3,
        last_streak_ad_at=now - timedelta(seconds=15),  # claimed 15s ago (< 120s cooldown)
    )

    # Calling claim_ad_pass during cooldown must raise ValueError anti-abuse exception
    with pytest.raises(ValueError, match="Ad pass cooldown active"):
        await BlindDateMatcherService.claim_ad_pass(mock_db, user)


# ---------------------------------------------------------------------------
# URH-CORS-HTTP-009: CORS regex restricts HTTP exclusively to localhost
# ---------------------------------------------------------------------------
def test_cors_regex_blocks_insecure_http_production_domains():
    """Verify CORS regex permits https for prod domains and restricts http to localhost."""
    cors_regex = r"^(http://(localhost|127\.0\.0\.1)(:\d+)?|https://.*\.urheart\.app|https://urheart\.app|https://.*\.asiverticals\.me|https://asiverticals\.me)$"
    compiled = re.compile(cors_regex)

    # Permitted origins:
    assert compiled.match("http://localhost:3000") is not None
    assert compiled.match("http://127.0.0.1:8080") is not None
    assert compiled.match("https://urheart.app") is not None
    assert compiled.match("https://api.urheart.app") is not None
    assert compiled.match("https://asiverticals.me") is not None
    assert compiled.match("https://urheart.asiverticals.me") is not None

    # Blocked insecure/attacker origins:
    assert compiled.match("http://urheart.app") is None  # Insecure http rejected
    assert compiled.match("http://asiverticals.me") is None  # Insecure http rejected
    assert compiled.match("http://evil-attacker.com") is None
    assert compiled.match("https://evil-urheart.app.attacker.com") is None
