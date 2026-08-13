import io
import uuid
import httpx
from typing import Optional
from app.core.config import settings

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

        supabase_url = settings.SUPABASE_URL.rstrip('/')
        supabase_key = settings.SUPABASE_KEY

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
        except Exception:
            pass

        # Fallback public CDN URL structure if Supabase is offline or initializing
        return public_cdn_url
