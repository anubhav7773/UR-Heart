from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User

router = APIRouter(prefix="/user", tags=["User Preferences & Privacy Flags"])


class PreferencesUpdateRequest(BaseModel):
    is_incognito: Optional[bool] = None
    discreet_mode: Optional[bool] = None
    push_notifications_enabled: Optional[bool] = None


@router.put("/preferences", status_code=status.HTTP_200_OK)
async def update_user_preferences(
    payload: PreferencesUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-04 Fix: Persists Ghost Cloak incognito, discreet lock-screen notifications,
    and push notification flags directly into Supabase.
    """
    update_data = payload.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(status_code=400, detail="Empty preferences payload.")

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(**update_data)
    )
    await db.commit()

    return {
        "status": "success",
        "updated_preferences": update_data
    }
