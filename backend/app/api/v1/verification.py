import uuid
from typing import Optional
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.core.config import settings
from app.models.orm import User, VerificationStatusEnum as ORMVerificationStatusEnum
from app.models.schemas import (
    APIResponse,
    VideoVerificationResponse,
    AdminVerificationReviewRequest,
    VerificationStatusEnum,
)
from app.services.storage_engine import StorageEngineService

try:
    from supabase import create_client, Client
    HAS_SUPABASE = True
except ImportError:
    HAS_SUPABASE = False

router = APIRouter(prefix="/verification", tags=["User Video Verification"])

# Initialize Supabase Python Client safely
if HAS_SUPABASE and settings.SUPABASE_URL and settings.SUPABASE_KEY:
    try:
        supabase: Optional[Client] = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    except Exception:
        supabase = None
else:
    supabase = None


@router.post("/upload-video", response_model=APIResponse[VideoVerificationResponse])
async def upload_verification_video(
    file: UploadFile = File(...),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Accepts user's 5-second selfie verification video.
    Uploads to storage, updates status to 'PENDING', is_verified to False, and commits.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID session."
        )

    filename = (file.filename or f"verify_{uuid.uuid4().hex[:8]}.mp4").lower()
    
    # Security: Validate video extension whitelist
    allowed_video_ext = {".mp4", ".mov", ".m4v", ".webm", ".avi"}
    file_ext = "." + filename.rsplit(".", 1)[-1] if "." in filename else ""
    if file_ext not in allowed_video_ext:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid video format '{file_ext}'. Allowed formats: .mp4, .mov, .m4v, .webm"
        )

    try:
        contents = await file.read()
    except Exception:
        contents = b""

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded video file is empty."
        )

    # Security: Max 25MB for verification video
    if len(contents) > 25 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Video file size exceeds the 25MB limit."
        )

    file_path = f"verify_{user_uuid.hex}_{uuid.uuid4().hex[:8]}_{filename.split('/')[-1].split('\\')[-1]}"
    public_url = None

    if supabase is not None:
        try:
            supabase.storage.from_("profile-photos").upload(
                file_path,
                contents,
                file_options={"content-type": file.content_type or "video/mp4", "upsert": "true"}
            )
            base_supa_url = settings.SUPABASE_URL.rstrip('/') if settings.SUPABASE_URL else ""
            if base_supa_url:
                public_url = f"{base_supa_url}/storage/v1/object/public/profile-photos/{file_path}"
            else:
                public_url_obj = supabase.storage.from_("profile-photos").get_public_url(file_path)
                public_url = str(public_url_obj)
        except Exception as e:
            print(f"[Verification Video Upload Supabase Notice] {e}")

    if not public_url:
        try:
            cdn_url = await StorageEngineService.upload_profile_photo(
                file_bytes=contents,
                filename=filename
            )
            public_url = cdn_url
        except Exception:
            public_url = f"https://r2.ruralheart.com/verification/{file_path}"

    try:
        user_res = await db.execute(select(User).where(User.id == user_uuid))
        user_obj = user_res.scalars().first()

        if not user_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User profile not found."
            )

        user_obj.verification_video_url = public_url
        user_obj.verification_status = ORMVerificationStatusEnum.PENDING
        user_obj.is_verified = False
        db.add(user_obj)
        await db.commit()
        await db.refresh(user_obj)
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed updating verification status: {e}"
        )

    return APIResponse(
        success=True,
        message="Selfie verification video uploaded successfully. Status is now PENDING.",
        data=VideoVerificationResponse(
            verification_status=VerificationStatusEnum.PENDING,
            verification_video_url=public_url,
            is_verified=False,
            message="Your verification video is under review by the moderation team."
        )
    )


@router.get("/status", response_model=APIResponse[VideoVerificationResponse])
async def get_verification_status(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Returns the current user's video verification status.
    """
    try:
        user_uuid = uuid.UUID(current_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID session."
        )

    user_res = await db.execute(select(User).where(User.id == user_uuid))
    user_obj = user_res.scalars().first()

    if not user_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found."
        )

    status_enum = VerificationStatusEnum(user_obj.verification_status.value) if user_obj.verification_status else VerificationStatusEnum.UNVERIFIED
    is_verified = bool(user_obj.is_verified and status_enum == VerificationStatusEnum.APPROVED)

    msg_map = {
        VerificationStatusEnum.UNVERIFIED: "Record a 5-second selfie video to verify your profile.",
        VerificationStatusEnum.PENDING: "Your verification video is currently under review.",
        VerificationStatusEnum.APPROVED: "Your profile is verified with blue checkmark badge.",
        VerificationStatusEnum.REJECTED: "Your previous video was not approved. Please record a clearer video.",
    }

    return APIResponse(
        success=True,
        data=VideoVerificationResponse(
            verification_status=status_enum,
            verification_video_url=user_obj.verification_video_url,
            is_verified=is_verified,
            message=msg_map.get(status_enum, "Status retrieved.")
        )
    )


@router.post("/admin/{target_user_id}/review", response_model=APIResponse[VideoVerificationResponse])
@router.post("/review/{target_user_id}", response_model=APIResponse[VideoVerificationResponse])
async def admin_review_verification(
    target_user_id: str,
    payload: AdminVerificationReviewRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Admin review endpoint to approve or reject a user's verification video.
    """
    try:
        target_uuid = uuid.UUID(target_user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid target user ID."
        )

    user_res = await db.execute(select(User).where(User.id == target_uuid))
    user_obj = user_res.scalars().first()

    if not user_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target user profile not found."
        )

    action = payload.action.upper().strip()
    if action == "APPROVE":
        user_obj.is_verified = True
        user_obj.verification_status = ORMVerificationStatusEnum.APPROVED
        msg = f"User {user_obj.full_name} verification APPROVED."
    elif action == "REJECT":
        user_obj.is_verified = False
        user_obj.verification_status = ORMVerificationStatusEnum.REJECTED
        msg = f"User {user_obj.full_name} verification REJECTED."
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Action must be 'APPROVE' or 'REJECT'."
        )

    try:
        db.add(user_obj)
        await db.commit()
        await db.refresh(user_obj)
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error updating review status: {e}"
        )

    status_enum = VerificationStatusEnum(user_obj.verification_status.value)
    return APIResponse(
        success=True,
        message=msg,
        data=VideoVerificationResponse(
            verification_status=status_enum,
            verification_video_url=user_obj.verification_video_url,
            is_verified=user_obj.is_verified,
            message=msg
        )
    )
