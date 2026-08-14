import uuid
from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import admin_required
from app.models.orm import User, VerificationStatusEnum as ORMVerificationStatusEnum
from app.models.schemas import APIResponse

router = APIRouter(prefix="/admin", tags=["Admin Verification & Moderation"])


def calculate_age(born: Optional[date]) -> Optional[int]:
    if not born:
        return None
    today = date.today()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


@router.get("/verifications/pending")
async def get_pending_verifications(
    admin_id: str = Depends(admin_required),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns all users with pending video verifications awaiting admin review.
    """
    stmt = (
        select(User)
        .where(
            User.verification_video_url.is_not(None),
            User.is_verified == False,
        )
        .order_by(User.created_at.desc())
    )
    res = await db.execute(stmt)
    users = res.scalars().all()

    pending_list = []
    for user in users:
        pending_list.append({
            "id": str(user.id),
            "name": user.full_name or "UR Heart User",
            "email": user.email or "",
            "phone_number": user.phone_number or "",
            "age": calculate_age(user.dob),
            "area_name": user.area_name or "",
            "verification_video_url": user.verification_video_url,
            "verification_status": user.verification_status.value if user.verification_status else "PENDING",
            "created_at": user.created_at.isoformat() if user.created_at else "",
        })

    return APIResponse(
        success=True,
        message=f"Retrieved {len(pending_list)} pending verifications.",
        data=pending_list
    )


@router.post("/verifications/{user_id}/review")
async def review_user_verification(
    user_id: str,
    payload: dict = Body(...),
    admin_id: str = Depends(admin_required),
    db: AsyncSession = Depends(get_db)
):
    """
    Admin review endpoint to approve or reject a user's verification video.
    Accepts: {"status": "approved" | "rejected"} or {"action": "APPROVE" | "REJECT"}.
    """
    try:
        target_uuid = uuid.UUID(user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID format."
        )

    res = await db.execute(select(User).where(User.id == target_uuid))
    user = res.scalars().first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )

    review_action = str(payload.get("status") or payload.get("action") or "").strip().lower()

    if review_action in ("approved", "approve"):
        user.is_verified = True
        user.verification_status = ORMVerificationStatusEnum.APPROVED
        msg = f"Verification approved for {user.full_name or 'user'}."
    elif review_action in ("rejected", "reject"):
        user.is_verified = False
        user.verification_status = ORMVerificationStatusEnum.REJECTED
        user.verification_video_url = None
        msg = f"Verification rejected for {user.full_name or 'user'}."
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Review status must be 'approved' or 'rejected'."
        )

    try:
        db.add(user)
        await db.commit()
        await db.refresh(user)
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error updating verification: {e}"
        )

    return {
        "status": "success",
        "message": msg,
        "is_verified": user.is_verified,
        "verification_status": user.verification_status.value
    }
