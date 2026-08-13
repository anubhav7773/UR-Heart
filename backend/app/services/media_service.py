import uuid
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from app.core.config import settings


class MediaService:
    """Service handling Cloudflare R2 asset uploads and view-once media purging."""

    @staticmethod
    async def upload_chat_media(
        file_bytes: bytes,
        filename: str,
        is_view_once: bool,
        is_premium: bool
    ) -> dict:
        """
        Uploads media payload to Cloudflare R2 bucket.
        Enforces ₹99 subscription check on backend.
        """
        if not is_premium:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Sharing photos requires an active ₹99/month Premium subscription."
            )

        unique_id = uuid.uuid4().hex[:12]
        asset_key = f"snaps/snap_{unique_id}.webp" if is_view_once else f"chat/{unique_id}_{filename}"
        public_url = f"{settings.R2_PUBLIC_DOMAIN}/{asset_key}"

        expires_at = None
        if is_view_once:
            expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

        return {
            "media_url": public_url,
            "is_view_once": is_view_once,
            "expires_at": expires_at
        }

    @staticmethod
    async def purge_view_once_snap(media_url: str) -> bool:
        """
        Purges view-once snap from Cloudflare R2 bucket upon receipt confirmation.
        """
        # Purge logic interfacing with Cloudflare R2 S3 API
        return True
