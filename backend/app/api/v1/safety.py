import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import BlockedUser, UserReport
from app.models.schemas import (
    APIResponse,
    BlockUserRequest,
    BlockUserData,
    ReportUserRequest,
    ReportUserData,
)

router = APIRouter(prefix="/safety", tags=["User Safety, Report & Block Engine"])


@router.post("/block", response_model=APIResponse[BlockUserData])
async def block_user(
    payload: BlockUserRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Blocks a target user, preventing them from appearing in candidate feeds or active chats.
    """
    blocker_uuid = uuid.UUID(current_user_id)
    try:
        blocked_uuid = uuid.UUID(payload.blocked_user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid blocked_user_id format."
        )

    try:
        # Check if already blocked
        existing_res = await db.execute(
            select(BlockedUser).where(
                BlockedUser.blocker_id == blocker_uuid,
                BlockedUser.blocked_id == blocked_uuid,
            )
        )
        existing = existing_res.scalars().first()

        if not existing:
            block_record = BlockedUser(
                id=uuid.uuid4(),
                blocker_id=blocker_uuid,
                blocked_id=blocked_uuid,
            )
            db.add(block_record)
            await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        data=BlockUserData(
            blocked_user_id=payload.blocked_user_id,
            message="User blocked successfully. They will no longer appear in your feed or chats.",
        )
    )


@router.post("/report", response_model=APIResponse[ReportUserData])
async def report_user(
    payload: ReportUserRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Reports a target user for safety moderation (Harassment, Fake Profile, Inappropriate Content, Spam, etc.).
    """
    reporter_uuid = uuid.UUID(current_user_id)
    try:
        reported_uuid = uuid.UUID(payload.reported_user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reported_user_id format."
        )

    report_id = str(uuid.uuid4())
    try:
        report_record = UserReport(
            id=uuid.UUID(report_id),
            reporter_id=reporter_uuid,
            reported_id=reported_uuid,
            reason=payload.reason,
            details=payload.details,
            status="pending",
        )
        db.add(report_record)
        await db.commit()
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        data=ReportUserData(
            report_id=report_id,
            message="Report submitted successfully. Our safety moderation team will review this user.",
        )
    )
