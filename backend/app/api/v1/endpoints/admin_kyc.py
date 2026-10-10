import html
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional
import urllib.parse
from uuid import UUID
import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from fastapi.responses import RedirectResponse
from jose import jwt
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.config import get_settings
from app.core.database import get_db
from app.core.exceptions import ForbiddenException
from app.core.security import JWT_SECRET_KEY, verify_firebase_jwt
from app.models.domain.kyc_escalation import AdminKycEscalation
from app.models.domain.user import User
from app.services.kyc_purge import purge_ephemeral_kyc_video

logger = logging.getLogger("admin_kyc")
router = APIRouter(prefix="/admin/kyc", tags=["Superadmin KYC Sentinel"])
settings = get_settings()


def get_admin_emails() -> set[str]:
    emails = set()
    if getattr(settings, "SUPERADMIN_EMAIL", None):
        emails.add(settings.SUPERADMIN_EMAIL.strip().lower())
    if getattr(settings, "SUPERADMIN_CANONICAL_EMAIL", None):
        emails.add(settings.SUPERADMIN_CANONICAL_EMAIL.strip().lower())
    canonical_env = (os.getenv("SUPERADMIN_CANONICAL_EMAIL") or "").strip().lower()
    if canonical_env:
        emails.add(canonical_env)
    admin_env = (os.getenv("SUPERADMIN_EMAIL") or "").strip().lower()
    if admin_env:
        emails.add(admin_env)
    emails.discard("")
    return emails


def verify_superadmin_guard(user: User = Depends(get_current_user)) -> User:
    admin_emails = get_admin_emails()
    user_email = (getattr(user, "email", "") or "").strip().lower()
    is_whitelisted = bool(admin_emails and user_email in admin_emails)
    is_superadmin = (getattr(user, "role", "user") == "superadmin")
    if not (is_whitelisted or is_superadmin):
        raise ForbiddenException("Access Denied: You do not possess Sanctuary Sovereign privileges. Access strictly restricted to verified superadministrators.")
    return user


async def verify_admin_media_token(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> str:
    """
    Validates token for media streaming strictly from the Authorization: Bearer header.
    Query-string credentials (?token=...) are disabled to prevent leakage in server access logs and browser history.
    Strictly verifies email against sovereign whitelist (no role bypass).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required to preview biometric evidence."
        )

    token_str = authorization.split("Bearer ")[1].strip()
    if not token_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required to preview biometric evidence."
        )

    admin_emails = get_admin_emails()

    # 1. Internal HS256 JWT Token check (strictly validate email against admin whitelist)
    try:
        payload = jwt.decode(
            token_str,
            JWT_SECRET_KEY,
            algorithms=["HS256"],
            options={"verify_signature": True, "verify_exp": True}
        )
        email = (payload.get("email") or "").strip().lower()
        if email and email in admin_emails:
            return email
    except Exception:
        pass

    # 2. Firebase / Google RS256 token verification (strictly validate email against admin whitelist)
    try:
        auth_payload = await verify_firebase_jwt(token_str)
        email = (auth_payload.get("email") or "").strip().lower()
        if email and email in admin_emails:
            return email

        # Check user record in DB if email wasn't in claims directly
        sub_id = auth_payload.get("sub") or auth_payload.get("user_id") or auth_payload.get("uid")
        if sub_id:
            from app.core.security import resolve_auth_uuid
            auth_uuid = resolve_auth_uuid(sub_id)
            user_res = await db.execute(select(User).where(User.auth_id == auth_uuid))
            u = user_res.scalar_one_or_none()
            if u:
                u_email = (u.email or "").strip().lower()
                if u_email and u_email in admin_emails:
                    return u_email
    except Exception:
        pass

    raise ForbiddenException("Access Denied: Sovereign Sentinel authorization required to stream biometric media.")


def _generate_placeholder_svg(label: str, subtext: str = "") -> Response:
    """
    Renders a graceful SVG placeholder with XML/HTML escaping on all injected text
    to prevent Stored XSS inside SVG vector contexts.
    """
    safe_label = html.escape(str(label), quote=True)
    safe_subtext = html.escape(str(subtext), quote=True)

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="600" height="750" viewBox="0 0 600 750">
  <defs>
    <radialGradient id="bg" cx="50%" cy="40%" r="60%">
      <stop offset="0%" stop-color="#1c162b"/>
      <stop offset="100%" stop-color="#0a0712"/>
    </radialGradient>
  </defs>
  <rect width="600" height="750" fill="url(#bg)"/>
  <rect x="20" y="20" width="560" height="710" rx="16" fill="none" stroke="#e0a96d" stroke-width="2" stroke-dasharray="6,6" opacity="0.4"/>
  <circle cx="300" cy="270" r="64" fill="none" stroke="#e0a96d" stroke-width="3" opacity="0.8"/>
  <circle cx="300" cy="245" r="28" fill="#e0a96d" opacity="0.8"/>
  <path d="M255 315 Q300 280 345 315" fill="none" stroke="#e0a96d" stroke-width="3" opacity="0.8"/>
  <text x="300" y="410" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="22" font-weight="bold" fill="#f5f0eb" text-anchor="middle">{safe_label}</text>
  <text x="300" y="445" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="14" fill="#a89f91" text-anchor="middle">{safe_subtext}</text>
  <rect x="180" y="490" width="240" height="38" rx="19" fill="rgba(224,169,109,0.15)" stroke="#e0a96d" stroke-width="1"/>
  <text x="300" y="514" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="13" font-weight="600" fill="#e0a96d" text-anchor="middle">UR-HEART SENTINEL</text>
</svg>"""
    return Response(
        content=svg,
        media_type="image/svg+xml",
        headers={"Cache-Control": "no-cache, no-store, must-revalidate"}
    )


class KycResolutionRequest(BaseModel):
    escalation_id: int
    user_id: UUID
    action: str  # "approve" or "reject"
    admin_notes: str = ""


class AdminKycQueueItem(BaseModel):
    id: int
    user_id: UUID
    user_name: str = "Seeker"
    user_email: str = ""
    declared_dob: str
    declared_age: int
    groq_match_score: int
    groq_reasoning: str
    anchor_photo_url: str
    kyc_video_url: str
    kyc_selfie_url: str = ""
    profile_photo_1_url: str = ""
    profile_photo_2_url: str = ""
    all_profile_photos: List[str] = []
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


@router.get("/escalations", response_model=List[AdminKycQueueItem], status_code=status.HTTP_200_OK)
@router.get("/pending-queue", response_model=List[AdminKycQueueItem], status_code=status.HTTP_200_OK)
async def list_pending_escalations(
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db)
):
    """
    Lists pending KYC escalations for human Sentinel review.
    Enriched with user name, email, and dynamic biometric photo mapping URLs.
    Strictly locked to asiverticals@gmail.com.
    """
    stmt = (
        select(AdminKycEscalation, User)
        .outerjoin(User, AdminKycEscalation.user_id == User.id)
        .where(AdminKycEscalation.status == "pending")
        .order_by(AdminKycEscalation.created_at.asc())
        .limit(30)
    )
    result = await db.execute(stmt)
    records = result.all()

    items = []
    for r, u in records:
        uid = r.user_id
        u_name = u.full_name if u else "Seeker"
        u_email = u.email if u else ""
        selfie_endpoint = f"/api/v1/admin/kyc/media/{uid}/selfie"
        p1_endpoint = f"/api/v1/admin/kyc/media/{uid}/profile_1"
        p2_endpoint = f"/api/v1/admin/kyc/media/{uid}/profile_2"

        collected_photos = []
        if u and u.avatar_url and str(u.avatar_url).strip():
            collected_photos.append(str(u.avatar_url).strip())
        if u and u.photos:
            for p in u.photos:
                p_str = str(p).strip() if p else ""
                if p_str and p_str not in collected_photos:
                    collected_photos.append(p_str)

        all_photos = [
            f"/api/v1/admin/kyc/media/{uid}/profile_{i + 1}"
            for i in range(max(1, len(collected_photos)))
        ]

        items.append(
            AdminKycQueueItem(
                id=r.id,
                user_id=r.user_id,
                user_name=u_name,
                user_email=u_email,
                declared_dob=r.declared_dob.isoformat() if hasattr(r.declared_dob, "isoformat") else str(r.declared_dob),
                declared_age=r.declared_age,
                groq_match_score=r.groq_match_score,
                groq_reasoning=r.groq_reasoning,
                anchor_photo_url=p1_endpoint,
                kyc_video_url=selfie_endpoint,
                kyc_selfie_url=selfie_endpoint,
                profile_photo_1_url=p1_endpoint,
                profile_photo_2_url=p2_endpoint,
                all_profile_photos=all_photos,
                status=r.status,
                created_at=r.created_at
            )
        )
    return items


@router.get("/media/{user_id}/{media_type}", summary="Stream KYC Biometric Media or Profile Photos for Admin Verification")
async def get_admin_kyc_media(
    user_id: UUID,
    media_type: str,
    request: Request,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Streams biometric media for Sentinel Desk inspection.
    media_type options:
    - 'selfie': The live KYC selfie snapshot taken during verification.
    - 'profile_{N}': The Nth Sanctuary profile photo (profile_1 for Avatar, profile_2 for Gallery Moment, etc.).
    """
    # 1. Authorize admin via Authorization header only
    await verify_admin_media_token(authorization=authorization, db=db)

    # 2. Case A: Live KYC Selfie
    if media_type == "selfie":
        # Check local ephemeral disk directory
        base_ephemeral = Path("uploads/kyc_ephemeral").resolve()
        try:
            local_selfie = (base_ephemeral / str(user_id) / "kyc_selfie.webp").resolve()
            if local_selfie.is_relative_to(base_ephemeral) and local_selfie.is_file():
                data = local_selfie.read_bytes()
                return Response(content=data, media_type="image/webp", headers={"Cache-Control": "private, max-age=60"})
        except Exception:
            pass

        # Check Supabase Storage if configured
        bucket = getattr(settings, "SUPABASE_STORAGE_BUCKET", None) or "ur-heart-media"
        if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
            try:
                storage_url = f"{settings.SUPABASE_URL}/storage/v1/object/{bucket}/kyc_ephemeral/{user_id}/kyc_selfie.webp"
                headers = {
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                }
                async with httpx.AsyncClient(timeout=8.0) as client:
                    resp = await client.get(storage_url, headers=headers)
                    if resp.status_code == 200 and resp.content:
                        content_type = resp.headers.get("content-type", "image/webp")
                        return Response(content=resp.content, media_type=content_type, headers={"Cache-Control": "private, max-age=60"})
            except Exception as s_err:
                logger.warning("Supabase storage selfie retrieval note: %s", s_err)

        # Graceful fallback: return sanitized SVG placeholder instead of 404
        return _generate_placeholder_svg("Live KYC Selfie", "Image not captured or purged per DPDP Act")

    # 3. Case B: Sanctuary Profile Photos
    stmt = select(User).where(User.id == user_id)
    user = (await db.execute(stmt)).scalar_one_or_none()

    if not user:
        return _generate_placeholder_svg("Profile Photo", "User sanctuary record not found")

    collected_photos = []
    if user.avatar_url and str(user.avatar_url).strip():
        collected_photos.append(str(user.avatar_url).strip())
    for p in (user.photos or []):
        p_clean = str(p).strip() if p else ""
        if p_clean and p_clean not in collected_photos:
            collected_photos.append(p_clean)

    target_photo = None
    slot_label = "Profile Photo"

    if media_type.startswith("profile_"):
        try:
            slot_num = int(media_type.split("_")[1])
        except (IndexError, ValueError):
            slot_num = 1
        slot_label = f"Profile Photo {slot_num} ({'Avatar' if slot_num == 1 else 'Gallery Moment'})"
        idx = slot_num - 1
        if 0 <= idx < len(collected_photos):
            target_photo = collected_photos[idx]
        elif len(collected_photos) == 1 and slot_num == 2:
            return _generate_placeholder_svg("Profile Photo 2 (Gallery Moment)", "Seeker has only uploaded 1 profile photo")
        else:
            return _generate_placeholder_svg(slot_label, f"No photo uploaded for slot {slot_num}")
    else:
        return _generate_placeholder_svg("Invalid Media Type", f"Unknown type: {media_type}")

    if not target_photo:
        return _generate_placeholder_svg(slot_label, "No photo uploaded in sanctuary")

    # Security check: Handle external URLs with strict domain whitelist to prevent Open Redirect / SSRF
    if target_photo.startswith("http://") or target_photo.startswith("https://"):
        parsed = urllib.parse.urlsplit(target_photo)
        hostname = (parsed.hostname or "").lower()

        trusted_hosts = {
            "res.cloudinary.com",
            "images.unsplash.com",
            "firebasestorage.googleapis.com",
        }
        if settings.SUPABASE_URL:
            supa_host = urllib.parse.urlsplit(settings.SUPABASE_URL).hostname
            if supa_host:
                trusted_hosts.add(supa_host.lower())
        if settings.CLOUDFLARE_ACCOUNT_ID:
            trusted_hosts.add(f"{settings.CLOUDFLARE_ACCOUNT_ID.lower()}.r2.cloudflarestorage.com")

        is_trusted = (
            parsed.scheme == "https"
            and (
                hostname in trusted_hosts
                or hostname.endswith(".supabase.co")
                or hostname.endswith(".supabase.in")
                or hostname.endswith(".firebasestorage.app")
            )
        )

        if is_trusted:
            return RedirectResponse(url=target_photo, status_code=status.HTTP_307_TEMPORARY_REDIRECT)
        else:
            logger.warning("Blocked redirect to untrusted external media domain: %s", hostname)
            return _generate_placeholder_svg(slot_label, "Untrusted external media domain blocked")

    # If it's a Supabase storage path (e.g. users/.../photos/slot_1.webp)
    bucket = getattr(settings, "SUPABASE_STORAGE_BUCKET", None) or "ur-heart-media"
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY and target_photo.startswith("users/"):
        storage_url = f"{settings.SUPABASE_URL}/storage/v1/object/public/{bucket}/{target_photo}"
        return RedirectResponse(url=storage_url, status_code=status.HTTP_307_TEMPORARY_REDIRECT)

    # Path traversal defense: strictly confine local file reads to uploads/
    base_uploads = Path("uploads").resolve()
    try:
        clean_rel = target_photo.lstrip("/\\")
        local_path = (base_uploads / clean_rel).resolve()
        if local_path.is_relative_to(base_uploads) and local_path.is_file():
            return Response(content=local_path.read_bytes(), media_type="image/webp")
    except Exception:
        pass

    return _generate_placeholder_svg(slot_label, "Photo pending cloud storage sync")


@router.post("/resolve", status_code=status.HTTP_200_OK)
async def resolve_kyc_ticket(
    payload: KycResolutionRequest,
    admin: User = Depends(verify_superadmin_guard),
    db: AsyncSession = Depends(get_db)
):
    """
    Resolves an escalated KYC ticket.
    Updates User.kyc_status, AdminKycEscalation status, notifies user via FCM, and triggers hard-purge of ephemeral video.
    """
    is_approved = (payload.action == "approve")

    # 1. Update User Profile Status
    await db.execute(
        update(User)
        .where(User.id == payload.user_id)
        .values(kyc_status=is_approved)
    )

    # 2. Update Escalation Queue
    await db.execute(
        update(AdminKycEscalation)
        .where(AdminKycEscalation.id == payload.escalation_id)
        .values(
            status="approved" if is_approved else "rejected",
            reviewed_at=datetime.now(timezone.utc),
            reviewed_by=getattr(admin, "email", None) or "superadmin"
        )
    )
    await db.commit()

    # 3. DPDP COMPLIANCE: Hard purge the ephemeral video and selfie immediately (<60s)
    purge_ephemeral_kyc_video(str(payload.user_id))

    # 4. Push FCM Notification to User
    try:
        from app.api.v1.endpoints.notifications import push_notification
        if is_approved:
            push_notification(
                user_id=str(payload.user_id),
                notif_type="kyc_approved",
                title="Identity Verified! 🛡️",
                body="Your biometric KYC verification has been granted by the Sentinel Desk. Sovereign Blue Crest unlocked!",
                data={"target_route": "/settings", "kyc_status": True}
            )
        else:
            push_notification(
                user_id=str(payload.user_id),
                notif_type="kyc_resubmit",
                title="KYC Verification Notice 🛡️",
                body="Your biometric verification was reviewed and could not be approved. Please resubmit clear portraits.",
                data={"target_route": "/settings", "kyc_status": False}
            )
    except Exception as notif_err:
        logger.warning("FCM notification post-resolution note: %s", notif_err)

    return {
        "status": "resolved",
        "user_id": payload.user_id,
        "kyc_status": is_approved
    }
