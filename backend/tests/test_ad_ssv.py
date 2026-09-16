import base64
import urllib.parse
from uuid import uuid4, UUID
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock

import pytest
from fastapi.testclient import TestClient
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from sqlalchemy.exc import IntegrityError

from app.main import app
from app.core.database import get_db
from app.api.v1.endpoints import ad_verification
from app.models.domain.user import User
from app.models.domain.match import Match
from app.models.domain.whatsapp_token import WhatsAppRevealToken

client = TestClient(app)

# Generate a test EC key pair for AdMob SSV verification
TEST_PRIVATE_KEY = ec.generate_private_key(ec.SECP256R1())
TEST_PUBLIC_KEY = TEST_PRIVATE_KEY.public_key()
TEST_PUBLIC_PEM = TEST_PUBLIC_KEY.public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo
).decode("utf-8")
TEST_KEY_ID = "test-key-id-12345"

def generate_signed_params(base_params: list, key_id: str = TEST_KEY_ID) -> tuple[str, str]:
    """
    Computes canonical query string and returns (signature_hex, full_query_string).
    base_params: list of (key, value) pairs excluding signature and key_id.
    """
    canonical_query = urllib.parse.urlencode(base_params)
    signature_bytes = TEST_PRIVATE_KEY.sign(
        canonical_query.encode("utf-8"),
        ec.ECDSA(hashes.SHA256())
    )
    signature_hex = signature_bytes.hex()
    full_params = list(base_params) + [
        ("key_id", key_id),
        ("signature", signature_hex)
    ]
    return signature_hex, urllib.parse.urlencode(full_params)

# ==============================================================================
# TEST SUITE 1: Valid Signature Reward Crediting
# ==============================================================================
def test_valid_signature_reward_crediting():
    """
    Valid signature signed with ECDSA SECP256R1.
    Ad type: direct_dm_reward.
    Asserts reward_balance is incremented and transaction is committed.
    """
    user_id = str(uuid4())
    tx_id = f"tx_valid_{uuid4().hex[:8]}"
    custom_data = f"{user_id}:direct_dm_reward:none"

    base_params = [
        ("network", "admob"),
        ("transaction_id", tx_id),
        ("custom_data", custom_data),
    ]
    _, query_string = generate_signed_params(base_params)

    from unittest.mock import MagicMock
    # Mock DB session
    mock_session = AsyncMock()
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock(return_value=None)
    mock_session.execute = AsyncMock(return_value=None)
    mock_session.commit = AsyncMock(return_value=None)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    with patch.object(ad_verification, "KEY_CACHE", {TEST_KEY_ID: TEST_PUBLIC_PEM}):
        response = client.get(f"/api/v1/ads/verify-reward?{query_string}")

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["status"] == "success"
    assert data["reward"] == "3_direct_dms_granted"
    assert mock_session.commit.called
    assert mock_session.add.called

# ==============================================================================
# TEST SUITE 2: Replay Attack Resistance (Idempotency)
# ==============================================================================
def test_replay_attack_resistance():
    """
    Submitting an identical transaction_id twice causes IntegrityError on db.flush().
    Endpoint returns status 'duplicate_ignored' without double crediting.
    """
    user_id = str(uuid4())
    tx_id = f"tx_replay_{uuid4().hex[:8]}"
    custom_data = f"{user_id}:direct_dm_reward:none"

    base_params = [
        ("network", "admob"),
        ("transaction_id", tx_id),
        ("custom_data", custom_data),
    ]
    _, query_string = generate_signed_params(base_params)

    from unittest.mock import MagicMock
    # Mock DB session that raises IntegrityError on flush simulating unique constraint violation
    mock_session = AsyncMock()
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock(side_effect=IntegrityError("duplicate key", params=None, orig=Exception()))
    mock_session.rollback = AsyncMock(return_value=None)
    mock_session.commit = AsyncMock(return_value=None)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    with patch.object(ad_verification, "KEY_CACHE", {TEST_KEY_ID: TEST_PUBLIC_PEM}):
        response = client.get(f"/api/v1/ads/verify-reward?{query_string}")

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["status"] == "duplicate_ignored"
    assert data["transaction_id"] == tx_id
    assert mock_session.rollback.called
    assert not mock_session.commit.called

# ==============================================================================
# TEST SUITE 3: WhatsApp Dual Progression & 6-Ad Unlock Test
# ==============================================================================
@pytest.mark.asyncio
async def test_whatsapp_dual_progression_and_unlock():
    """
    Tests mutual 6-ad state machine in whatsapp_service:
    - User1 watches 3 ads (0/3 -> 3/3, User2 is 0/3) => is_unlocked = False
    - User2 watches 2 ads (User2 is 2/3) => is_unlocked = False
    - User2 watches 3rd ad (User2 is 3/3) => is_unlocked = True, token generated with 24h expiration
    """
    from app.services.whatsapp_service import process_whatsapp_ad_completion

    user1_id = uuid4()
    user2_id = uuid4()
    match_id = uuid4()

    mock_match = Match(
        id=match_id,
        user1_id=user1_id,
        user2_id=user2_id,
        is_active=True
    )
    mock_token = WhatsAppRevealToken(
        id=uuid4(),
        match_id=match_id,
        user1_consent=True,
        user2_consent=True,
        user1_ads_count=0,
        user2_ads_count=0,
        is_unlocked=False
    )

    mock_db = AsyncMock()
    mock_result = AsyncMock()
    mock_result.first = lambda: (mock_token, mock_match)
    mock_db.execute.return_value = mock_result

    # 1. User 1 watches 3 ads
    for i in range(1, 4):
        await process_whatsapp_ad_completion(user1_id, match_id, mock_db)
        assert mock_token.user1_ads_count == i
        assert mock_token.user2_ads_count == 0
        assert mock_token.is_unlocked is False

    # 2. User 2 watches 2 ads
    for j in range(1, 3):
        await process_whatsapp_ad_completion(user2_id, match_id, mock_db)
        assert mock_token.user1_ads_count == 3
        assert mock_token.user2_ads_count == j
        assert mock_token.is_unlocked is False

    # 3. User 2 watches 3rd ad -> Triggers unlock
    await process_whatsapp_ad_completion(user2_id, match_id, mock_db)
    assert mock_token.user1_ads_count == 3
    assert mock_token.user2_ads_count == 3
    assert mock_token.is_unlocked is True
    assert mock_token.ephemeral_token is not None
    assert len(mock_token.ephemeral_token) >= 32
    assert mock_token.expires_at is not None

    # Expiration is ~24 hours in the future
    time_diff = mock_token.expires_at - datetime.now(timezone.utc)
    assert 23 * 3600 < time_diff.total_seconds() <= 24 * 3600 + 5

# ==============================================================================
# TEST SUITE 4: Tampered Signature Rejection
# ==============================================================================
def test_tampered_signature_rejection():
    """
    Alters query parameter value while retaining original signature.
    Asserts endpoint returns HTTP 400 Bad Request.
    """
    user_id = str(uuid4())
    tx_id = f"tx_tampered_{uuid4().hex[:8]}"
    custom_data = f"{user_id}:direct_dm_reward:none"

    base_params = [
        ("network", "admob"),
        ("transaction_id", tx_id),
        ("custom_data", custom_data),
    ]
    signature_hex, _ = generate_signed_params(base_params)

    # Tamper with custom_data
    tampered_params = [
        ("network", "admob"),
        ("transaction_id", tx_id),
        ("custom_data", f"{user_id}:direct_dm_reward:tampered_target"),
        ("key_id", TEST_KEY_ID),
        ("signature", signature_hex)
    ]
    tampered_query = urllib.parse.urlencode(tampered_params)

    with patch.object(ad_verification, "KEY_CACHE", {TEST_KEY_ID: TEST_PUBLIC_PEM}):
        response = client.get(f"/api/v1/ads/verify-reward?{tampered_query}")

    assert response.status_code == 400
    assert "Cryptographic verification failed" in response.json()["detail"]
