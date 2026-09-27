# 04_BACKEND_FASTAPI_ARCHITECTURE.md: MODULAR ASYNC SERVICE & ENGINE
# Project: UR-Heart (Mindful Dating Platform)
# Target Environment: Render Free Web Service (Python 3.11+ / Async ASGI)
# Performance Goal: Sub-100ms P95 Latency under 512MB RAM Constraint

---

## 1. BACKEND ARCHITECTURE & DIRECTORY BLUEPRINT

FastAPI backend strictly modular, asynchronous aur layered architecture follow karta hai. Router endpoints business logic se isolated rahenge, aur database queries repository/service layers ke through execute hongi. Har file strictly 250 lines ke limit ke andar rahegi taaki Antigravity codebase ko spaghetti na banaye.

### 1.1 Production Directory Layout

```text
backend/
├── app/
│   ├── api/
│   │   ├── dependencies.py          # Auth, DB, and Header injection
│   │   └── v1/
│   │       ├── router.py            # Aggregated APIRouter
│   │       └── endpoints/
│   │           ├── health.py        # UptimeRobot 5-min keep-alive ping
│   │           ├── auth.py          # Session sync & token exchange
│   │           ├── users.py         # Profile builder & Persona endpoints
│   │           ├── discovery.py     # Feed card deck & Ignored profiles
│   │           ├── swipes.py        # Swipe actions (Like, Pass, Superlike)
│   │           ├── matches.py       # Active matches & unmatch triggers
│   │           ├── chat.py          # REST message history & WebSocket gate
│   │           ├── ads.py           # SSV multi-network verification
│   │           ├── kyc.py           # Groq AI live video verification trigger
│   │           └── legal.py         # DPDP Sec 11/12/14 & IT Rules dossiers[cite: 13]
│   ├── core/
│   │   ├── config.py                # Pydantic BaseSettings (.env loader)
│   │   ├── database.py              # Async SQLAlchemy engine with NullPool
│   │   ├── exceptions.py            # Global custom exception classes
│   │   └── security.py              # Firebase JWT decoder & token utilities[cite: 1]
│   ├── models/
│   │   └── domain/                  # SQLAlchemy ORM mapped entities[cite: 1]
│   │       ├── user.py
│   │       ├── swipe.py
│   │       ├── match.py
│   │       ├── message.py
│   │       ├── ad_transaction.py
│   │       ├── whatsapp_token.py
│   │       └── legal.py
│   ├── schemas/                     # Pydantic v2 validation contracts[cite: 1]
│   │   ├── auth_schema.py
│   │   ├── user_schema.py
│   │   ├── discovery_schema.py
│   │   ├── chat_schema.py
│   │   ├── ad_schema.py
│   │   └── legal_schema.py
│   ├── services/                    # Domain logic & third-party integrations[cite: 1]
│   │   ├── chat_manager.py          # WebSocket connection pool[cite: 1]
│   │   ├── chat_sanitizer.py        # NLP regex contact detector[cite: 1]
│   │   ├── photo_moderator.py       # OpenCV QR & OCR scanner[cite: 1]
│   │   ├── groq_service.py          # Groq AI multimodal client
│   │   ├── reward_service.py        # AdMob ECDSA & HMAC SSV verifier[cite: 1]
│   │   └── storage_service.py       # Cloudflare R2 presigned URLs[cite: 1]
│   └── main.py                      # ASGI lifespan, CORS & middleware pipeline[cite: 1]
├── requirements.txt
├── Dockerfile
└── render.yaml
2. RENDER 512MB RAM SURVIVAL SPECIFICATIONS
Render free tier container sirf 512MB RAM provide karta hai. Agar Python process memory exceed karega to Linux kernel OOM (Out Of Memory) killer FastAPI process ko instantly terminate kar dega (Exit Code 137).

2.1 Memory Optimization Directives
Zero Multi-Processing: Render free tier par uvicorn app.main:app --workers 1 execute hoga. Multiple workers memory ko multiply kar dete hain, jisse single container crash ho jata hai.

Streaming & Ephemeral File Handling: Media upload (photos aur KYC videos) server disk par write nahi honge[cite: 1]. Files directly Cloudflare R2 presigned URLs ke zariye stream hongi[cite: 1].

Lazy Module Imports: Heavy modules jaise cv2 (OpenCV) aur pytesseract sirf unhi endpoints mein instantiate honge jahan KYC ya image validation required ho[cite: 1].

Single Shared HTTPX AsyncClient: Multiple API calls (Groq AI, AdMob Verifier Keys, Firebase) ke liye ek centralized singleton httpx.AsyncClient lifespan context ke zariye share hoga taaki socket descriptors exhaust na hon[cite: 1].

3. CORE CONFIGURATION & ENVIRONMENT (app/core/config.py)
Python


import os
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # App Information
    APP_NAME: str = "UR-Heart API"
    ENVIRONMENT: str = "production"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"

    # Supabase PgBouncer Pooler (Port 6543)
    SUPABASE_PGBOUNCER_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SUPABASE_URL: str

    # Cloudflare R2 Configuration[cite: 1]
    CLOUDFLARE_ACCOUNT_ID: str
    R2_ACCESS_KEY_ID: str
    R2_SECRET_ACCESS_KEY: str
    R2_BUCKET_NAME: str = "ur-heart-media"

    # Groq Cloud API Engine
    GROQ_API_KEY: str

    # Ad Network Security Secrets[cite: 1]
    APPLOVIN_SDK_KEY: str = ""
    ADMOB_VERIFIER_KEYS_URL: str = "[https://www.gstatic.com/admob/reward/verifier-keys.json](https://www.gstatic.com/admob/reward/verifier-keys.json)"

    # Firebase Admin Configuration
    FIREBASE_PROJECT_ID: str

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

@lru_cache()
def get_settings() -> Settings:
    return Settings()
4. LIFESPAN MANAGEMENT & MAIN APP (app/main.py)
Lifespan context manager server start aur shutdown ke dauran connections ko cleanly initialize aur release karta hai.

Python


import os
import httpx
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings
from app.core.exceptions import SanctuaryException
from app.api.v1.router import api_v1_router
from app.services.rate_limiter import RateLimitMiddleware[cite: 1]

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: Shared HTTP client allocate karein
    app.state.http_client = httpx.AsyncClient(timeout=15.0)
    yield
    # SHUTDOWN: Gracefully close HTTP client
    await app.state.http_client.aclose()

app = FastAPI(
    title=settings.APP_NAME,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json" if settings.DEBUG else None,
    docs_url=f"{settings.API_V1_PREFIX}/docs" if settings.DEBUG else None,
    redoc_url=None,
    lifespan=lifespan
)

# Cross-Origin Isolation for Mobile App
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Sliding Window Rate-Limiter Middleware[cite: 1]
app.add_middleware(RateLimitMiddleware, swipe_limit=30, window_seconds=60)[cite: 1]

# Global Centralized Exception Handler
@app.exception_handler(SanctuaryException)
async def sanctuary_exception_handler(request: Request, exc: SanctuaryException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error_code": exc.error_code,
            "message": exc.detail
        }
    )

# Register Main API v1 Router
app.include_router(api_v1_router, prefix=settings.API_V1_PREFIX)
5. DEPENDENCY INJECTION ENGINE (app/api/dependencies.py)
FastAPI dependencies incoming requests ko secure karti hain aur database sessions provide karti hain[cite: 1].

Python


from uuid import UUID
from typing import AsyncGenerator
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.exceptions import AuthenticationFailedException, ProfileNotFoundException
from app.core.security import verify_firebase_token[cite: 1]
from app.models.domain.user import User[cite: 1]

async def get_current_user(
    authorization: str = Header(..., description="Bearer <Firebase_ID_Token>"),
    x_installation_uuid: str = Header(..., description="App-scoped Linux sandbox UUID")[cite: 1],
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Validates Firebase Auth JWT token, verifies installation UUID,[cite: 1]
    and retrieves active user from Supabase.
    """
    if not authorization.startswith("Bearer "):
        raise AuthenticationFailedException("Invalid authorization header format.")

    token = authorization.split("Bearer ")[1].strip()
    auth_payload = await verify_firebase_token(token)
    auth_id = auth_payload.get("uid")

    if not auth_id:
        raise AuthenticationFailedException("Token verification failed.")

    # Fetch User Record from Supabase
    stmt = select(User).where(User.auth_id == UUID(auth_id), User.deleted_at.is_(None))[cite: 1]
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise ProfileNotFoundException("User profile not found or permanently erased.")

    # Zero-on-Delete Re-install Detection[cite: 1]
    incoming_uuid = x_installation_uuid.strip()
    if user.last_installation_uuid is None:
        user.last_installation_uuid = incoming_uuid
        await db.commit()
    elif user.last_installation_uuid != incoming_uuid:
        # Reset streaks and rewards upon app reinstallation[cite: 1]
        user.streak_count = 0
        user.reward_balance = 0
        user.last_installation_uuid = incoming_uuid
        await db.commit()
        await db.refresh(user)

    return user
6. CENTRALIZED EXCEPTIONS SYSTEM (app/core/exceptions.py)
Application-wide errors standard contract maintain karte hain taaki Flutter client graceful dialogs display kar sake:

Python


from fastapi import status

class SanctuaryException(Exception):
    def __init__(self, detail: str, error_code: str, status_code: int = status.HTTP_400_BAD_REQUEST):
        self.detail = detail
        self.error_code = error_code
        self.status_code = status_code
        super().__init__(detail)

class AuthenticationFailedException(SanctuaryException):
    def __init__(self, detail: str = "Authentication failed."):
        super().__init__(detail=detail, error_code="AUTH_FAILED", status_code=status.HTTP_401_UNAUTHORIZED)

class ProfileNotFoundException(SanctuaryException):
    def __init__(self, detail: str = "Sanctuary profile does not exist."):
        super().__init__(detail=detail, error_code="PROFILE_NOT_FOUND", status_code=status.HTTP_404_NOT_FOUND)

class PolicyViolationException(SanctuaryException):
    def __init__(self, detail: str):
        super().__init__(detail=detail, error_code="POLICY_VIOLATION", status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)

class RateLimitException(SanctuaryException):
    def __init__(self, detail: str = "Rate limit exceeded. Please be mindful."):
        super().__init__(detail=detail, error_code="RATE_LIMIT_EXCEEDED", status_code=status.HTTP_429_TOO_MANY_REQUESTS)
7. PYDANTIC V2 CONTRACT SCHEMAS
7.1 User Persona Schema (app/schemas/user_schema.py)
Python


from pydantic import BaseModel, Field, ConfigDict
from datetime import date
from typing import Optional, List
from uuid import UUID

class UserCreateRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=60)
    dob: date
    gender: str = Field(..., pattern="^(Woman|Man|Non-Binary|Other)$")
    interested_in: str = Field(..., pattern="^(Men|Women|Everyone)$")
    whatsapp_encrypted: str
    location_name: str = Field(default="Bandra West, Mumbai", max_length=100)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    bio: Optional[str] = Field(default="", max_length=500)
    profession: Optional[str] = Field(default="", max_length=80)
    education: Optional[str] = Field(default="", max_length=100)
    preferred_age_min: int = Field(default=18, ge=18, le=100)
    preferred_age_max: int = Field(default=35, ge=18, le=100)

class UserProfileResponse(BaseModel):
    id: UUID
    full_name: str
    age: int
    gender: str
    interested_in: str
    location_name: str
    bio: str
    profession: str
    education: str
    preferred_age_min: int
    preferred_age_max: int
    streak_count: int
    reward_balance: int
    swipes_remaining: int
    direct_letters_count: int
    kyc_status: bool
    is_incognito: bool
    discreet_mode: bool
    night_slumber: bool
    photo_urls: List[str]

    model_config = ConfigDict(from_attributes=True)
7.2 Swipe Request & Feed Match Schema (app/schemas/discovery_schema.py)
Python


from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional

class SwipeActionRequest(BaseModel):
    target_id: UUID
    swipe_type: str = Field(..., pattern="^(like|pass|superlike)$")[cite: 1]

class SwipeActionResponse(BaseModel):
    status: str
    is_match: bool
    match_id: Optional[UUID] = None
    swipes_remaining: int
8. SLIDING WINDOW RATE LIMITER (app/services/rate_limiter.py)
Render ke single instance environment mein IP aur User-based spam ko neutralize karne ke liye in-memory sliding window rate limiter[cite: 1]:

Python


import time
from collections import defaultdict
from fastapi import Request, Response, status
from starlette.middleware.base import BaseHTTPMiddleware

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, swipe_limit: int = 30, window_seconds: int = 60):
        super().__init__(app)
        self.swipe_limit = swipe_limit
        self.window_seconds = window_seconds
        self.request_history = defaultdict(list)

    async def dispatch(self, request: Request, call_next) -> Response:
        path = request.url.path
        # Restrict swipe actions, messages, and KYC submissions[cite: 1]
        if path.startswith("/api/v1/swipes") or path.startswith("/api/v1/chat/send"):
            client_ip = request.client.host if request.client else "unknown"
            current_time = time.time()

            # Clean entries outside window[cite: 1]
            self.request_history[client_ip] = [
                t for t in self.request_history[client_ip]
                if current_time - t < self.window_seconds
            ]

            if len(self.request_history[client_ip]) >= self.swipe_limit:
                return Response(
                    content='{"success": false, "error_code": "RATE_LIMIT_EXCEEDED", "message": "Too many requests. Please slow down."}',
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    headers={"Retry-After": str(self.window_seconds)},
                    media_type="application/json"
                )

            self.request_history[client_ip].append(current_time)

        return await call_next(request)
9. ANTIGRAVITY VERIFICATION & DEPLOYMENT CHECKLIST
Antigravity agent ko FastAPI layer build karte waqt ye checkmarks verify karne honge:

UptimeRobot Keep-Alive Endpoint:

Verify karein ki GET /api/v1/health 200 OK return karta hai aur 0 database queries trigger karta hai.

Clean Dependency Separation:

Endpoints direct SQLAlchemy models return nahi karenge; sabhi response objects Pydantic schemas ke through serialize honge[cite: 1].

No File System Writes:

Verify karein ki kisi bhi router mein open(), temporary disk caching, ya local file buffering na ho; sabhi operations RAM buffer aur Cloudflare R2 presigned URLs ke zariye hon[cite: 1].

Error Formatting Uniformity:

Sabhi error responses standard JSON schema ({ success: false, error_code: str, message: str }) follow karein.

