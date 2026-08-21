import io
import uuid
import logging
import httpx
from typing import Optional
from fastapi import HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


class StorageEngineService:
    @staticmethod
    async def upload_profile_photo(file_bytes: bytes, filename: str) -> str:
        """
        Uploads image file bytes to Supabase Storage bucket ('profile-photos')
        and returns the public CDN URL. Converts image to compressed WebP if Pillow is installed.
        """
        return await StorageEngineService._upload_to_bucket(file_bytes, filename, bucket_name="profile-photos")

    @staticmethod
    async def upload_chat_media(file_bytes: bytes, filename: str) -> str:
        """
        Uploads image/video file bytes to Supabase Storage bucket ('chat-media')
        and returns the public CDN URL.
        """
        return await StorageEngineService._upload_to_bucket(file_bytes, filename, bucket_name="chat-media")

    @staticmethod
    async def _upload_to_bucket(file_bytes: bytes, filename: str, bucket_name: str) -> str:
        target_filename = f"{uuid.uuid4().hex}_{filename.split('/')[-1].split('\\')[-1]}"
        if not target_filename.endswith(".webp"):
            target_filename = f"{target_filename.rsplit('.', 1)[0]}.webp"

        processed_bytes = file_bytes
        content_type = "image/webp"

        # Compress image to WebP format if Pillow is available
        if HAS_PIL and len(file_bytes) > 0:
            try:
                img = Image.open(io.BytesIO(file_bytes))
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGBA")
                else:
                    img = img.convert("RGB")

                output = io.BytesIO()
                img.save(output, format="WEBP", quality=85, optimize=True)
                processed_bytes = output.getvalue()
            except Exception:
                processed_bytes = file_bytes

        supabase_url = (settings.SUPABASE_URL or "").rstrip('/')
        supabase_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY or ""

        if not supabase_url or not supabase_key:
            logger.error("Supabase Storage credentials not configured (SUPABASE_URL / key missing).")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Storage upload failed"
            )

        # Supabase Storage REST API URL for specified bucket
        upload_url = f"{supabase_url}/storage/v1/object/{bucket_name}/{target_filename}"
        public_cdn_url = f"{supabase_url}/storage/v1/object/public/{bucket_name}/{target_filename}"

        headers = {
            "Authorization": f"Bearer {supabase_key}",
            "apikey": supabase_key,
            "Content-Type": content_type,
            "x-upsert": "true",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                res = await client.post(upload_url, content=processed_bytes, headers=headers)
                if res.status_code in (200, 201):
                    return public_cdn_url
                else:
                    logger.error(
                        "Supabase storage upload failed with HTTP %s: %s (bucket: %s, file: %s)",
                        res.status_code,
                        res.text,
                        bucket_name,
                        target_filename
                    )
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Storage upload failed"
                    )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(
                "Exception during Supabase storage upload to bucket '%s' for file '%s': %s",
                bucket_name,
                target_filename,
                str(e),
                exc_info=True
            )
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Storage upload failed"
            )

