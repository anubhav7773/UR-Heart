import logging
from typing import Optional
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.domain.user import User
from app.services.data_incinerator_service import DataIncineratorService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Account Governance & Shredding"])


class IncinerateAccountRequest(BaseModel):
    confirmation_token: str = Field(..., pattern=r"^ERASE$")
    reason: Optional[str] = Field(default="user_requested_erasure", max_length=100)


@router.delete("/incinerate-account", status_code=status.HTTP_200_OK)
async def incinerate_account_irrevocably(
    payload: IncinerateAccountRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    DPDP ACT 2023 SECTION 12: Irrevocable Account Incinerator.
    Executes atomic cascading deletion across:
    1. Firebase Authentication Console.
    2. Supabase Storage (all moments, avatars, KYC videos, audio bios).
    3. Supabase Auth (auth.users administrative record).
    4. PostgreSQL database (public.users and foreign key cascades).
    """
    audit = await DataIncineratorService.incinerate_user(
        email=current_user.email,
        user_id=current_user.id,
        auth_id=current_user.auth_id,
        db=db,
    )
    logger.info(f"[ACCOUNT INCINERATOR] Completed account incineration for {current_user.id}: {audit}")

    return {
        "status": "incinerated",
        "compliance": "DPDP Act 2023 Section 12",
        "message": "All personal data, authentication credentials, storage media, and encryption keys have been permanently shredded.",
        "audit": audit
    }
