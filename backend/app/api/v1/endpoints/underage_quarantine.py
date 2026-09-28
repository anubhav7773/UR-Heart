import hashlib
from datetime import datetime, date, timedelta
from fastapi import APIRouter, HTTPException, status, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.domain.legal import UnderageQuarantineRegistry

router = APIRouter(prefix="/auth", tags=["Underage Quarantine Protection"])


class QuarantineRegistrationPayload(BaseModel):
    device_hardware_fingerprint: str = Field(..., min_length=16, max_length=128)
    attempted_dob: date


@router.post("/quarantine-device", status_code=status.HTTP_201_CREATED)
async def register_underage_hardware_quarantine(
    payload: QuarantineRegistrationPayload,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    DPDP ACT 2023 SECTION 9: Anti-Bypass Hardware Quarantine.
    Locks device fingerprint for 180 days upon detection of minor input.
    """
    # 1. Calculate attempted age
    today = date.today()
    age = today.year - payload.attempted_dob.year - (
        (today.month, today.day) < (payload.attempted_dob.month, payload.attempted_dob.day)
    )

    if age >= 18:
        raise HTTPException(status_code=400, detail="Declared age satisfies adult threshold.")

    # 2. Compute canonical device hash
    client_ip = request.client.host if request.client else "unknown"
    ip_sub = ".".join(client_ip.split(".")[:2])  # Subnet only for privacy compliance
    raw_seed = f"{payload.device_hardware_fingerprint}:{ip_sub}"
    device_hash = hashlib.sha256(raw_seed.encode("utf-8")).hexdigest()

    # 3. Check existing quarantine
    stmt = select(UnderageQuarantineRegistry).where(UnderageQuarantineRegistry.device_hash == device_hash)
    existing = (await db.execute(stmt)).scalar_one_or_none()

    if existing:
        existing.quarantine_until = datetime.utcnow() + timedelta(days=180)
        existing.attempt_metadata = {"attempted_age": age, "recorded_at": datetime.utcnow().isoformat()}
    else:
        entry = UnderageQuarantineRegistry(
            device_hash=device_hash,
            attempted_dob=payload.attempted_dob,
            quarantine_until=datetime.utcnow() + timedelta(days=180),
            attempt_metadata={"attempted_age": age, "recorded_at": datetime.utcnow().isoformat()}
        )
        db.add(entry)

    await db.commit()
    return {
        "status": "quarantined",
        "lockout_days": 180,
        "detail": "Underage access restricted under DPDP Act 2023 Section 9. Hardware identifier quarantined."
    }


@router.get("/check-quarantine/{device_fingerprint}", status_code=status.HTTP_200_OK)
async def verify_device_quarantine_status(
    device_fingerprint: str,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """Called on app launch to intercept blacklisted hardware even after storage wipes."""
    client_ip = request.client.host if request.client else "unknown"
    ip_sub = ".".join(client_ip.split(".")[:2])
    raw_seed = f"{device_fingerprint}:{ip_sub}"
    device_hash = hashlib.sha256(raw_seed.encode("utf-8")).hexdigest()

    stmt = select(UnderageQuarantineRegistry).where(
        UnderageQuarantineRegistry.device_hash == device_hash,
        UnderageQuarantineRegistry.quarantine_until > datetime.utcnow()
    )
    quarantined = (await db.execute(stmt)).scalar_one_or_none()

    if quarantined:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Device currently quarantined under DPDP Act Section 9 (Child Data Protection)."
        )

    return {"is_quarantined": False}
