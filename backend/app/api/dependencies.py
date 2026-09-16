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
        from datetime import date
        import re

        email = token_payload.get("email") or f"{firebase_uid[:8]}@urheart.app"
        raw_name = token_payload.get("name") or email.split("@")[0] or "UR Heart User"
        clean_name = re.sub(r"[^a-zA-Z\s]", "", raw_name).strip() or "UR Heart User"
        phone_suffix = f"{(abs(hash(firebase_uid)) % 90000000 + 10000000):08d}"
        phone = f"+919{phone_suffix[:9]}"

        user = User(
            firebase_uid=firebase_uid,
            phone_number=phone,
            whatsapp_number=phone,
            full_name=clean_name[:50],
            dob=date(2000, 1, 1),
            gender="other",
            city="Lucknow",
            bio="UR-Heart Explorer",
            installation_uuid=UUID(x_installation_uuid.strip()) if x_installation_uuid else None,
            is_verified=True,
            is_banned=False,
        )
        db.add(user)
        try:
            await db.commit()
            await db.refresh(user)
        except Exception:
            await db.rollback()
            result = await db.execute(stmt)
            user = result.scalar_one_or_none()
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to initialize user session."
                )

    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account has been suspended for safety violations."
        )

    return user

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
