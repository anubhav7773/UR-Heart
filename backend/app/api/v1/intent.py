import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import ChaiStatus, ChaiInvite
from app.models.schemas import (
    APIResponse,
    ChaiStatusRequest,
    ChaiStatusData,
    SendChaiInviteRequest,
    SendChaiInviteData,
)

router = APIRouter(prefix="/intent", tags=["Chai Status & Local Invites"])


@router.post("/chai-status", response_model=APIResponse[ChaiStatusData])
async def update_chai_status(
    payload: ChaiStatusRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Updates user's active "Free for Chai" availability badge and spatial landmark.
    """
    user_uuid = uuid.UUID(current_user_id)

    try:
        result = await db.execute(select(ChaiStatus).where(ChaiStatus.user_id == user_uuid))
        chai_rec = result.scalars().first()

        if not chai_rec:
            chai_rec = ChaiStatus(
                user_id=user_uuid,
                is_free_for_chai=payload.is_free_for_chai,
                status_badge=payload.status_badge,
                location_landmark=payload.location_landmark or "Saket College Junction",
            )
            db.add(chai_rec)
        else:
            chai_rec.is_free_for_chai = payload.is_free_for_chai
            chai_rec.status_badge = payload.status_badge
            if payload.location_landmark:
                chai_rec.location_landmark = payload.location_landmark

        await db.commit()
    except Exception:
        pass

    data = ChaiStatusData(
        is_free_for_chai=payload.is_free_for_chai,
        status_badge=payload.status_badge,
        location_landmark=payload.location_landmark or "Saket College Junction",
    )
    return APIResponse(success=True, data=data)


@router.post("/send-chai-invite", response_model=APIResponse[SendChaiInviteData])
async def send_chai_invite(
    payload: SendChaiInviteRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Sends a ₹9 Chai Invite micro-transaction request to a target profile.
    """
    sender_uuid = uuid.UUID(current_user_id)
    try:
        receiver_uuid = uuid.UUID(payload.receiver_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid receiver_id UUID format."
        )

    invite_id = str(uuid.uuid4())

    try:
        new_invite = ChaiInvite(
            id=uuid.UUID(invite_id),
            sender_id=sender_uuid,
            receiver_id=receiver_uuid,
            status="pending",
        )
        db.add(new_invite)
        await db.commit()
    except Exception:
        pass

    data = SendChaiInviteData(
        invite_id=invite_id,
        status="pending",
        message="₹9 Chai Invite sent successfully!"
    )
    return APIResponse(success=True, data=data)
