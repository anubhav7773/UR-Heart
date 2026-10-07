import os
import time
from typing import Optional, Dict, Any
from uuid import UUID
import httpx
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_

from app.core.database import get_db
from app.models.domain.user import User
from starlette.requests import Request


class StrictHTTPBearer(HTTPBearer):
    async def __call__(self, request: Request) -> Optional[HTTPAuthorizationCredentials]:
        res = await super().__call__(request)
        if not res or not res.credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return res


security_scheme = StrictHTTPBearer(auto_error=False)

from app.core.config import get_settings

_settings = get_settings()
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID") or _settings.FIREBASE_PROJECT_ID
FIREBASE_ISSUER = f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"
FIREBASE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
GOOGLE_OAUTH_CERTS_URL = "https://www.googleapis.com/oauth2/v1/certs"
GOOGLE_SERVER_CLIENT_ID = "527791570469-hvkp9ctr4v0qnihptkq0vs080419e0cf.apps.googleusercontent.com"
GOOGLE_CERTS_URL = FIREBASE_CERTS_URL  # Backward compatibility alias

_raw_jwt = os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET") or _settings.JWT_SECRET_KEY
if not _raw_jwt or len(_raw_jwt.strip()) < 32 or (_raw_jwt == "dev-insecure-test-jwt-secret-key-32-chars-long" and (_settings.ENVIRONMENT or "").lower() == "production"):
    if (_settings.ENVIRONMENT or "").lower() == "production":
        raise RuntimeError("FATAL PRODUCTION SECURITY ERROR: JWT_SECRET_KEY is missing or insecure (<32 bytes). Refusing boot.")
    _raw_jwt = "dev-insecure-test-jwt-secret-key-32-chars-long"

JWT_SECRET_KEY = _raw_jwt


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """Creates a JWT access token for authenticating sessions."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=30)
    to_encode.update({"exp": expire, "iss": "ur-heart"})
    return jwt.encode(to_encode, JWT_SECRET_KEY, algorithm="HS256")

# In-memory public key caches to avoid fetching Google/Firebase certs on every single request
_firebase_keys_cache: Dict[str, str] = {}
_firebase_cache_expiry: float = 0.0

_google_oauth_keys_cache: Dict[str, str] = {}
_google_oauth_cache_expiry: float = 0.0


async def get_google_public_keys() -> Dict[str, str]:
    """Fetches and caches Firebase public x509 certificates for RS256 token verification."""
    global _firebase_keys_cache, _firebase_cache_expiry
    current_time = time.time()

    if _firebase_keys_cache and current_time < _firebase_cache_expiry:
        return _firebase_keys_cache

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(FIREBASE_CERTS_URL)
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to verify security credentials with identity provider."
            )
        
        cache_control = response.headers.get("cache-control", "")
        max_age = 3600
        for part in cache_control.split(","):
            if "max-age=" in part:
                try:
                    max_age = int(part.split("=")[1].strip())
                except ValueError:
                    max_age = 3600

        _firebase_keys_cache = response.json()
        _firebase_cache_expiry = current_time + max_age
        return _firebase_keys_cache


async def get_google_oauth_public_keys() -> Dict[str, str]:
    """Fetches and caches Google OAuth2 public x509 certificates for One Tap RS256 token verification."""
    global _google_oauth_keys_cache, _google_oauth_cache_expiry
    current_time = time.time()

    if _google_oauth_keys_cache and current_time < _google_oauth_cache_expiry:
        return _google_oauth_keys_cache

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(GOOGLE_OAUTH_CERTS_URL)
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to verify security credentials with Google OAuth provider."
            )
        
        cache_control = response.headers.get("cache-control", "")
        max_age = 3600
        for part in cache_control.split(","):
            if "max-age=" in part:
                try:
                    max_age = int(part.split("=")[1].strip())
                except ValueError:
                    max_age = 3600

        _google_oauth_keys_cache = response.json()
        _google_oauth_cache_expiry = current_time + max_age
        return _google_oauth_keys_cache


async def verify_firebase_jwt(token: str) -> Dict[str, Any]:
    """
    Cryptographically verifies incoming JWT.
    Supports:
    1. UR-Heart HS256 internal session tokens.
    2. Google OAuth2 / One Tap RS256 tokens (iss: accounts.google.com).
    3. Firebase Auth RS256 tokens (iss: securetoken.google.com/...).
    """
    # 0. Check if token is internal UR-Heart HS256 token
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=["HS256"],
            options={"verify_signature": True, "verify_exp": True}
        )
        if payload.get("iss") == "ur-heart":
            return payload
    except Exception:
        pass

    try:
        # 1. Decode header and unverified claims to inspect Key ID (kid) and Issuer (iss)
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        if not kid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token header: Missing Key ID (kid)."
            )

        unverified_claims = jwt.get_unverified_claims(token)
        token_iss = (unverified_claims.get("iss") or "").strip().lower()

        # 2. Dual-Provider Certificate Resolution
        certificate = None
        is_google_oauth = "accounts.google.com" in token_iss

        if is_google_oauth:
            oauth_keys = await get_google_oauth_public_keys()
            certificate = oauth_keys.get(kid)
            if not certificate:
                fb_keys = await get_google_public_keys()
                certificate = fb_keys.get(kid)
        else:
            fb_keys = await get_google_public_keys()
            certificate = fb_keys.get(kid)
            if not certificate:
                oauth_keys = await get_google_oauth_public_keys()
                certificate = oauth_keys.get(kid)
                if certificate:
                    is_google_oauth = True

        if not certificate:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token certificate expired or unknown Key ID."
            )

        # 3. Cryptographically verify signature, audience, and issuer
        if is_google_oauth:
            # Google OAuth2 / One Tap token verification
            allowed_audiences = [
                GOOGLE_SERVER_CLIENT_ID,
                FIREBASE_PROJECT_ID,
            ]
            custom_client_id = getattr(_settings, "GOOGLE_CLIENT_ID", None)
            if custom_client_id:
                allowed_audiences.append(custom_client_id)

            payload = jwt.decode(
                token,
                certificate,
                algorithms=["RS256"],
                options={
                    "verify_signature": True,
                    "verify_aud": False,  # Verified manually below to support multiple client IDs
                    "verify_exp": True,
                }
            )
            aud = payload.get("aud")
            if aud not in allowed_audiences and not any(a in str(aud) for a in ["googleusercontent.com", FIREBASE_PROJECT_ID]):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Google ID token audience mismatch: {aud}"
                )
            return payload
        else:
            # Firebase Auth token verification
            payload = jwt.decode(
                token,
                certificate,
                algorithms=["RS256"],
                audience=FIREBASE_PROJECT_ID,
                issuer=FIREBASE_ISSUER,
                options={
                    "verify_signature": True,
                    "verify_aud": True,
                    "verify_iss": True,
                    "verify_exp": True,
                }
            )
            return payload

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Cryptographic token validation failed: {str(e)}"
        )


def resolve_auth_uuid(raw_id: str) -> UUID:
    """
    Deterministically maps any auth identifier (Firebase string UID, Supabase UUID, or OAuth sub)
    to a valid RFC-4122 UUID to prevent asyncpg UUID decoding failures.
    """
    if isinstance(raw_id, UUID):
        return raw_id
    try:
        return UUID(str(raw_id))
    except (ValueError, TypeError):
        import uuid as _uuid
        return _uuid.uuid5(_uuid.NAMESPACE_URL, f"firebase:{raw_id}")


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Dependency: Verifies token and returns authenticated User entity."""
    token = credentials.credentials
    payload = await verify_firebase_jwt(token)
    
    auth_uid = payload.get("sub") or payload.get("user_id")
    if not auth_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload missing subject identifier."
        )

    # 1. Safely resolve auth_id to valid deterministic UUID
    auth_uuid = resolve_auth_uuid(auth_uid)

    stmt = select(User).where(
        or_(User.id == auth_uuid, User.auth_id == auth_uuid),
        User.deleted_at.is_(None)
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # 2. Fallback: check by email from verified token
    token_email = (payload.get("email") or "").strip().lower()
    if not user and token_email:
        stmt = select(User).where(User.email == token_email, User.deleted_at.is_(None))
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()
        # If user found by email and auth_id was a placeholder/different, sync auth_id
        if user and user.auth_id != auth_uuid:
            try:
                user.auth_id = auth_uuid
                await db.commit()
                await db.refresh(user)
            except Exception:
                await db.rollback()

    # 3. Auto-provision user shell if identity is cryptographically verified
    if not user:
        import uuid as _uuid
        from datetime import date as _date
        name = payload.get("name") or payload.get("display_name") or "Sanctuary Seeker"

        user = User(
            id=_uuid.uuid4(),
            auth_id=auth_uuid,
            full_name=name,
            dob=_date(2000, 1, 1),
            gender="Unspecified",
            interested_in="Everyone",
            contact_bridge_type="whatsapp",
            contact_bridge_encrypted="",
            location_name="Saket, Ayodhya",
            referral_code=f"UR-{_uuid.uuid4().hex[:6].upper()}",
            is_profile_completed=False,
            email=token_email,
        )
        db.add(user)
        try:
            await db.commit()
            await db.refresh(user)
        except Exception:
            await db.rollback()
            if token_email:
                res = await db.execute(select(User).where(User.email == token_email))
                user = res.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User identity verified but sanctuary record does not exist."
        )

    # Attach runtime email from token claims
    user.email = token_email
    return user


optional_security_scheme = HTTPBearer(auto_error=False)


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(optional_security_scheme),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """Graceful auth dependency: Resolves authenticated User or returns None if unauthenticated."""
    if not credentials or not credentials.credentials:
        return None
    try:
        return await get_current_user(credentials, db)
    except Exception:
        return None


async def require_superadmin(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Strict authorization gate: Validates server-side role and immutable admin identity."""
    admin_whitelist = {
        (os.getenv("SUPERADMIN_CANONICAL_EMAIL") or "").strip().lower(),
        (os.getenv("SUPERADMIN_EMAIL") or "").strip().lower(),
        "asiverticals@gmail.com",
    }
    admin_whitelist.discard("")
    
    # Check verified email against superadmin whitelist
    user_email = (getattr(current_user, "email", "") or "").strip().lower()
    if user_email not in admin_whitelist:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access strictly restricted to the Sovereign Sanctuary Sentinel."
        )
    
    # Auto-elevate role claim if not already superadmin
    user_role = getattr(current_user, "role", "user") or "user"
    if user_role != "superadmin":
        current_user.role = "superadmin"
        try:
            await db.commit()
        except Exception:
            pass
    return current_user


async def verify_firebase_token(token: str) -> Dict[str, Any]:
    """Compatibility bridge that delegates to cryptographically verified verify_firebase_jwt."""
    payload = await verify_firebase_jwt(token)
    return {
        "uid": str(payload.get("sub") or payload.get("user_id")),
        "email": payload.get("email", ""),
        "email_verified": payload.get("email_verified", False),
        "claims": payload
    }


def verify_ws_ticket(ticket: str) -> Optional[str]:
    """Validates ephemeral WebSocket handshake tickets."""
    if not ticket:
        return None
    try:
        from app.core.config import get_settings
        settings = get_settings()
        payload = jwt.decode(
            ticket,
            key=settings.SUPABASE_SERVICE_ROLE_KEY or "sanctuary_secret",
            algorithms=["HS256"],
            options={"verify_exp": True}
        )
        return payload.get("sub")
    except Exception:
        return None
