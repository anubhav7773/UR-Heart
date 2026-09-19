import time
from uuid import UUID
from typing import Optional
from fastapi import Request, Header, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.domain.user import User

security = HTTPBearer(auto_error=False)

# Strict JWT clock skew tolerance (in seconds)
MAX_TOKEN_CLOCK_SKEW = 60
MAX_SESSION_AGE_SECONDS = 3600  # 1 hour max lifespan before forcing Firebase refresh

# Statutory Super Admin Whitelist
MASTER_ADMIN_WHITELIST = {
    "kshtriyaanubhav9120@gmail.com",
}


def verify_firebase_token(token: str, check_revoked: bool = True) -> dict:
    """Wrapper around Firebase Admin auth.verify_id_token for centralized verification."""
    return auth.verify_id_token(token, check_revoked=check_revoked)


async def get_current_user(
    cred: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_device_id: Optional[str] = Header(None, alias="X-Device-ID"),
    x_installation_uuid: Optional[str] = Header(None, alias="X-Installation-UUID"),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Validates Firebase Auth JWT token and enforces expiry and session integrity.
    Prevents replay and session interception attacks.
    """
    token = cred.credentials if cred else None
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token is missing."
        )

    try:
        # Verify decoded Firebase JWT
        decoded_token = verify_firebase_token(token, check_revoked=True)
    except auth.RevokedIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been revoked. Please re-authenticate."
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Client must trigger Firebase refresh token exchange."
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}"
        )

    now = int(time.time())
    auth_time = decoded_token.get("auth_time")
    exp = decoded_token.get("exp")

    # 1. JWT Expiry Check
    if exp is not None and exp < now - MAX_TOKEN_CLOCK_SKEW:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Security token has expired. Session refresh required."
        )

    # 2. Maximum Session Age Verification
    if auth_time is not None and (now - auth_time) > (MAX_SESSION_AGE_SECONDS * 24):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Primary authentication session is too old. Please perform fresh login."
        )

    firebase_uid = decoded_token.get("uid")
    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token does not contain a valid Firebase UID."
        )

    if x_installation_uuid is not None:
        try:
            UUID(x_installation_uuid.strip())
        except (ValueError, AttributeError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid X-Installation-UUID format. Must be a valid UUIDv4."
            )

    # 3. Retrieve User from Database
    query = (
        select(User)
        .where(User.firebase_uid == firebase_uid)
        .where(User.deleted_at.is_(None))
    )
    result = await db.execute(query)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account record not found in system. User profile not registered."
        )

    caller_email = (decoded_token.get("email") or "").strip().lower()
    setattr(user, "email", caller_email)

    if caller_email in MASTER_ADMIN_WHITELIST:
        if not user.is_super_admin:
            user.is_super_admin = True
            try:
                await db.commit()
                await db.refresh(user)
            except Exception:
                await db.rollback()
    else:
        if user.is_super_admin:
            user.is_super_admin = False
            try:
                await db.commit()
                await db.refresh(user)
            except Exception:
                await db.rollback()

    # 4. Check Account Freeze & Ban Status
    if user.is_frozen or user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is currently frozen due to policy violations. Contact support."
        )

    return user


async def require_master_admin(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Guarantees caller is an authorized Super Admin.
    Validates both the DB flag and hardcoded whitelist identity.
    """
    if not current_user.is_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrative access denied. Privilege level insufficient."
        )

    user_email = getattr(current_user, "email", None)
    if user_email and user_email.lower() not in MASTER_ADMIN_WHITELIST:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is not on the statutory Master Admin whitelist."
        )

    return current_user


async def get_current_user_id(
    current_user: User = Depends(get_current_user)
) -> UUID:
    """Convenience dependency to retrieve authenticated user's internal UUID."""
    return current_user.id


def require_installation_uuid(
    x_installation_uuid: Optional[str] = Header(None, alias="X-Installation-UUID")
) -> UUID:
    """
    Strict dependency enforcing the presence and validity of X-Installation-UUID.
    Rejects missing or malformed headers with HTTP 400 Bad Request.
    """
    if not x_installation_uuid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing required X-Installation-UUID header."
        )
    try:
        return UUID(x_installation_uuid.strip())
    except (ValueError, AttributeError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-Installation-UUID format. Must be a valid UUIDv4."
        )
