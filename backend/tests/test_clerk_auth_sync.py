import time
import uuid
from datetime import date, datetime, timezone
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from fastapi import HTTPException
from fastapi.testclient import TestClient
from jose import jwt

from app.core.config import settings
from app.main import app
from app.models.orm import User, UserPhoto, UserAdCounter
from app.models.schemas import ClerkUserClaims
from app.services.clerk_auth import (
    ClerkJWKSVerifier,
    ClerkUserSyncService,
    clerk_verifier,
)


# Generate test RSA Keypair for RS256 JWKS mocking
_test_private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
)
_test_private_pem = _test_private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
).decode("utf-8")

_test_public_key = _test_private_key.public_key()
_test_public_pem = _test_public_key.public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
).decode("utf-8")

_test_public_numbers = _test_public_key.public_numbers()

import base64

def int_to_base64url(val: int) -> str:
    val_bytes = val.to_bytes((val.bit_length() + 7) // 8, byteorder="big")
    return base64.urlsafe_b64encode(val_bytes).decode("utf-8").rstrip("=")

_test_jwk = {
    "kty": "RSA",
    "use": "sig",
    "alg": "RS256",
    "kid": "test_clerk_kid_1",
    "n": int_to_base64url(_test_public_numbers.n),
    "e": int_to_base64url(_test_public_numbers.e),
}

_mock_jwks = {
    "keys": [_test_jwk]
}


def create_clerk_rs256_token(
    sub: str = "user_clerk_test_123",
    email: str = "clerk_user@example.com",
    first_name: str = "Priya",
    last_name: str = "Sharma",
    image_url: str = "https://images.ruralheart.com/avatar1.jpg",
    expires_in: int = 3600,
    kid: str = "test_clerk_kid_1",
) -> str:
    """Generates a valid RS256 JWT signed with test private key."""
    now = int(time.time())
    payload = {
        "sub": sub,
        "email": email,
        "first_name": first_name,
        "last_name": last_name,
        "full_name": f"{first_name} {last_name}",
        "image_url": image_url,
        "iat": now,
        "nbf": now,
        "exp": now + expires_in,
        "iss": "https://clerk.ruralheart.com",
    }
    headers = {
        "alg": "RS256",
        "kid": kid,
        "typ": "JWT",
    }
    return jwt.encode(payload, _test_private_pem, algorithm="RS256", headers=headers)


@pytest.fixture(autouse=True)
def setup_mock_jwks(monkeypatch):
    """Automatically mock the JWKS cache with test RSA JWK."""
    monkeypatch.setattr(clerk_verifier, "_cached_jwks", _mock_jwks)
    monkeypatch.setattr(clerk_verifier, "_cached_at", time.time())
    monkeypatch.setattr(clerk_verifier, "_cache_ttl", 3600)


def test_clerk_jwks_verifier_success():
    """Test that a valid RS256 Clerk token decodes successfully and extracts claims."""
    token = create_clerk_rs256_token(
        sub="user_2XyZ999",
        email="aarav.kumar@example.com",
        first_name="Aarav",
        last_name="Kumar",
    )

    import asyncio
    claims = asyncio.run(clerk_verifier.verify_token(token))

    assert isinstance(claims, ClerkUserClaims)
    assert claims.sub == "user_2XyZ999"
    assert claims.clerk_id == "user_2XyZ999"
    assert claims.email == "aarav.kumar@example.com"
    assert claims.first_name == "Aarav"
    assert claims.last_name == "Kumar"
    assert claims.full_name == "Aarav Kumar"


def test_clerk_expired_token_raises_401():
    """Test that an expired Clerk token raises HTTP 401 Unauthorized."""
    token = create_clerk_rs256_token(
        sub="user_expired_123",
        expires_in=-300, # expired 5 minutes ago
    )

    import asyncio
    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(clerk_verifier.verify_token(token))

    assert exc_info.value.status_code == 401
    assert "expired" in exc_info.value.detail.lower()


def test_clerk_malformed_token_raises_401():
    """Test that a malformed or garbage token raises HTTP 401 Unauthorized."""
    import asyncio
    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(clerk_verifier.verify_token("invalid.token.structure"))

    assert exc_info.value.status_code == 401


def test_clerk_cache_key_rotation(monkeypatch):
    """Test that an unknown key ID triggers a JWKS refresh."""
    # Generate second keypair
    key2 = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    key2_pem = key2.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")
    key2_pub_nums = key2.public_key().public_numbers()
    jwk2 = {
        "kty": "RSA",
        "use": "sig",
        "alg": "RS256",
        "kid": "rotated_kid_2",
        "n": int_to_base64url(key2_pub_nums.n),
        "e": int_to_base64url(key2_pub_nums.e),
    }

    fresh_jwks = {"keys": [_test_jwk, jwk2]}

    async def mock_fetch_jwks(force_refresh=False):
        return fresh_jwks

    verifier = ClerkJWKSVerifier()
    verifier._cached_jwks = {"keys": [_test_jwk]}
    verifier._cached_at = time.time()
    monkeypatch.setattr(verifier, "fetch_jwks", mock_fetch_jwks)

    import asyncio
    key = asyncio.run(verifier.get_signing_key("rotated_kid_2"))
    assert key is not None
    assert key["kid"] == "rotated_kid_2"


client = TestClient(app)


def test_api_users_me_with_clerk_token():
    """Test GET /api/v1/users/me using Clerk authentication Bearer token."""
    unique_clerk_id = f"user_test_{uuid.uuid4().hex[:8]}"
    unique_email = f"{unique_clerk_id}@ruralheart.test"
    token = create_clerk_rs256_token(
        sub=unique_clerk_id,
        email=unique_email,
        first_name="Ananya",
        last_name="Verma",
        image_url="https://images.ruralheart.com/ananya.jpg",
    )

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    json_data = response.json()
    assert json_data["success"] is True
    data = json_data["data"]
    assert data["clerk_id"] == unique_clerk_id
    assert data["email"] == unique_email
    assert "Ananya" in data["full_name"]


def test_api_users_me_update_profile():
    """Test PUT /api/v1/users/me updates profile fields for authenticated user."""
    unique_clerk_id = f"user_test_{uuid.uuid4().hex[:8]}"
    unique_email = f"{unique_clerk_id}@ruralheart.test"
    token = create_clerk_rs256_token(
        sub=unique_clerk_id,
        email=unique_email,
        first_name="Rohan",
        last_name="Gupta",
    )

    # Initial sync via GET /me
    get_res = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_res.status_code == 200

    # Update profile
    update_payload = {
        "full_name": "Rohan Gupta (Updated)",
        "bio": "Exploring rural roots & coffee culture in Ayodhya.",
        "dob": "1998-05-15",
        "gender": "male",
        "interested_in": "female",
        "intent": "serious",
        "area_name": "Civil Lines, Ayodhya",
    }

    put_res = client.put(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json=update_payload,
    )
    assert put_res.status_code == 200
    updated_data = put_res.json()["data"]
    assert updated_data["full_name"] == "Rohan Gupta (Updated)"
    assert updated_data["bio"] == "Exploring rural roots & coffee culture in Ayodhya."
    assert updated_data["dob"] == "1998-05-15"
    assert updated_data["intent"] == "serious"
    assert updated_data["is_onboarded"] is True


def test_api_auth_clerk_sync_endpoint():
    """Test POST /api/v1/auth/clerk-sync endpoint with FCM token registration."""
    unique_clerk_id = f"user_sync_{uuid.uuid4().hex[:8]}"
    unique_email = f"{unique_clerk_id}@ruralheart.test"
    token = create_clerk_rs256_token(
        sub=unique_clerk_id,
        email=unique_email,
        first_name="Kavita",
        last_name="Singh",
    )

    sync_payload = {
        "fcm_token": "fcm_test_device_token_xyz_123456789",
        "device_id": "device_flutter_pixel7",
    }

    res = client.post(
        "/api/v1/auth/clerk-sync",
        headers={"Authorization": f"Bearer {token}"},
        json=sync_payload,
    )
    assert res.status_code == 200
    json_data = res.json()
    assert json_data["success"] is True
    data = json_data["data"]
    assert data["clerk_id"] == unique_clerk_id
    assert data["email"] == unique_email
    assert data["is_new_user"] is True


def test_unauthorized_access_without_token():
    """Test that accessing /api/v1/users/me without Authorization header returns 401."""
    res = client.get("/api/v1/users/me")
    assert res.status_code == 401
