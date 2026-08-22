import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, Any
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.database import get_db, AsyncSessionLocal
from app.models.orm import User

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security_bearer = HTTPBearer(auto_error=False)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plain-text password against a hashed bcrypt digest."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hashes a raw password using bcrypt."""
    return pwd_context.hash(password)


def create_access_token(subject: str | Any, expires_delta: Optional[timedelta] = None) -> str:
    """Generates a signed JWT access token for user authentication."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode = {
        "exp": expire,
        "sub": str(subject),
        "iat": datetime.now(timezone.utc),
    }
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> Optional[str]:
    """Decodes and verifies a local HS256 JWT token signature, extracting the user_id subject."""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM, "HS256"],
            options={"verify_aud": False, "verify_iss": False},
        )
        user_id: Optional[str] = payload.get("sub")
        return user_id
    except JWTError:
        return None


async def resolve_user_id_from_raw_token(token: str) -> Optional[str]:
    """
    Validates a raw authentication token string (Firebase ID token, HS256 JWT, or UUID)
    and resolves the database User UUID string.
    """
    if not token or not isinstance(token, str):
        return None

    cleaned_token = token.strip()
    if cleaned_token.lower().startswith("bearer "):
        cleaned_token = cleaned_token[7:].strip()

    # 1. Local HS256 JWT decoding
    user_id = decode_access_token(cleaned_token)
    if user_id:
        return user_id

    # 2. Try Firebase ID Token Verification
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth

        if firebase_admin._apps:
            decoded_token = firebase_auth.verify_id_token(cleaned_token)
            firebase_uid = decoded_token.get("uid") or decoded_token.get("sub")
            email = decoded_token.get("email")
            phone = decoded_token.get("phone_number")

            if firebase_uid or email or phone:
                async with AsyncSessionLocal() as db:
                    conditions = []
                    if email:
                        conditions.append(User.email == email)
                    if phone:
                        conditions.append(User.phone_number == phone)
                    if firebase_uid:
                        conditions.append(User.clerk_id == firebase_uid)
                        if len(firebase_uid) == 36:
                            try:
                                conditions.append(User.id == uuid.UUID(firebase_uid))
                            except Exception:
                                pass
                    if conditions:
                        from sqlalchemy import or_
                        stmt = select(User).where(or_(*conditions))
                        res = await db.execute(stmt)
                        user = res.scalars().first()
                        if user:
                            return str(user.id)
    except Exception:
        pass

    # 3. Direct UUID validation
    try:
        u = uuid.UUID(cleaned_token)
        return str(u)
    except Exception:
        pass

    return None



async def get_current_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: AsyncSession = Depends(get_db),
) -> str:
    """
    FastAPI bearer security dependency for validating authentication tokens:
    - Supports Firebase ID tokens (verified via Firebase Admin SDK or local user resolution).
    - Supports local HS256 JWT tokens.
    Returns: Local database User UUID string.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication token header.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    # 1. Try Firebase Token Verification (if initialized)
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth

        if firebase_admin._apps:
            decoded_token = firebase_auth.verify_id_token(token)
            firebase_uid = decoded_token.get("uid") or decoded_token.get("sub")
            email = decoded_token.get("email")
            phone = decoded_token.get("phone_number")

            if firebase_uid:
                # Find user by phone, email, or id
                stmt = select(User).where(
                    (User.email == email) if email else (User.phone_number == phone) if phone else (User.id == uuid.UUID(firebase_uid) if len(firebase_uid) == 36 else False)
                )
                res = await db.execute(stmt)
                user = res.scalars().first()
                if user:
                    return str(user.id)
    except Exception:
        pass

    # 2. Fallback: Local HS256 token decoding
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials or token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user_id


async def get_current_authenticated_user(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    FastAPI dependency that resolves the full User ORM entity for the authenticated user.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user identification token.",
        )

    res = await db.execute(
        select(User)
        .options(selectinload(User.photos), selectinload(User.ad_counter))
        .where(User.id == user_uuid)
    )
    user = res.scalars().first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )
    return user


async def get_optional_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: AsyncSession = Depends(get_db),
) -> Optional[str]:
    """Optional bearer security dependency that returns user_id if valid token is present, or None."""
    if not credentials or not credentials.credentials:
        return None
    try:
        return await get_current_user_id(credentials, db)
    except HTTPException:
        return None


SUPER_ADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"


async def get_current_user(
    current_user_id: str = Depends(get_current_user_id),
) -> str:
    return current_user_id


async def admin_required(
    current_user_id: str = Depends(get_current_user_id),
) -> str:
    """
    FastAPI dependency for verifying that the current authenticated user has admin privileges.
    Validated by checking super admin email or admin flag against database.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID token."
        )

    async with AsyncSessionLocal() as db:
        res = await db.execute(select(User).where(User.id == user_uuid))
        user = res.scalars().first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found."
            )

        is_super_admin = bool(user.email and user.email.lower().strip() == SUPER_ADMIN_EMAIL.lower())
        is_admin_flag = bool(getattr(user, "is_admin", False))

        if not (is_super_admin or is_admin_flag):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin privileges required."
            )

    return current_user_id


_active_conversations: dict[str, tuple[str, str]] = {}


def register_conversation_participants(match_id: str, user1_id: str, user2_id: str):
    """Registers conversation participant IDs for access control."""
    _active_conversations[str(match_id)] = (str(user1_id), str(user2_id))


async def verify_conversation_access(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: Optional[AsyncSession] = Depends(get_db)
) -> str:
    """
    Blocks IDOR: Verifies current_user_id is an active participant in match_id / conversation_id.
    """
    from app.models.orm import Match

    match_id_str = str(match_id)
    current_user_str = str(current_user_id)

    if match_id_str in _active_conversations:
        u1, u2 = _active_conversations[match_id_str]
        if current_user_str not in (u1, u2):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not a participant in this conversation."
            )
        return match_id

    if db is not None:
        try:
            match_uuid = uuid.UUID(match_id_str)
            stmt = select(Match).where(Match.id == match_uuid)
            res = await db.execute(stmt)
            match_obj = res.scalars().first()
            if match_obj:
                u1, u2 = str(match_obj.user1_id), str(match_obj.user2_id)
                _active_conversations[match_id_str] = (u1, u2)
                if current_user_str not in (u1, u2):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Access denied. You are not a participant in this conversation."
                    )
        except HTTPException:
            raise
        except Exception:
            pass

    return match_id


async def verify_conversation_access_raw(conversation_id: str, user_id: str) -> bool:
    """
    Direct async check whether user_id is a valid participant of conversation_id / match_id.
    Returns True if participant, False otherwise.
    """
    from app.models.orm import Match

    match_id_str = str(conversation_id)
    user_id_str = str(user_id)

    if match_id_str in _active_conversations:
        u1, u2 = _active_conversations[match_id_str]
        return user_id_str in (u1, u2)

    try:
        match_uuid = uuid.UUID(match_id_str)
        user_uuid = uuid.UUID(user_id_str)

        async with AsyncSessionLocal() as db:
            stmt = select(Match).where(Match.id == match_uuid)
            res = await db.execute(stmt)
            match_obj = res.scalars().first()
            if match_obj:
                u1, u2 = str(match_obj.user1_id), str(match_obj.user2_id)
                _active_conversations[match_id_str] = (u1, u2)
                return user_id_str in (u1, u2)
    except Exception:
        pass

    return False
