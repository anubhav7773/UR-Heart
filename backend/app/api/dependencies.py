from uuid import UUID
from fastapi import Depends, Header, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import get_settings
from app.core.database import get_db
from app.core.exceptions import (
    AuthenticationFailedException,
    ForbiddenException,
    ProfileNotFoundException
)
from app.core.security import verify_firebase_token
from app.models.domain.user import User

settings = get_settings()


async def get_current_user(
    authorization: str = Header(..., description="Bearer <Firebase_ID_Token>"),
    x_installation_uuid: str = Header(..., description="App-scoped client installation UUID"),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Validates Firebase Auth JWT token, verifies installation UUID handshake,
    and enforces Zero-on-Delete state reset upon reinstallation.
    """
    if not authorization.startswith("Bearer "):
        raise AuthenticationFailedException("Invalid authorization header format. Expected Bearer <token>.")

    token = authorization.split("Bearer ")[1].strip()
    auth_payload = await verify_firebase_token(token)
    auth_id_str = auth_payload.get("uid")

    if not auth_id_str:
        raise AuthenticationFailedException("Token verification failed: Missing UID claim.")

    try:
        auth_uuid = UUID(auth_id_str)
    except ValueError:
        raise AuthenticationFailedException("Token UID claim is not a valid UUID.")

    # Retrieve User Record from Supabase
    stmt = select(User).where(User.auth_id == auth_uuid, User.deleted_at.is_(None))
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise ProfileNotFoundException("User profile not found or permanently erased.")

    # Attach verified email from token payload
    user.email = auth_payload.get("email", "")

    # Zero-on-Delete Re-install Detection Handshake
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
    """Strict Gatekeeper: Only permits kshtriyaanubhav9120@gmail.com."""
    user_email = getattr(current_user, "email", "") or ""
    if user_email.strip().lower() != settings.SUPERADMIN_EMAIL.lower():
        raise ForbiddenException("Access Denied: You do not possess Sanctuary Sovereign privileges.")
    return current_user
