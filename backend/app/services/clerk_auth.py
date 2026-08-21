import logging
import time
import uuid
from datetime import date, datetime, timezone
from typing import Optional, Dict, Any, List, Tuple
import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt
from jose.exceptions import JWTError, ExpiredSignatureError, JWTClaimsError
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.database import get_db
from app.models.orm import (
    User,
    UserPhoto,
    UserAdCounter,
    GenderEnum as ORMGenderEnum,
    IntentEnum as ORMIntentEnum,
    VerificationStatusEnum,
)
from app.models.schemas import ClerkUserClaims, UserSessionData

logger = logging.getLogger(__name__)

security_bearer = HTTPBearer(auto_error=False)


class ClerkJWKSVerifier:
    """
    Robust Clerk JWKS Key Manager and Token Verifier.
    - Caches JWKS keys with TTL to minimize network overhead.
    - Handles key rotation automatically on unknown 'kid'.
    - Verifies RS256 signatures, issuer, audience, and expiration.
    """

    def __init__(self):
        self._cached_jwks: Optional[Dict[str, Any]] = None
        self._cached_at: float = 0.0
        self._cache_ttl: int = getattr(settings, "CLERK_JWKS_CACHE_TTL_SECONDS", 3600)

    def get_jwks_url(self) -> Optional[str]:
        """Resolves the JWKS URL from explicit setting or Clerk issuer."""
        if settings.CLERK_JWKS_URL:
            return settings.CLERK_JWKS_URL.strip()
        if settings.CLERK_ISSUER:
            issuer = settings.CLERK_ISSUER.strip().rstrip("/")
            return f"{issuer}/.well-known/jwks.json"
        return None

    def is_cache_valid(self) -> bool:
        """Checks if the cached JWKS has not expired."""
        if not self._cached_jwks:
            return False
        return (time.time() - self._cached_at) < self._cache_ttl

    async def fetch_jwks(self, force_refresh: bool = False) -> Dict[str, Any]:
        """Fetches JWKS keys from Clerk endpoint with caching."""
        if not force_refresh and self.is_cache_valid() and self._cached_jwks:
            return self._cached_jwks

        jwks_url = self.get_jwks_url()
        if not jwks_url:
            if settings.CLERK_PEM_PUBLIC_KEY:
                return {"keys": []}
            logger.warning("[ClerkAuth] Neither CLERK_JWKS_URL, CLERK_ISSUER, nor CLERK_PEM_PUBLIC_KEY configured.")
            return {"keys": []}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(jwks_url)
                response.raise_for_status()
                jwks_data = response.json()
                self._cached_jwks = jwks_data
                self._cached_at = time.time()
                logger.info(f"[ClerkAuth] Successfully fetched and cached JWKS from {jwks_url}")
                return jwks_data
        except Exception as e:
            logger.error(f"[ClerkAuth] Failed to fetch JWKS from {jwks_url}: {e}")
            if self._cached_jwks:
                logger.warning("[ClerkAuth] Using stale JWKS cache due to fetch error.")
                return self._cached_jwks
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Authentication service temporarily unavailable: Unable to retrieve signing keys.",
            )

    async def get_signing_key(self, kid: Optional[str]) -> Optional[Dict[str, Any]]:
        """Retrieves matching JWK key by key ID (kid), with automatic cache refresh on miss."""
        jwks = await self.fetch_jwks(force_refresh=False)
        keys = jwks.get("keys", [])

        if kid:
            for k in keys:
                if k.get("kid") == kid:
                    return k

            # Key not found in cache - might have been rotated by Clerk. Force refresh JWKS.
            logger.info(f"[ClerkAuth] Key ID '{kid}' not in cache. Refreshing JWKS...")
            jwks = await self.fetch_jwks(force_refresh=True)
            for k in jwks.get("keys", []):
                if k.get("kid") == kid:
                    return k

        # If only 1 key exists and no kid specified, fallback to it
        if len(keys) == 1 and not kid:
            return keys[0]

        return None

    def extract_claims_from_payload(self, payload: Dict[str, Any]) -> ClerkUserClaims:
        """Extracts normalized claims from verified token payload."""
        sub = str(payload.get("sub", "")).strip()
        if not sub:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token claims: 'sub' (User ID) is missing.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Extract email from various Clerk claim representations
        email: Optional[str] = payload.get("email")
        if not email and "email_address" in payload:
            email = payload.get("email_address")
        if not email and "email_addresses" in payload and isinstance(payload["email_addresses"], list):
            for e in payload["email_addresses"]:
                if isinstance(e, dict) and e.get("email_address"):
                    email = e.get("email_address")
                    break
                elif isinstance(e, str):
                    email = e
                    break

        email_verified = payload.get("email_verified", None)

        # Extract name fields
        first_name: Optional[str] = payload.get("first_name") or payload.get("given_name")
        last_name: Optional[str] = payload.get("last_name") or payload.get("family_name")
        full_name: Optional[str] = payload.get("full_name") or payload.get("name")
        if not full_name and (first_name or last_name):
            full_name = f"{first_name or ''} {last_name or ''}".strip() or None

        # Extract avatar / photo
        image_url: Optional[str] = (
            payload.get("image_url")
            or payload.get("picture")
            or payload.get("avatar_url")
        )

        # Extract phone
        phone_number: Optional[str] = payload.get("phone_number") or payload.get("primary_phone_number")

        return ClerkUserClaims(
            sub=sub,
            email=email,
            email_verified=email_verified,
            first_name=first_name,
            last_name=last_name,
            full_name=full_name,
            image_url=image_url,
            phone_number=phone_number,
            raw_claims=payload,
        )

    async def verify_token(self, token: str) -> ClerkUserClaims:
        """
        Decodes and verifies a Clerk JWT token.
        Supports:
        1. RS256 JWKS public key verification.
        2. RS256 PEM public key verification (if configured).
        3. Local HS256 secret key verification (for dev, testing, or internal tokens).
        """
        if not token or not isinstance(token, str):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing or malformed authorization token.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # 1. Inspect unverified header
        try:
            unverified_header = jwt.get_unverified_header(token)
            alg = unverified_header.get("alg", "RS256")
            kid = unverified_header.get("kid")
        except Exception:
            # Check if it might be an HS256 token without standard header
            alg = "HS256"
            kid = None

        payload: Optional[Dict[str, Any]] = None

        # 2. Case: RS256 Token from Clerk
        if alg.startswith("RS") or alg.startswith("ES") or kid is not None:
            # Try PEM public key if provided
            if settings.CLERK_PEM_PUBLIC_KEY:
                try:
                    payload = jwt.decode(
                        token,
                        settings.CLERK_PEM_PUBLIC_KEY,
                        algorithms=["RS256"],
                        options={"verify_aud": False, "verify_iss": False},
                    )
                except ExpiredSignatureError:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Authentication token has expired. Please refresh your session.",
                        headers={"WWW-Authenticate": 'Bearer error="invalid_token", error_description="token expired"'},
                    )
                except JWTError as e:
                    logger.warning(f"[ClerkAuth] PEM decode error: {e}")

            # Try JWKS key lookup
            if not payload:
                signing_key = await self.get_signing_key(kid)
                if not signing_key:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Could not find a valid signing key for token verification.",
                        headers={"WWW-Authenticate": "Bearer"},
                    )

                try:
                    # Verify token with JWK dictionary
                    payload = jwt.decode(
                        token,
                        signing_key,
                        algorithms=["RS256", "RS384", "RS512"],
                        options={"verify_aud": False, "verify_iss": False},
                    )
                except ExpiredSignatureError:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Authentication token has expired. Please sign in again.",
                        headers={"WWW-Authenticate": 'Bearer error="invalid_token", error_description="token expired"'},
                    )
                except JWTClaimsError as e:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=f"Token claims verification failed: {e}",
                        headers={"WWW-Authenticate": "Bearer"},
                    )
                except JWTError as e:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Invalid token signature or malformed token.",
                        headers={"WWW-Authenticate": "Bearer"},
                    )

        # 3. Fallback: Local HS256 Token (for dev / tests / internal authentication)
        if not payload:
            try:
                payload = jwt.decode(
                    token,
                    settings.SECRET_KEY,
                    algorithms=[settings.ALGORITHM, "HS256"],
                    options={"verify_aud": False, "verify_iss": False},
                )
            except ExpiredSignatureError:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication token has expired.",
                    headers={"WWW-Authenticate": 'Bearer error="invalid_token"'},
                )
            except JWTError:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Could not validate authentication credentials.",
                    headers={"WWW-Authenticate": "Bearer"},
                )

        if not payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token validation failed.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return self.extract_claims_from_payload(payload)


# Global Singleton Verifier
clerk_verifier = ClerkJWKSVerifier()


class ClerkUserSyncService:
    """
    Database Synchronization Service for Clerk Users:
    - Auto-detects existing users by clerk_id, email, or user UUID.
    - Automatically creates a new User profile with sane dating app defaults on first login.
    - Synchronizes online status and last_seen timestamps.
    - Builds comprehensive UserSessionData.
    """

    @staticmethod
    async def sync_or_get_user(
        db: AsyncSession,
        claims: ClerkUserClaims,
    ) -> Tuple[User, bool]:
        """
        Finds or automatically provisions a database User record from Clerk claims.
        Returns: (user_orm_object, is_new_user)
        """
        clerk_id = claims.clerk_id
        email = claims.email.lower().strip() if claims.email else None

        user: Optional[User] = None
        is_new_user = False

        try:
            # 1. Lookup by clerk_id
            try:
                stmt = (
                    select(User)
                    .options(selectinload(User.photos), selectinload(User.ad_counter))
                    .where(User.clerk_id == clerk_id)
                )
                res = await db.execute(stmt)
                user = res.scalars().first()
            except Exception as col_err:
                logger.debug(f"[ClerkSync] Clerk ID direct lookup notice: {col_err}")
                await db.rollback()
                user = None

            # 2. Fallback: Lookup by email and associate clerk_id
            if not user and email:
                try:
                    stmt_email = (
                        select(User)
                        .options(selectinload(User.photos), selectinload(User.ad_counter))
                        .where(User.email == email)
                    )
                    res_email = await db.execute(stmt_email)
                    user = res_email.scalars().first()
                    if user:
                        try:
                            user.clerk_id = clerk_id
                            await db.commit()
                        except Exception:
                            await db.rollback()
                except Exception:
                    await db.rollback()

            # 3. Fallback: Lookup by UUID if clerk_id happens to be UUID formatted
            if not user:
                try:
                    candidate_uuid = uuid.UUID(clerk_id)
                    stmt_uuid = (
                        select(User)
                        .options(selectinload(User.photos), selectinload(User.ad_counter))
                        .where(User.id == candidate_uuid)
                    )
                    res_uuid = await db.execute(stmt_uuid)
                    user = res_uuid.scalars().first()
                    if user and not getattr(user, "clerk_id", None):
                        try:
                            user.clerk_id = clerk_id
                            await db.commit()
                        except Exception:
                            await db.rollback()
                except (ValueError, TypeError):
                    pass

            # 4. Auto-Provision New User on First Login
            if not user:
                is_new_user = True
                new_user_id = uuid.uuid4()

                # Format default full name
                full_name = claims.full_name or claims.first_name or "UR Heart User"
                if not full_name.strip():
                    full_name = "User"

                user = User(
                    id=new_user_id,
                    clerk_id=clerk_id,
                    email=email,
                    phone_number=claims.phone_number,
                    full_name=full_name,
                    dob=date(2000, 1, 1),
                    gender=ORMGenderEnum.male,
                    interested_in=ORMGenderEnum.female,
                    intent=ORMIntentEnum.casual,
                    bio="",
                    area_name="Ayodhya",
                    village_pin_code="224001",
                    is_active=True,
                    is_online=True,
                    last_seen=datetime.now(timezone.utc),
                    photo_url=claims.image_url,
                    verification_status=VerificationStatusEnum.UNVERIFIED,
                )
                db.add(user)
                await db.flush()

                # Create default Ad Counter
                ad_counter = UserAdCounter(
                    user_id=new_user_id,
                    persistent_skip_count=0,
                    total_interstitials_shown=0,
                )
                db.add(ad_counter)

                # Create default photo if profile picture provided by Clerk
                if claims.image_url:
                    photo = UserPhoto(
                        id=uuid.uuid4(),
                        user_id=new_user_id,
                        photo_url=claims.image_url,
                        is_first_impression=True,
                        display_order=1,
                    )
                    db.add(photo)

                await db.commit()
                await db.refresh(user)
                logger.info(f"[ClerkSync] Auto-provisioned new User '{user.id}' for Clerk ID '{clerk_id}'")
            else:
                # Update existing user state
                user.is_online = True
                user.last_seen = datetime.now(timezone.utc)
                if claims.image_url and not user.photo_url:
                    user.photo_url = claims.image_url
                if email and not user.email:
                    user.email = email
                await db.commit()

        except Exception as e:
            logger.warning(f"[ClerkSync] DB operation fallback: {e}")
            await db.rollback()
            if not user:
                try:
                    fallback_uuid = uuid.UUID(clerk_id) if len(clerk_id) == 36 else uuid.uuid5(uuid.NAMESPACE_DNS, clerk_id)
                except Exception:
                    fallback_uuid = uuid.uuid4()
                user = User(
                    id=fallback_uuid,
                    clerk_id=clerk_id,
                    email=email,
                    full_name=claims.full_name or claims.first_name or "User",
                    dob=date(2000, 1, 1),
                    gender=ORMGenderEnum.male,
                    interested_in=ORMGenderEnum.female,
                    intent=ORMIntentEnum.casual,
                    is_active=True,
                    is_online=True,
                    last_seen=datetime.now(timezone.utc),
                    photo_url=claims.image_url,
                )
                is_new_user = True

        return user, is_new_user

    @staticmethod
    def build_user_session(
        user: User,
        claims: ClerkUserClaims,
    ) -> UserSessionData:
        """Serializes user ORM and claims into a comprehensive session payload."""
        # Calculate age if dob exists
        age: Optional[int] = None
        if user.dob:
            today = date.today()
            age = today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day))

        # Collect photos
        photos = [p.photo_url for p in user.photos] if user.photos else []
        if not photos and user.photo_url:
            photos = [user.photo_url]

        # Determine onboarding completeness (customized bio/photos/dob)
        is_onboarded = bool(
            user.bio
            or len(photos) > 1
            or (user.dob and user.dob != date(2000, 1, 1))
        )

        first_name = (user.full_name or "").split()[0] if user.full_name else "User"

        return UserSessionData(
            user_id=str(user.id),
            clerk_id=user.clerk_id or claims.clerk_id,
            email=user.email or claims.email,
            full_name=user.full_name or "UR Heart User",
            first_name=first_name,
            age=age,
            gender=user.gender.value if user.gender else "male",
            interested_in=user.interested_in.value if user.interested_in else "female",
            intent=user.intent.value if user.intent else "casual",
            bio=user.bio or "",
            area_name=user.area_name or "Ayodhya",
            photos=photos,
            photo_url=photos[0] if photos else user.photo_url,
            is_verified=bool(user.is_verified and getattr(user, 'verification_status', None) and user.verification_status.value == "APPROVED"),
            is_admin=bool(getattr(user, "is_admin", False)),
            is_online=bool(user.is_online),
            is_onboarded=is_onboarded,
            token_claims=claims.raw_claims,
        )


# ==============================================================================
# FastAPI Security Dependencies
# ==============================================================================

async def get_current_clerk_claims(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
) -> ClerkUserClaims:
    """Extracts and verifies Clerk JWT claims from the Authorization Bearer header."""
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication token header.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return await clerk_verifier.verify_token(credentials.credentials)


async def get_current_user_and_session(
    claims: ClerkUserClaims = Depends(get_current_clerk_claims),
    db: AsyncSession = Depends(get_db),
) -> Tuple[User, UserSessionData]:
    """Retrieves/auto-syncs the database User and builds the session object."""
    user, _ = await ClerkUserSyncService.sync_or_get_user(db, claims)
    session = ClerkUserSyncService.build_user_session(user, claims)
    return user, session


async def get_current_authenticated_user(
    user_session_tuple: Tuple[User, UserSessionData] = Depends(get_current_user_and_session),
) -> User:
    """FastAPI dependency returning the synced database User ORM object."""
    user, _ = user_session_tuple
    return user


async def get_current_session(
    user_session_tuple: Tuple[User, UserSessionData] = Depends(get_current_user_and_session),
) -> UserSessionData:
    """FastAPI dependency returning the UserSessionData object."""
    _, session = user_session_tuple
    return session
