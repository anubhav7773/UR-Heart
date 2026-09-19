from uuid import UUID
from typing import Optional
from fastapi import Request, Header, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import verify_firebase_token
from app.models.domain.user import User

async def get_current_user(
    request: Request,
    authorization: str = Header(..., description="Firebase Bearer Token"),
    x_installation_uuid: Optional[str] = Header(None, alias="X-Installation-UUID"),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Validates Firebase Bearer token and returns the corresponding active User.
    Enforces server-side authentication (Check 6), account safety, and installation UUID hygiene.
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Expected 'Bearer <token>'."
        )

    token = authorization.split("Bearer ")[1].strip()
    token_payload = verify_firebase_token(token, check_revoked=True)
    firebase_uid = token_payload.get("uid")

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

    # Query active user
    stmt = (
        select(User)
        .where(User.firebase_uid == firebase_uid)
        .where(User.deleted_at.is_(None))
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not registered. Please complete registration setup."
        )

    caller_email = (token_payload.get("email") or "").strip().lower()
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

    if user.is_banned or user.is_frozen:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account has been suspended for safety violations."
        )

    return user


# Statutory Super Admin Whitelist
MASTER_ADMIN_WHITELIST = {
    "kshtriyaanubhav9120@gmail.com",
}

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

    # Secondary check against Firebase decoded token if available in state
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
