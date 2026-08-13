import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import User
from app.models.schemas import APIResponse

router = APIRouter(prefix="/users", tags=["User Location"])


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
