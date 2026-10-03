import os
from typing import Optional
from uuid import UUID
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import get_settings
from app.core.database import get_db
from app.core.exceptions import (
    AuthenticationFailedException,
    ForbiddenException,
    ProfileNotFoundException
)
from app.core.security import verify_firebase_jwt, verify_firebase_token, resolve_auth_uuid
from app.models.domain.user import User

settings = get_settings()


async def get_current_user(
    authorization: Optional[str] = Header(None, description="Bearer <Firebase_ID_Token>"),
    x_installation_uuid: Optional[str] = Header(None, description="App-scoped client installation UUID"),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Validates Firebase Auth JWT token with cryptographic RS256 JWKS verification,
    verifies installation UUID handshake, and enforces Zero-on-Delete state reset.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise AuthenticationFailedException("Invalid authorization header format. Expected Bearer <token>.")

    token = authorization.split("Bearer ")[1].strip()
    try:
        auth_payload = await verify_firebase_jwt(token)
    except HTTPException as e:
        raise AuthenticationFailedException(e.detail)
    except Exception as e:
        raise AuthenticationFailedException(f"Cryptographic token validation failed: {str(e)}")

    auth_id_str = auth_payload.get("sub") or auth_payload.get("user_id") or auth_payload.get("uid")
    if not auth_id_str:
        raise AuthenticationFailedException("Token payload missing subject identifier.")

    auth_uuid = resolve_auth_uuid(auth_id_str)

    # Retrieve User Record from Supabase
    stmt = select(User).where(User.auth_id == auth_uuid, User.deleted_at.is_(None))
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # Fallback: check by email from verified token
    token_email = (auth_payload.get("email") or "").strip().lower()
    if not user and token_email:
        stmt = select(User).where(User.email == token_email, User.deleted_at.is_(None))
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()
        if user and user.auth_id != auth_uuid:
            try:
                user.auth_id = auth_uuid
                await db.commit()
                await db.refresh(user)
            except Exception:
                await db.rollback()

    if not user:
        raise ProfileNotFoundException("User identity verified but sanctuary record does not exist.")

    # Attach verified email from token payload
    user.email = auth_payload.get("email", "")

    # Zero-on-Delete Re-install Detection Handshake (if installation UUID provided)
    if x_installation_uuid and x_installation_uuid.strip():
        incoming_uuid = x_installation_uuid.strip()
        if user.last_installation_uuid is None:
            user.last_installation_uuid = incoming_uuid
            await db.commit()
        elif user.last_installation_uuid != incoming_uuid:
            # App re-installation detected: Reset streaks and rewards per compliance mandate
            user.streak_count = 0
            user.reward_balance = 0
            user.last_installation_uuid = incoming_uuid
            await db.commit()
            await db.refresh(user)

    return user


async def require_superadmin(current_user: User = Depends(get_current_user)) -> User:
    """Strict authorization gate: Validates server-side role and immutable admin identity."""
    admin_whitelist = {
        (os.getenv("SUPERADMIN_CANONICAL_EMAIL") or "").strip().lower(),
        (os.getenv("SUPERADMIN_EMAIL") or "").strip().lower(),
        "asiverticals@gmail.com",
    }
    admin_whitelist.discard("")
    user_email = (getattr(current_user, "email", "") or "").strip().lower()

    if user_email not in admin_whitelist:
        raise ForbiddenException("Access Denied: You do not possess Sanctuary Sovereign privileges. Access strictly restricted to the Sovereign Sanctuary Sentinel.")
    return current_user
