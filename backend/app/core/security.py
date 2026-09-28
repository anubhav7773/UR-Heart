import os
import time
from typing import Optional, Dict, Any
from uuid import UUID
import httpx
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.domain.user import User

security_scheme = HTTPBearer(auto_error=True)

FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "ur-heart-44b46")
FIREBASE_ISSUER = f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"
GOOGLE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

# In-memory public key cache to avoid fetching Google certs on every single request
_public_keys_cache: Dict[str, str] = {}
_cache_expiry: float = 0.0


async def get_google_public_keys() -> Dict[str, str]:
    """Fetches and caches Google's public x509 certificates for RS256 token verification."""
    global _public_keys_cache, _cache_expiry
    current_time = time.time()

    if _public_keys_cache and current_time < _cache_expiry:
        return _public_keys_cache

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(GOOGLE_CERTS_URL)
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to verify security credentials with identity provider."
            )
        
        # Cache control header parsing
        cache_control = response.headers.get("cache-control", "")
        max_age = 3600
        for part in cache_control.split(","):
            if "max-age=" in part:
                try:
                    max_age = int(part.split("=")[1].strip())
                except ValueError:
                    max_age = 3600

        _public_keys_cache = response.json()
        _cache_expiry = current_time + max_age
        return _public_keys_cache


async def verify_firebase_jwt(token: str) -> Dict[str, Any]:
    """Cryptographically verifies incoming JWT. Enforces signature, aud, iss, and exp."""
    try:
        # 1. Decode header without verification to retrieve Key ID (kid)
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        if not kid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token header: Missing Key ID (kid)."
            )

        # 2. Match Key ID with Google's public certificates
        keys = await get_google_public_keys()
        certificate = keys.get(kid)
        if not certificate:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token certificate expired or unknown Key ID."
            )

        # 3. Cryptographically verify signature, audience, and issuer (RS256)
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

    stmt = select(User).where(User.auth_id == auth_uuid, User.deleted_at.is_(None))
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


async def require_superadmin(
    current_user: User = Depends(get_current_user)
) -> User:
    """Strict authorization gate: Validates server-side role and immutable admin identity."""
    expected_admin_email = os.getenv("SUPERADMIN_CANONICAL_EMAIL") or os.getenv("SUPERADMIN_EMAIL", "kshtriyaanubhav9120@gmail.com")
    
    # Check both verified email and database role claim
    user_email = getattr(current_user, "email", "") or ""
    user_role = getattr(current_user, "role", "user") or "user"
    if user_email.strip().lower() != expected_admin_email.strip().lower() or user_role != "superadmin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access strictly restricted to the Sovereign Sanctuary Sentinel."
        )
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
