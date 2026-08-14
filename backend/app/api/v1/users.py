import uuid

from fastapi import APIRouter, Body, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import User
from app.models.schemas import APIResponse

router = APIRouter(prefix="/users", tags=["User Location"])


@router.post("/fcm-token")
@router.put("/fcm-token")
async def update_fcm_token(
    payload: dict = Body(...),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Persists the authenticated device's FCM push notification token to the database.
    Accepts either {"fcm_token": "..."} or {"token": "..."} in JSON body.
    """
    token = str(payload.get("fcm_token") or payload.get("token") or "").strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="fcm_token is required.")

    try:
        user_id = uuid.UUID(current_user_id)
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalars().first()
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found.")
        user.fcm_token = token
        db.add(user)
        await db.commit()
        await db.refresh(user)
        print(f"[FCM_SAVE] Successfully saved token for user {user.id}: {token[:15]}...")
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        print(f"[FCM_SAVE] ERROR saving FCM token for user {current_user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save FCM token.")

    return APIResponse(success=True, message="FCM token updated successfully.", data={"fcm_token": token})


@router.post("/location")
@router.put("/location")
async def update_user_location(
    payload: dict,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Persist the authenticated device's latest live GPS coordinates."""
    lat = payload.get("latitude", payload.get("lat"))
    lng = payload.get("longitude", payload.get("lng"))
    if lat is None or lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="latitude and longitude are required.",
        )

    try:
        latitude, longitude = float(lat), float(lng)
        if not -90.0 <= latitude <= 90.0 or not -180.0 <= longitude <= 180.0:
            raise ValueError("Coordinates are outside valid GPS bounds.")
        user_id = uuid.UUID(current_user_id)
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalars().first()
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found.")
        user.latitude = latitude
        user.longitude = longitude
        await db.commit()
    except HTTPException:
        raise
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid GPS coordinates.")
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unable to save GPS location.")

    return APIResponse(
        success=True,
        message="Device GPS location updated successfully.",
        data={"latitude": latitude, "longitude": longitude},
    )
