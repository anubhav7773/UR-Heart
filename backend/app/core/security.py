import os
from uuid import UUID
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any

import jwt
from fastapi import HTTPException, Response, status
import firebase_admin
from firebase_admin import auth, credentials
from passlib.context import CryptContext

# Secret key for internal token issuance
INTERNAL_JWT_SECRET = os.getenv("INTERNAL_JWT_SECRET", "UR_HEART_INTERNAL_HMAC_SECRET_KEY_ASI_VERTICALS")
INTERNAL_JWT_ALGORITHM = "HS256"

# Argon2id Password Hashing Context (time_cost=3, memory_cost=64MB, parallelism=2)
pwd_context = CryptContext(
    schemes=["argon2"],
    deprecated="auto",
    argon2__time_cost=3,
    argon2__memory_cost=65536,  # 64 MB (65536 KiB)
    argon2__parallelism=2
)

def hash_password(password: str) -> str:
    """Hashes a password using Argon2id with time_cost=3, memory_cost=64MB."""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plaintext password against an Argon2id hash."""
    return pwd_context.verify(plain_password, hashed_password)

def set_secure_auth_cookie(response: Response, key: str, value: str, max_age: int = 3600) -> None:
    """
    Sets a hardened session cookie according to Security Check 9:
    - httponly=True (blocks XSS theft via document.cookie)
    - secure=True (enforces transmission strictly over HTTPS / TLS 1.3)
    - samesite='Strict' (mitigates CSRF completely)
    - max_age=3600 (1 hour session expiration)
    """
    response.set_cookie(
        key=key,
        value=value,
        httponly=True,
        secure=True,
        samesite="strict",
        max_age=max_age
    )

# Initialize Firebase Admin App safely
_firebase_initialized = False
try:
    if not firebase_admin._apps:
        project_id = os.getenv("FIREBASE_PROJECT_ID")
        client_email = os.getenv("FIREBASE_CLIENT_EMAIL")
        private_key = os.getenv("FIREBASE_PRIVATE_KEY")

        service_account_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "serviceAccountKey.json"))
        if os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
        elif project_id and client_email and private_key:
            cred = credentials.Certificate({
                "type": "service_account",
                "project_id": project_id,
                "private_key": private_key.replace("\\n", "\n"),
                "client_email": client_email,
                "token_uri": "https://oauth2.googleapis.com/token"
            })
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
        else:
            # Local test mode / fallback default app
            try:
                firebase_admin.initialize_app()
                _firebase_initialized = True
            except Exception:
                _firebase_initialized = False
    else:
        _firebase_initialized = True
except Exception:
    _firebase_initialized = False

def verify_firebase_token(token: str, check_revoked: bool = True) -> Dict[str, Any]:
    """
    Decodes and cryptographically verifies Firebase ID token using firebase_admin.auth.
    Enforces check_revoked=True to immediately reject revoked tokens.
    Extracts uid (mapped to firebase_uid), email, and email_verified.
    Raises HTTPException(401) on failure.
    """
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token is missing."
        )

    try:
        decoded_token = auth.verify_id_token(token, check_revoked=check_revoked)
        return {
            "uid": decoded_token.get("uid"),
            "email": decoded_token.get("email"),
            "email_verified": decoded_token.get("email_verified", False)
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid, expired or revoked Firebase authentication token: {str(e)}"
        )

def create_internal_token(user_id: UUID, expires_delta: Optional[timedelta] = None) -> str:
    """Creates a signed internal JWT for WebSocket handshakes and internal microservices."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(hours=24)

    payload = {
        "sub": str(user_id),
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "iss": "UR-Heart-Auth"
    }
    return jwt.encode(payload, INTERNAL_JWT_SECRET, algorithm=INTERNAL_JWT_ALGORITHM)

def decode_access_token(token: str) -> Optional[str]:
    """Decodes internal JWT and returns user_id string if valid, else None."""
    try:
        payload = jwt.decode(
            token,
            INTERNAL_JWT_SECRET,
            algorithms=[INTERNAL_JWT_ALGORITHM],
            options={"require": ["exp", "sub"]}
        )
        return payload.get("sub")
    except Exception:
        return None
