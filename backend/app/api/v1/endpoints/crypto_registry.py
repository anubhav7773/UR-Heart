import base64
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User

router = APIRouter(prefix="/crypto", tags=["Cryptographic Key Registry"])


class KeyRotationRequest(BaseModel):
    public_key_base64: str = Field(min_length=40, max_length=64)


@router.post("/rotate-key", status_code=status.HTTP_200_OK)
async def register_rotated_encryption_key(
    payload: KeyRotationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DIS-05 Fix: Stores the user's authentic X25519 public key in Supabase.
    Allows peers in mutual matches to derive shared secrets for E2EE messaging.
    """
    try:
        # Validate that the string is genuine Base64
        key_bytes = base64.b64decode(payload.public_key_base64)
        if len(key_bytes) != 32:
            raise HTTPException(status_code=422, detail="Invalid X25519 public key length (must be 32 bytes).")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=422, detail="Malformed Base64 public key payload.")

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(public_encryption_key=payload.public_key_base64)
    )
    await db.commit()

    return {
        "status": "success",
        "message": "Authentic X25519 public key registered in sanctuary vault.",
        "key_fingerprint": payload.public_key_base64[:8] + "..."
    }
