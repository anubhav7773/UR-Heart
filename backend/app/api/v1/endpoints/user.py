from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update, select

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.domain.user import User
from app.models.schemas.user import UserProfileUpdateRequest, UserProfileResponse

router = APIRouter()

@router.get("/profile", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def get_profile(
    current_user: User = Depends(get_current_user)
):
    """
    Returns the authenticated user's profile.
    Extracts identity strictly from verified server-side JWT (prevents IDOR).
    """
    return current_user

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

    # Add updated_at timestamp
    update_data["updated_at"] = datetime.now(timezone.utc)

    # 100% Parameterized SQLAlchemy 2.0 ORM update
    stmt = (
        update(User)
        .where(User.id == current_user.id)
        .values(**update_data)
        .execution_options(synchronize_session="fetch")
    )
    await db.execute(stmt)
    await db.commit()

    # Refresh and return updated record
    res = await db.execute(select(User).where(User.id == current_user.id))
    updated_user = res.scalar_one()
    return updated_user
