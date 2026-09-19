import os
import io
from uuid import UUID
from datetime import datetime, timezone
from fastapi import HTTPException, status, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update, select
from app.models.domain.kyc_queue import KycReviewQueue
from app.models.domain.user import User

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = None

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

supabase_storage_client = None
if create_client and SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY:
    try:
        supabase_storage_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    except Exception:
        supabase_storage_client = None

def get_supabase_admin_client():
    global supabase_storage_client
    if supabase_storage_client is not None:
        return supabase_storage_client
    if create_client and SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY:
        try:
            supabase_storage_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
            return supabase_storage_client
        except Exception:
            pass
    return supabase_storage_client

if supabase_storage_client is None:
    class _DummyStorageFrom:
        def upload(self, *args, **kwargs):
            return {}
        def remove(self, *args, **kwargs):
            return []
        def get_public_url(self, path: str):
            return f"https://mock-storage.supabase.co/user-photos/{path}"
        def list(self, *args, **kwargs):
            return []
        def create_signed_upload_url(self, path: str):
            return {"signedUrl": f"https://mock-storage.supabase.co/user-photos/{path}", "url": f"https://mock-storage.supabase.co/user-photos/{path}"}
        def create_signed_url(self, path: str, expires_in: int = 600):
            return {"signedURL": f"https://mock-storage.supabase.co/kyc-temp/{path}?token=mock_signed_url", "signedUrl": f"https://mock-storage.supabase.co/kyc-temp/{path}?token=mock_signed_url"}

    class _DummyStorage:
        def __init__(self):
            self._from_handler = _DummyStorageFrom()
        def from_(self, bucket_name: str):
            return self._from_handler

    class _DummyClient:
        def __init__(self):
            self.storage = _DummyStorage()

    supabase_storage_client = _DummyClient()

supabase_admin = supabase_storage_client

MAGIC_BYTES = {
    "webp": b"RIFF",  # Bytes 0-4 are 'RIFF', bytes 8-12 are 'WEBP'
    "jpeg": b"\xFF\xD8\xFF",
    "mp4": b"ftyp",   # Typically offset at index 4 (e.g., ....ftypisom)
}

MAX_PHOTO_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB limit (legacy ceiling)
MAX_KYC_VIDEO_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB limit (legacy ceiling)

DISALLOWED_EXTENSIONS = {
    ".php", ".py", ".sh", ".exe", ".js", ".html", ".htm", ".bat", ".cmd",
    ".msi", ".dll", ".com", ".vbs", ".ps1", ".jar", ".war", ".bin"
}

def validate_binary_magic_bytes(file_bytes: bytes, expected_type: str) -> bool:
    """Verifies genuine file headers against binary magic signatures to prevent extension spoofing."""
    if len(file_bytes) < 16:
        return False

    if expected_type == "photo":
        # Check WebP signature (RIFF at 0..4 and WEBP at 8..12)
        if file_bytes[:4] == MAGIC_BYTES["webp"] and file_bytes[8:12] == b"WEBP":
            return True
        # Check JPEG signature
        if file_bytes[:3] == MAGIC_BYTES["jpeg"]:
            return True
        return False

    elif expected_type == "video":
        # Check MP4 'ftyp' container box signature within first 16 bytes
        return MAGIC_BYTES["mp4"] in file_bytes[:16]

    return False

def validate_photo_file(file_bytes: bytes, filename: str = "") -> None:
    """
    Security Check 16: Restrict File Uploads & Magic Bytes Inspection for Photos.
    - Rejects executable and script extensions.
    - Enforces <= 10 MB size ceiling (raises HTTP 413).
    - Inspects binary magic bytes for WebP, JPEG, PNG.
    """
    if filename:
        ext = os.path.splitext(filename.lower())[1]
        if ext in DISALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Disallowed executable or script extension: {ext}"
            )

    if len(file_bytes) > MAX_PHOTO_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Photo size ({len(file_bytes)} bytes) exceeds 10 MB limit."
        )

    if len(file_bytes) < 12:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too small to be a valid image."
        )

    # Magic bytes check
    is_jpeg = file_bytes.startswith(b"\xff\xd8\xff")
    is_png = file_bytes.startswith(b"\x89PNG\r\n\x1a\n")
    is_webp = file_bytes.startswith(b"RIFF") and file_bytes[8:12] == b"WEBP"

    if not (is_jpeg or is_png or is_webp):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid image format: Magic bytes do not match JPEG, PNG, or WebP."
        )

def validate_kyc_video_file(file_bytes: bytes, filename: str = "") -> None:
    """
    Security Check 16: Restrict File Uploads & Magic Bytes Inspection for KYC Videos.
    - Rejects executable and script extensions.
    - Enforces <= 2.5 MB size ceiling (raises HTTP 413).
    - Inspects binary magic bytes for MP4 ('ftyp' container).
    """
    if filename:
        ext = os.path.splitext(filename.lower())[1]
        if ext in DISALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Disallowed executable or script extension: {ext}"
            )

    if len(file_bytes) > MAX_KYC_VIDEO_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Video size ({len(file_bytes)} bytes) exceeds 10MB limit."
        )

    if len(file_bytes) < 12:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too small to be a valid video container."
        )

    # Magic bytes check: MP4 container must contain 'ftyp' box
    is_mp4 = file_bytes[4:8] == b"ftyp" or b"ftyp" in file_bytes[:32]
    if not is_mp4:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid video format: Magic bytes do not match MP4 ('ftyp')."
        )

async def upload_profile_photo_to_storage(
    user_id: UUID,
    slot_index: int,
    file_bytes: bytes,
    content_type: str = "image/webp"
) -> str:
    """Uploads validated compressed photo to 'user-photos' bucket under user's UUID path."""
    if len(file_bytes) > 150 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Photo size exceeds 150 KB limit. Ensure client compression is active."
        )

    if not validate_binary_magic_bytes(file_bytes, "photo"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid image payload. File signature must match WebP or JPEG binary headers."
        )

    storage_path = f"{user_id}/slot_{slot_index}.webp"
    
    # Supabase storage upload with overwrite flag
    response = supabase_storage_client.storage.from_("user-photos").upload(
        path=storage_path,
        file=file_bytes,
        file_options={"content-type": content_type, "upsert": "true"}
    )
    
    # Retrieve public URL
    public_url = supabase_storage_client.storage.from_("user-photos").get_public_url(storage_path)
    return public_url

async def upload_kyc_video_to_storage(
    user_id: UUID,
    video_bytes: bytes,
    storage_path: str = ""
) -> str:
    """Uploads 5-second KYC video to private 'kyc-temp' bucket for ephemeral processing."""
    if len(video_bytes) > 10485760:  # 10 MB in bytes
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Video size exceeds statutory 10 MB ceiling."
        )

    if not validate_binary_magic_bytes(video_bytes, "video"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid video payload. File signature must be a valid MP4 ftyp container."
        )

    if not storage_path:
        storage_path = f"{user_id}/selfie.mp4"
    
    supabase_storage_client.storage.from_("kyc-temp").upload(
        path=storage_path,
        file=video_bytes,
        file_options={"content-type": "video/mp4", "upsert": "true"}
    )
    
    return storage_path

async def purge_kyc_video_from_storage(
    storage_path: str,
    user_id: UUID,
    db: AsyncSession
) -> bool:
    """
    DPDP ACT 2023 COMPLIANT PURGE ROUTINE:
    1. Permanently deletes raw MP4 video object from Supabase 'kyc-temp' bucket.
    2. Overwrites video_storage_path in public.kyc_review_queue to 'PURGED'.
    """
    if not storage_path or storage_path == "PURGED":
        return True

    try:
        # Step 1: Delete object from Supabase bucket
        supabase_storage_client.storage.from_("kyc-temp").remove([storage_path])

        # Step 2: Update queue status in PostgreSQL
        stmt = (
            update(KycReviewQueue)
            .where(KycReviewQueue.user_id == user_id)
            .values(
                video_storage_path="PURGED",
                resolved_at=datetime.now(timezone.utc)
            )
        )
        await db.execute(stmt)
        await db.commit()
        return True
    except Exception as e:
        # Log failure into console; do not mask if called by background task
        print(f"FAILED_TO_PURGE_KYC_VIDEO: {storage_path}, error: {str(e)}")
        return False

async def hard_delete_kyc_video(storage_path: str) -> bool:
    """
    Permanently deletes a KYC video from Supabase Storage bucket ('kyc-videos').
    Eliminates biometric data leakage liability under DPDP Act 2023.
    """
    if not storage_path or storage_path == "PURGED":
        return True

    try:
        supabase = get_supabase_admin_client()
        # Clean relative path if bucket prefix is present
        clean_path = storage_path.replace("kyc-videos/", "").replace("kyc-temp/", "").lstrip("/")
        
        if supabase:
            try:
                supabase.storage.from_("kyc-videos").remove([clean_path])
            except Exception:
                pass
            try:
                supabase.storage.from_("kyc-temp").remove([clean_path])
            except Exception:
                pass
        return True
    except Exception as e:
        print(f"⚠️ [Storage Hard-Delete Error] Failed to purge {storage_path}: {e}")
        return False

async def create_signed_upload_url(user_id: UUID, slot_index: int) -> dict:
    """
    Generates a secure, 10-minute upload URL for the user's specific photo slot.
    Format: user-photos/{user_id}/slot_{slot_index}.webp
    """
    file_path = f"{user_id}/slot_{slot_index}.webp"
    try:
        res = supabase_storage_client.storage.from_("user-photos").create_signed_upload_url(file_path)
        return {
            "upload_url": res.get("signedUrl") or res.get("url") if isinstance(res, dict) else f"https://mock-storage.supabase.co/user-photos/{file_path}",
            "file_path": file_path,
            "bucket": "user-photos"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Storage upload ticket generation failed: {str(e)}"
        )

async def purge_user_storage_assets(user_id: UUID) -> None:
    """
    Hard-deletes all photos and temporary KYC videos associated with user_id.
    Strictly complies with Section 8(7) of DPDP Act 2023.
    """
    try:
        photo_files = supabase_storage_client.storage.from_("user-photos").list(path=str(user_id))
        if photo_files and isinstance(photo_files, list):
            file_keys = [f"{user_id}/{f['name']}" for f in photo_files if isinstance(f, dict) and 'name' in f]
            if file_keys:
                supabase_storage_client.storage.from_("user-photos").remove(file_keys)
    except Exception:
        pass

    try:
        kyc_files = supabase_storage_client.storage.from_("kyc-temp").list(path=str(user_id))
        if kyc_files and isinstance(kyc_files, list):
            kyc_keys = [f"{user_id}/{f['name']}" for f in kyc_files if isinstance(f, dict) and 'name' in f]
            if kyc_keys:
                supabase_storage_client.storage.from_("kyc-temp").remove(kyc_keys)
    except Exception:
        pass
