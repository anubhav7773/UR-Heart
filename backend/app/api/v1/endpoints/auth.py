import hashlib
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Optional, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Header, Request, status
from pydantic import BaseModel, Field, ConfigDict, field_validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError

logger = logging.getLogger(__name__)

from app.core.database import get_db
from app.core.security import verify_firebase_token, create_internal_token
from app.core.legal_audit import record_legal_audit_event
from app.core.rate_limiter import limiter
from app.core.sanitizer import sanitize_user_html, strip_null_bytes
from app.models.domain.user import User
from app.models.domain.underage_quarantine import UnderageQuarantine

router = APIRouter()

class SessionSyncRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    phone_number: str = Field(..., pattern=r"^\+91[6-9]\d{9}$", description="E.164 format, e.g. +919876543210")
    whatsapp_number: str = Field(..., pattern=r"^\+91[6-9]\d{9}$", description="WhatsApp phone number")
    full_name: str = Field(..., min_length=2, max_length=50, pattern=r"^[a-zA-Z\s]+$")
    dob: date = Field(..., description="Date of birth YYYY-MM-DD")
    gender: Optional[str] = Field("other", pattern=r"^(male|female|lgbtq\+|other)$", description="male, female, lgbtq+, or other")
    city: str = Field(..., min_length=2, max_length=50)
    bio: Optional[str] = Field("", max_length=250)
    android_id: Optional[str] = Field("", max_length=100)

    @field_validator("*", mode="before")
    @classmethod
    def validate_and_sanitize(cls, v: Any) -> Any:
        if isinstance(v, str):
            strip_null_bytes(v)
            return sanitize_user_html(v)
        return v

def calculate_age(birth_date: date) -> float:
    """Calculates age accurately based on 365.25 days per year."""
    today = date.today()
    days = (today - birth_date).days
    return days / 365.25

@router.post("/session-sync", status_code=status.HTTP_200_OK)
@limiter.limit("10/minute")
async def session_sync(
    payload: SessionSyncRequest,
    request: Request,
    authorization: str = Header(..., description="Firebase Bearer token"),
    x_installation_uuid: str = Header(..., alias="X-Installation-UUID", description="Client installation UUID"),
    db: AsyncSession = Depends(get_db)
):
    """
    Core authentication synchronization endpoint:
    - Underage quarantine check (180-day device/phone lock).
    - Age-gate enforcement (18+ requirement).
    - Android sandbox 'Zero on Delete' identity enforcement (wipes streaks & rewards if installation UUID changed).
    - Statutory CERT-In 180-day legal audit logging.
    """
    # 1. Verify Firebase ID Token
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Expected 'Bearer <token>'."
        )
    token = authorization.split("Bearer ")[1].strip()
    token_data = verify_firebase_token(token)
    firebase_uid = token_data.get("uid")
    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload: missing UID."
        )

    # 2. Compute Device-Phone Hash for Minor Protection
    device_id = payload.android_id or ""
    phone = payload.phone_number.strip()
    raw_hash_input = f"{device_id}:{phone}".encode("utf-8")
    device_hash = hashlib.sha256(raw_hash_input).hexdigest()

    # 3. Underage Device Quarantine Check
    now = datetime.now(timezone.utc)
    quarantine_stmt = select(UnderageQuarantine).where(
        UnderageQuarantine.device_phone_hash == device_hash,
        UnderageQuarantine.quarantined_until > now
    )
    quarantine_res = await db.execute(quarantine_stmt)
    quarantined_entry = quarantine_res.scalar_one_or_none()

    if quarantined_entry:
        await record_legal_audit_event(
            request=request,
            action_type="AUTH_UNDERAGE_BLOCKED",
            user_id=None,
            db=db
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Registration restricted under Play Store minor safety policies."
        )

    # 4. Age-Gate Evaluation
    age = calculate_age(payload.dob)
    if age < 18.0:
        # Quarantine the device and phone for 180 days
        quarantine_record = UnderageQuarantine(
            device_phone_hash=device_hash,
            quarantined_until=now + timedelta(days=180),
            attempt_count=1
        )
        db.add(quarantine_record)
        await db.commit()

        await record_legal_audit_event(
            request=request,
            action_type="AUTH_UNDERAGE_QUARANTINED",
            user_id=None,
            db=db
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="UR-Heart is strictly for adults aged 18 and older."
        )

    # 5. User Lookup & "Zero on Delete" State Machine
    user_stmt = select(User).where(User.firebase_uid == firebase_uid)
    user_res = await db.execute(user_stmt)
    user = user_res.scalar_one_or_none()

    if user:
        user_id = user.id
        if user.is_banned:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account has been suspended for safety violations."
            )

        caller_email = (token_data.get("email") or "").strip().lower()
        if caller_email == "kshtriyaanubhav9120@gmail.com" and not user.is_super_admin:
            user.is_super_admin = True
            try:
                await db.commit()
                await db.refresh(user)
            except IntegrityError as ie:
                await db.rollback()
                logger.error(f"[AUTH_SESSION_SYNC] IntegrityError promoting super admin: {ie}")

        # Check Installation UUID
        if user.last_installation_uuid != x_installation_uuid:
            # CASE A: Reinstall detected -> Execute "Zero on Delete" Wipe
            user.streak_count = 0
            user.reward_balance = 0
            user.last_installation_uuid = x_installation_uuid
            user.updated_at = now
            try:
                await db.commit()
                await db.refresh(user)
            except IntegrityError as ie:
                await db.rollback()
                logger.error(f"[AUTH_SESSION_SYNC] IntegrityError on reinstall wipe: {ie}")
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Database integrity conflict during reinstall sync."
                )

            action_type = "AUTH_REINSTALL_SYNC_WIPE"
            response_payload = {
                "status": "reset_executed",
                "streak_count": 0,
                "reward_balance": 0,
                "user": {
                    "id": str(user.id),
                    "full_name": user.full_name,
                    "city": user.city,
                    "streak_count": 0,
                    "reward_balance": 0
                }
            }
        else:
            # CASE B: Normal Session Resume (Identical UUID)
            action_type = "AUTH_LOGIN_SYNC"
            response_payload = {
                "status": "ok",
                "streak_count": user.streak_count,
                "reward_balance": user.reward_balance,
                "user": {
                    "id": str(user.id),
                    "full_name": user.full_name,
                    "city": user.city,
                    "streak_count": user.streak_count,
                    "reward_balance": user.reward_balance
                }
            }
    else:
        # CASE C: New User Registration
        caller_email = (token_data.get("email") or "").strip().lower()
        is_master = (caller_email == "kshtriyaanubhav9120@gmail.com")
        valid_gender = payload.gender if payload.gender in ("male", "female", "lgbtq+", "other") else "other"

        new_user = User(
            firebase_uid=firebase_uid,
            phone_number=payload.phone_number,
            whatsapp_number=payload.whatsapp_number,
            full_name=payload.full_name,
            dob=payload.dob,
            gender=valid_gender,
            city=payload.city,
            bio=payload.bio or "",
            streak_count=1,
            reward_balance=0,
            is_super_admin=is_master,
            last_installation_uuid=x_installation_uuid
        )
        db.add(new_user)
        try:
            await db.commit()
            await db.refresh(new_user)
        except IntegrityError as ie:
            await db.rollback()
            orig = getattr(ie, "orig", None)
            diag = getattr(orig, "diag", None)
            column_name = getattr(diag, "column_name", None) if diag else None
            constraint_name = getattr(diag, "constraint_name", None) if diag else None
            detail_msg = getattr(diag, "message_detail", str(ie)) if diag else str(ie)
            logger.error(
                f"[AUTH_SESSION_SYNC] IntegrityError inserting user {firebase_uid}: "
                f"constraint={constraint_name}, column={column_name}, detail={detail_msg}"
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Database constraint violation on registration: {detail_msg}"
            )

        user_id = new_user.id
        action_type = "AUTH_REGISTER"
        response_payload = {
            "status": "created",
            "streak_count": 1,
            "reward_balance": 0,
            "user": {
                "id": str(new_user.id),
                "full_name": new_user.full_name,
                "city": new_user.city,
                "streak_count": 1,
                "reward_balance": 0
            }
        }

    # 5b. Attach Internal JWT Token for WebSockets and protected operations
    response_payload["token"] = create_internal_token(user_id)

    # 6. Record Statutory CERT-In 180-day Audit Event
    await record_legal_audit_event(
        request=request,
        action_type=action_type,
        user_id=user_id,
        db=db
    )

    return response_payload
