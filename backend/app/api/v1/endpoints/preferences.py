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
    is_photo_veiled: Optional[bool] = None
    discreet_mode: Optional[bool] = None
    push_notifications_enabled: Optional[bool] = None
    night_slumber: Optional[bool] = None


def _format_key_fingerprint(pub_key: Optional[str]) -> str:
    if not pub_key:
        return "X25519-INITIALIZING"
    clean = pub_key.strip()
    if len(clean) >= 12:
        return f"X25519-{clean[:6]}...{clean[-4:]}"
    return f"X25519-{clean}"


@router.get("/preferences", status_code=status.HTTP_200_OK)
async def get_user_preferences(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the authenticated user's current persistent privacy settings,
    including Ghost Cloak incognito status, Sacred Photo Veil, and active X25519 public key fingerprint.
    """
    return {
        "status": "success",
        "preferences": {
            "is_incognito": bool(current_user.is_incognito),
            "is_photo_veiled": bool(current_user.is_photo_veiled),
            "discreet_mode": bool(current_user.discreet_mode),
            "push_notifications_enabled": bool(current_user.push_notifications_enabled if current_user.push_notifications_enabled is not None else True),
            "night_slumber": bool(current_user.night_slumber),
            "public_encryption_key": current_user.public_encryption_key,
            "key_fingerprint": _format_key_fingerprint(current_user.public_encryption_key),
        }
    }


@router.put("/preferences", status_code=status.HTTP_200_OK)
async def update_user_preferences(
    payload: PreferencesUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-04 Fix: Persists Ghost Cloak incognito, Sacred Photo Veil, discreet lock-screen notifications,
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
    for k, v in update_data.items():
        setattr(current_user, k, v)

    await db.commit()

    return {
        "status": "success",
        "updated_preferences": update_data,
        "is_incognito": bool(current_user.is_incognito),
        "is_photo_veiled": bool(current_user.is_photo_veiled),
        "night_slumber": bool(current_user.night_slumber),
        "key_fingerprint": _format_key_fingerprint(current_user.public_encryption_key),
    }

