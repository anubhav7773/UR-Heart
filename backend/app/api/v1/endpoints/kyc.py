from uuid import UUID, uuid4
from typing import Optional
from fastapi import APIRouter, File, UploadFile, Header, Form, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.rate_limiter import limiter
from app.models.domain.user import User
from app.services.ai_kyc_service import process_video_kyc
from app.services.storage_service import validate_kyc_video_file

router = APIRouter()

MAX_VIDEO_SIZE_BYTES = 2500000  # 2.5 MB limit per Section 6 Infra Spec

@router.post("/submit-video", status_code=status.HTTP_200_OK)
@limiter.limit("3/hour")
async def submit_kyc_video(
    request: Request,
    file: UploadFile = File(...),
    user_id: Optional[UUID] = Form(None),
    user_name: Optional[str] = Form(None),
    user_city: Optional[str] = Form(None),
    x_consent_dpdp: Optional[str] = Header(None, alias="X-Consent-DPDP"),
    db: AsyncSession = Depends(get_db)
):
    """
    Submits a 5-second video KYC clip for AI automated verification.
    Enforces statutory DPDP consent header verification and file size ceiling.
    """
    # 1. Statutory DPDP Consent Verification
    if not x_consent_dpdp or x_consent_dpdp.strip().lower() != "true":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="DPDP consent notice must be affirmatively accepted via X-Consent-DPDP: true."
        )

    # 2. File Read, Magic Bytes, Extension & Size Check (< 2.5MB)
    file_bytes = await file.read()
    validate_kyc_video_file(file_bytes, filename=file.filename or "")

    # 3. User Identity Context Resolution
    resolved_user_id = user_id or uuid4()
    resolved_name = user_name or "Aman Gupta"
    resolved_city = user_city or "Lucknow"

    if user_id and db:
        try:
            stmt = select(User).where(User.id == user_id)
            res = await db.execute(stmt)
            user_record = res.scalar_one_or_none()
            if user_record:
                resolved_name = user_record.full_name
                resolved_city = user_record.city
        except Exception:
            pass

    # 4. Execute AI Verification Pipeline
    result = await process_video_kyc(
        user_id=resolved_user_id,
        file_bytes=file_bytes,
        user_name=resolved_name,
        user_city=resolved_city,
        db=db
    )

    return result
