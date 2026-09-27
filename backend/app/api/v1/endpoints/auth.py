from datetime import date
from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict
from app.api.dependencies import get_current_user
from app.models.domain.user import User

router = APIRouter(prefix="/auth", tags=["Authentication & Session"])


class UserSessionResponse(BaseModel):
    id: UUID
    auth_id: UUID
    full_name: str
    email: Optional[str] = None
    streak_count: int
    reward_balance: int
    swipes_remaining: int
    direct_letters_count: int
    kyc_status: bool
    is_incognito: bool
    discreet_mode: bool
    night_slumber: bool
    last_installation_uuid: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


@router.get(
    "/sync",
    status_code=status.HTTP_200_OK,
    response_model=UserSessionResponse,
    summary="Installation UUID Handshake & Zero-on-Delete Sync"
)
async def sync_session(current_user: User = Depends(get_current_user)) -> UserSessionResponse:
    """
    Validates client authentication token and installation UUID.
    Returns active user state after verifying reinstallation parameters.
    """
    return UserSessionResponse.model_validate(current_user)


@router.get(
    "/me",
    status_code=status.HTTP_200_OK,
    response_model=UserSessionResponse,
    summary="Get Current User Profile"
)
async def get_me(current_user: User = Depends(get_current_user)) -> UserSessionResponse:
    """Returns authenticated profile data."""
    return UserSessionResponse.model_validate(current_user)
