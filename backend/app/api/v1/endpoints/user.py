from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, update, select, func

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.domain.user_photo import UserPhoto
from app.models.schemas.user import (
    UserProfileUpdateRequest,
    UserProfileResponse,
    UserProfileSetupRequest,
    DiscoveryProfileResponse,
)
from app.core.legal_audit import record_legal_audit_event

router = APIRouter()

# 1. Profile Retrieval Endpoint
@router.get("/me", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
@router.get("/profile", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the authenticated user's profile with photo count.
    Extracts identity strictly from verified server-side JWT (prevents IDOR).
    """
    photo_stmt = select(func.count(UserPhoto.id)).where(UserPhoto.user_id == current_user.id)
    photo_res = await db.execute(photo_stmt)
    photo_count = photo_res.scalar_one() or 0

    resp = UserProfileResponse.model_validate(current_user)
    resp.photo_count = photo_count
    return resp

# 2. Profile Update Endpoint
@router.patch("/profile", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def update_profile(
    payload: UserProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates the authenticated user's profile.
    - Locks record access: Strictly uses current_user.id from verified JWT (prevents IDOR).
    - Prevents mass assignment: UserProfileUpdateRequest forbids unknown/privileged fields (extra='forbid').
    - Executes 100% parameterized SQLAlchemy 2.0 update query.
    """
    update_data = payload.model_dump(exclude_unset=True)
    if not update_data:
        return current_user

    update_data["updated_at"] = datetime.now(timezone.utc)

    stmt = (
        update(User)
        .where(User.id == current_user.id)
        .values(**update_data)
        .execution_options(synchronize_session="fetch")
    )
    await db.execute(stmt)
    await db.commit()

    res = await db.execute(select(User).where(User.id == current_user.id))
    updated_user = res.scalar_one()
    return updated_user

# 3. Profile Setup Endpoint (Sub-Task A.4)
@router.post("/profile-setup", status_code=status.HTTP_200_OK)
async def setup_user_profile(
    payload: UserProfileSetupRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Saves user name, WhatsApp (+91), inclusive gender, and private GPS coordinates.
    Exact GPS coordinates are secured and never exposed to other clients.
    """
    stmt = (
        update(User)
        .where(User.id == current_user.id)
        .values(
            full_name=payload.full_name,
            whatsapp_number=payload.whatsapp_number,
            gender=payload.gender,
            city=payload.city,
            bio=payload.bio or "",
            latitude=payload.latitude,
            longitude=payload.longitude,
            detected_locality=payload.detected_locality
        )
    )
    await db.execute(stmt)
    await db.commit()

    # Log Profile Setup in statutory audit trail
    await record_legal_audit_event(
        request=request,
        action_type="USER_PROFILE_SETUP",
        user_id=current_user.id,
        db=db
    )

    return {
        "status": "success",
        "message": "Profile initialized successfully. Proceed to media KYC."
    }

# 4. Discovery Feed Endpoint with Relative Distance Badge (Sub-Task A.4)
@router.get("/feed", response_model=List[DiscoveryProfileResponse])
async def get_feed(
    lat: float = Query(..., ge=-90.0, le=90.0, description="Caller's current GPS Latitude"),
    lon: float = Query(..., ge=-180.0, le=180.0, description="Caller's current GPS Longitude"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches discovery feed ordered by proximity using the database spatial function.
    Returns relative distance badges (e.g. 'Nearby 12 km') without leaking exact coordinates.
    """
    sql = text("""
        SELECT * FROM public.get_discovery_feed(
            :current_user_id,
            :lat,
            :lon,
            :limit,
            :offset
        )
    """)
    
    result = await db.execute(
        sql,
        {
            "current_user_id": current_user.id,
            "lat": lat,
            "lon": lon,
            "limit": limit,
            "offset": offset
        }
    )
    rows = result.mappings().all()

    return [DiscoveryProfileResponse.from_row(dict(row)) for row in rows]


from pydantic import BaseModel, Field

class DeviceTokenRequest(BaseModel):
    fcm_token: str = Field(..., min_length=10, max_length=255)

@router.post("/device-token", status_code=status.HTTP_200_OK)
async def update_device_token(
    payload: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Registers or updates the user's FCM device token for WhatsApp-style push notifications.
    """
    current_user.fcm_token = payload.fcm_token
    await db.commit()
    return {"status": "success", "message": "Device token updated"}

