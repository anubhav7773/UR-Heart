import os
import base64
from uuid import uuid4, UUID
from datetime import datetime, date, timezone
from unittest.mock import patch, AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.core.crypto import encrypt_data, decrypt_data, get_encryption_key
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.message import Message
from app.api.dependencies import get_current_user, get_current_user_id

client = TestClient(app)

# ==============================================================================
# TEST 1: AES-256 GCM Cryptographic At-Rest Encryption/Decryption
# ==============================================================================
def test_aes_256_gcm_encryption_roundtrip():
    """
    Verifies AES-256 GCM encryption/decryption helper in app.core.crypto:
    - Encrypts user's phone, WhatsApp number, and ephemeral reveal tokens.
    - Decrypts back to exact plaintext.
    - Ciphertext uses random 12-byte nonce (two encryptions of the same plaintext produce different ciphertexts).
    - Tampered ciphertext fails decryption.
    """
    test_phone = "+919876543210"
    test_wa = "+919876543210"
    test_token = "reveal_tok_xyz_123456789"

    # Encrypt
    c1 = encrypt_data(test_phone)
    c2 = encrypt_data(test_phone)

    assert c1 != test_phone
    # Random nonce produces distinct ciphertexts for identical plaintext
    assert c1 != c2

    # Decrypt
    d1 = decrypt_data(c1)
    d2 = decrypt_data(c2)
    assert d1 == test_phone
    assert d2 == test_phone

    # WA and token encryption
    c_wa = encrypt_data(test_wa)
    c_tok = encrypt_data(test_token)
    assert decrypt_data(c_wa) == test_wa
    assert decrypt_data(c_tok) == test_token

    # Tampering test (modify byte in ciphertext)
    raw = bytearray(base64.b64decode(c1))
    raw[-1] ^= 0xFF  # Flip bit in auth tag
    tampered_b64 = base64.b64encode(raw).decode("utf-8")
    with pytest.raises(Exception):
        decrypt_data(tampered_b64)


# ==============================================================================
# TEST 2: Mass Assignment & Field Tampering Prevention (HTTP 422)
# ==============================================================================
def test_mass_assignment_tampering_rejected_profile_update():
    """
    Attempting to inject privileged fields (is_super_admin, is_banned, etc.)
    in UserProfileUpdateRequest must be blocked by extra='forbid' and return HTTP 422.
    """
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_test_123",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        full_name="Aman Gupta",
        dob=date(1995, 5, 20),
        gender="male",
        city="Lucknow",
        bio="Hello world",
        is_super_admin=False,
        is_banned=False
    )

    app.dependency_overrides[get_current_user] = lambda: mock_user

    # Injected privileged field: is_super_admin
    payload = {
        "full_name": "Aman Hacked",
        "is_super_admin": True
    }
    response = client.patch(
        "/api/v1/users/profile",
        json=payload,
        headers={"Authorization": "Bearer mock_token"}
    )
    assert response.status_code == 422
    err = response.json()
    assert any("extra_forbidden" in str(e) or "is_super_admin" in str(e) for e in err.get("detail", []))

    # Injected privileged field: is_banned
    payload_banned = {
        "bio": "New bio",
        "is_banned": False,
        "reward_balance": 999999
    }
    response_banned = client.patch(
        "/api/v1/users/profile",
        json=payload_banned,
        headers={"Authorization": "Bearer mock_token"}
    )
    assert response_banned.status_code == 422

    app.dependency_overrides.clear()


def test_mass_assignment_tampering_rejected_session_sync():
    """
    Attempting to inject privileged fields in SessionSyncRequest must return HTTP 422.
    """
    payload = {
        "phone_number": "+919876543210",
        "whatsapp_number": "+919876543210",
        "full_name": "Hacker User",
        "dob": "1998-01-01",
        "gender": "male",
        "city": "Delhi",
        "is_super_admin": True  # Injected field
    }
    response = client.post(
        "/api/v1/auth/session-sync",
        json=payload,
        headers={
            "Authorization": "Bearer mock_token",
            "X-Installation-UUID": str(uuid4())
        }
    )
    assert response.status_code == 422
    err = response.json()
    assert any("extra_forbidden" in str(e) or "is_super_admin" in str(e) for e in err.get("detail", []))


# ==============================================================================
# TEST 3: IDOR Prevention — Match & Message Access (HTTP 403)
# ==============================================================================
def test_idor_chat_history_forbidden_for_non_participant():
    """
    User A attempts to read User B's match and messages.
    Backend verifies ownership query:
    WHERE match_id = :match_id AND (user1_id = :current_user_id OR user2_id = :current_user_id)
    Raises HTTP 403 Forbidden because User A is not an active participant.
    """
    attacker_id = uuid4()
    victim_user_1 = uuid4()
    victim_user_2 = uuid4()
    match_id = uuid4()

    mock_match = Match(
        id=match_id,
        user1_id=victim_user_1,
        user2_id=victim_user_2,
        is_active=True
    )

    # Mock DB query returning None because attacker_id is neither user1 nor user2
    mock_session = AsyncMock()
    mock_res = AsyncMock()
    mock_res.scalar_one_or_none = lambda: None  # No row matches the ownership condition
    mock_session.execute = AsyncMock(return_value=mock_res)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user_id] = lambda: attacker_id

    response = client.get(
        f"/api/v1/chat/history/{match_id}",
        headers={"Authorization": "Bearer mock_token"}
    )
    assert response.status_code == 403
    assert "Not a participant" in response.json()["detail"]

    app.dependency_overrides.clear()


# ==============================================================================
# TEST 4: Authorized Profile Update with Parameterized Query
# ==============================================================================
def test_authorized_profile_update():
    """
    Legitimate profile update with valid allowed fields executes successfully.
    """
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        firebase_uid="fb_legit_user",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        full_name="Original Name",
        dob=date(1995, 5, 20),
        gender="male",
        city="Lucknow",
        bio="Original bio",
        is_super_admin=False,
        is_banned=False
    )
    updated_user = User(
        id=user_id,
        firebase_uid="fb_legit_user",
        phone_number="+919876543210",
        whatsapp_number="+919876543210",
        full_name="Updated Name",
        dob=date(1995, 5, 20),
        gender="male",
        city="Varanasi",
        bio="Updated bio",
        streak_count=0,
        reward_balance=0,
        kyc_status=False,
        is_super_admin=False,
        is_banned=False
    )

    mock_session = AsyncMock()
    mock_res = AsyncMock()
    mock_res.scalar_one = lambda: updated_user
    mock_session.execute = AsyncMock(return_value=mock_res)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = lambda: mock_user

    payload = {
        "full_name": "Updated Name",
        "city": "Varanasi",
        "bio": "Updated bio"
    }

    response = client.patch(
        "/api/v1/users/profile",
        json=payload,
        headers={"Authorization": "Bearer mock_token"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["full_name"] == "Updated Name"
    assert data["city"] == "Varanasi"
    assert data["bio"] == "Updated bio"

    app.dependency_overrides.clear()
