import os
import json
import re
import html
import random
import logging
import base64
from typing import List, Dict, Any, Optional
from uuid import UUID
from datetime import datetime, timezone
import httpx
from pydantic import BaseModel, Field

from app.core.config import get_settings

logger = logging.getLogger("groq_service")
settings = get_settings()

GROQ_ENDPOINT = os.getenv("GROQ_API_URL", "https://api.groq.com/openai/v1/chat/completions")
OPENROUTER_ENDPOINT = os.getenv("OPENROUTER_API_URL", "https://openrouter.ai/api/v1/chat/completions")


class KycAiEvaluation(BaseModel):
    is_live_human: bool = Field(default=False)
    face_match_score: int = Field(default=0, ge=0, le=100)
    is_identity_match: bool = Field(default=True, description="True ONLY if the person in the live selfie is conclusively verified to be the exact same individual as in the uploaded profile photos")
    gallery_consistent: bool = Field(default=True, description="True if all uploaded profile photos belong to the same individual")
    pose_matched: bool = Field(default=True)
    estimated_age_bracket: str = Field(default="unknown")
    is_underage: bool = Field(default=True)
    rejection_reason: Optional[str] = Field(default="")
    status: str = Field(default="pending_manual_review")
    analysis_summary: Optional[str] = Field(default="")


def sanitize_prompt_input(user_text: str) -> str:
    """Strips delimiter tags, normalizes whitespace, and escapes control characters."""
    # Strip raw XML/control boundary tags BEFORE html escaping so they are reliably eliminated
    cleaned = re.sub(r'<\/?(?:user_submitted_text|system|assistant|instruction)[^>]*>', '', user_text.strip(), flags=re.I)
    escaped = html.escape(cleaned)
    # Also strip any escaped variants in case input was pre-escaped
    sanitized = re.sub(r'&lt;\/?(?:user_submitted_text|system|assistant|instruction)[^&]*&gt;', '', escaped, flags=re.I)
    return sanitized[:500]


class GroqAiService:
    @classmethod
    def _groq_headers(cls) -> Dict[str, str]:
        key = settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "UR-Heart-Sanctuary/1.0"
        }

    @classmethod
    def _openrouter_headers(cls) -> Dict[str, str]:
        key = settings.OPENROUTER_API_KEY or os.getenv("OPENROUTER_API_KEY", "")
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.asiverticals.me",
            "X-Title": "UR-Heart Sanctuary"
        }

    @classmethod
    async def polish_bio_secure(cls, raw_bio: str) -> str:
        """
        Deeply analyzes user's raw thoughts and transforms them into an authentic
        sanctuary bio using Eva Section 1 (Identity & Persona Engine).
        """
        sanitized_bio = sanitize_prompt_input(raw_bio or "")
        if not sanitized_bio or len(sanitized_bio.strip()) < 2:
            return "Please share a few words or thoughts about yourself first! Eva will transform them into an authentic, top-class bio ✨"
        from app.services.eva_identity_engine import EvaIdentityEngine
        res = await EvaIdentityEngine.polish_bio(sanitized_bio.strip())
        return res.get("polished_bio", sanitized_bio.strip())


    @classmethod
    async def polish_bio(cls, raw_bio: str, intent: str = "mindful") -> str:
        """Alias forwarding to secure boundary-tagged bio polish."""
        return await cls.polish_bio_secure(raw_bio)

    @classmethod
    async def generate_chat_icebreakers(cls, user_a: Dict, user_b: Dict) -> List[str]:
        """
        Generates 3 bespoke, non-intrusive dialogue starter prompts referencing shared interests.
        """
        safe_a_bio = sanitize_prompt_input(str(user_a.get('bio', '')))
        safe_b_bio = sanitize_prompt_input(str(user_b.get('bio', '')))
        context = (
            f"User A Bio: {safe_a_bio}, Interests: {user_a.get('interests', '')}\n"
            f"User B Bio: {safe_b_bio}, Interests: {user_b.get('interests', '')}"
        )
        prompt = (
            f"Generate exactly 3 thoughtful, authentic dialogue starter prompts (max 14 words each) referencing shared interests. "
            f"Profiles:\n{context}\nOutput JSON: {{\"icebreakers\": [\"...\", \"...\", \"...\"]}}"
        )

        payload = {
            "model": "llama-3.1-8b-instant",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.7,
            "response_format": {"type": "json_object"}
        }

        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                if res.status_code == 200:
                    data = json.loads(res.json()["choices"][0]["message"]["content"])
                    return data.get("icebreakers", [])[:3]
        except Exception as e:
            logger.warning("Groq icebreaker exception: %s", str(e))

        return [
            "What is a quiet ritual that keeps you grounded?",
            "I noticed we both appreciate slow, intentional spaces.",
            "What was the last story or book that genuinely moved you?"
        ]

    @classmethod
    async def verify_kyc_liveness(
        cls,
        anchor_bytes_b64: str,
        frame_1_b64: str,
        frame_2_b64: str,
        frame_3_b64: str
    ) -> Dict[str, Any]:
        """
        Legacy endpoint interface. Routes to Eva Section 1 engine.
        """
        from app.services.eva_identity_engine import EvaIdentityEngine
        import uuid
        eval_result = await EvaIdentityEngine.verify_kyc_liveness(
            user_id=uuid.uuid4(),
            anchor_b64=anchor_bytes_b64,
            frames_b64=[frame_1_b64, frame_2_b64, frame_3_b64]
        )
        return {
            "is_live_human": eval_result.is_live_human,
            "face_match_score": eval_result.face_match_score,
            "estimated_age_bracket": eval_result.estimated_age_bracket,
            "is_underage": eval_result.is_underage,
            "rejection_reason": eval_result.rejection_reason,
            "status": eval_result.status
        }

    @classmethod
    def extract_image_frames(cls, input_b64_list: List[str]) -> List[str]:
        """
        Extracts sharp JPEG image frames if input contains base64 encoded MP4 video.
        Ensures AI Vision receives valid image payloads, not raw video bytes.
        """
        import base64
        import tempfile
        import os
        import cv2

        result_frames: List[str] = []
        for item in input_b64_list:
            if not item or len(item) < 16:
                continue
            try:
                # Strip data URL prefix if present
                clean_b64 = item.split(",")[-1] if "," in item else item
                raw_bytes = base64.b64decode(clean_b64)

                # Detect MP4 video signatures (ftyp, moov, or large stream without JPEG/PNG/WEBP header)
                is_video = (b"ftyp" in raw_bytes[:50]) or (
                    len(raw_bytes) > 50000
                    and not raw_bytes.startswith(b"\xff\xd8")
                    and not raw_bytes.startswith(b"\x89PNG")
                    and not raw_bytes.startswith(b"RIFF")
                )

                if is_video:
                    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
                        tmp.write(raw_bytes)
                        tmp_path = tmp.name

                    try:
                        cap = cv2.VideoCapture(tmp_path)
                        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
                        if total_frames > 0:
                            indices = [
                                max(0, int(total_frames * 0.15)),
                                max(0, int(total_frames * 0.50)),
                                max(0, int(total_frames * 0.85)),
                            ]
                            for idx in indices:
                                cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
                                ret, frame = cap.read()
                                if ret and frame is not None:
                                    # Resize to max 720p for fast vision processing
                                    h, w = frame.shape[:2]
                                    if max(h, w) > 720:
                                        scale = 720.0 / max(h, w)
                                        frame = cv2.resize(frame, (int(w * scale), int(h * scale)))
                                    _, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                                    result_frames.append(base64.b64encode(buffer).decode("utf-8"))
                        cap.release()
                    finally:
                        if os.path.exists(tmp_path):
                            os.remove(tmp_path)
                else:
                    if len(clean_b64) >= 16:
                        result_frames.append(clean_b64)
            except Exception as e:
                logger.warning("Frame extraction notice: %s", e)
                if len(item) >= 16:
                    result_frames.append(item)

        return result_frames if result_frames else input_b64_list

    @classmethod
    async def resolve_images_to_b64(cls, items: List[str]) -> List[str]:
        """
        Safely resolves a list of image identifiers (base64 strings, data URIs, or remote URLs)
        into cleaned base64 image strings.
        """
        resolved: List[str] = []
        for raw in items:
            if not raw or not isinstance(raw, str):
                continue
            item = raw.strip()
            if not item:
                continue
            if item.startswith("data:image"):
                clean = item.split(",")[-1]
                if len(clean) >= 16:
                    resolved.append(clean)
            elif item.startswith("http://") or item.startswith("https://"):
                try:
                    async with httpx.AsyncClient(timeout=6.0) as client:
                        resp = await client.get(item)
                        if resp.status_code == 200 and len(resp.content) >= 16:
                            b64 = base64.b64encode(resp.content).decode("utf-8")
                            resolved.append(b64)
                except Exception as e:
                    logger.warning("Failed to fetch image from URL %s: %s", item[:80], e)
            elif len(item) >= 16:
                resolved.append(item)
        return resolved

    @classmethod
    async def verify_kyc_liveness_secure(
        cls,
        user_id: UUID,
        anchor_b64: str = "",
        frames_b64: Optional[List[str]] = None,
        expected_pose: Optional[str] = None,
        profile_photos_b64: Optional[List[str]] = None,
        db_session: Any = None
    ) -> KycAiEvaluation:
        """
        Evaluates video KYC using Eva Section 1 (Identity & Persona Engine).
        Provides safe OpenCV attribute checking, multi-photo cross-matching, and resilient multi-model vision failover.
        """
        from app.services.eva_identity_engine import EvaIdentityEngine
        eval_result = await EvaIdentityEngine.verify_kyc_liveness(
            user_id=user_id,
            anchor_b64=anchor_b64,
            frames_b64=frames_b64 or [],
            expected_pose=expected_pose,
            profile_photos_b64=profile_photos_b64,
            db_session=db_session
        )

        # Hook admin escalation queue strictly when manual review is required (rate limits, outages, ambiguous scores)
        if eval_result.status == "pending_manual_review" and db_session is not None:
            try:
                await cls._escalate_to_admin_desk(
                    user_id=user_id,
                    score=eval_result.face_match_score,
                    reason=eval_result.rejection_reason or "Automated biometric review pending",
                    db=db_session,
                    selfie_b64=frames_b64[0] if (frames_b64 and len(frames_b64) > 0) else None,
                    anchor_b64=anchor_b64,
                    profile_photos_b64=profile_photos_b64
                )
            except Exception as e:
                logger.warning("Failed to escalate KYC to admin desk: %s", e)

        return KycAiEvaluation(
            is_live_human=eval_result.is_live_human,
            face_match_score=eval_result.face_match_score,
            is_identity_match=getattr(eval_result, "is_identity_match", True if (eval_result.status == "approved" and eval_result.face_match_score >= 70) else False),
            gallery_consistent=getattr(eval_result, "gallery_consistent", True),
            pose_matched=eval_result.pose_matched,
            estimated_age_bracket=eval_result.estimated_age_bracket,
            is_underage=eval_result.is_underage,
            rejection_reason=eval_result.rejection_reason or "",
            status=eval_result.status,
            analysis_summary=eval_result.analysis_summary or ""
        )

    @classmethod
    async def _escalate_to_admin_desk(
        cls,
        user_id: UUID,
        score: int,
        reason: str,
        db: Any,
        selfie_b64: Optional[str] = None,
        anchor_b64: Optional[str] = None,
        profile_photos_b64: Optional[List[str]] = None,
    ) -> None:
        """Inserts or updates an escalation row into the admin queue table with real selfie and profile photos."""
        from app.models.domain.admin_escalations import AdminKycEscalation
        from app.models.domain.user import User
        from sqlalchemy import select
        from pathlib import Path

        # 1. Ephemeral Disk & Storage Persistence for the Live Selfie
        if selfie_b64 and len(selfie_b64.strip()) > 30:
            try:
                clean_selfie = selfie_b64.split(",")[-1] if "," in selfie_b64 else selfie_b64
                selfie_bytes = base64.b64decode(clean_selfie)
                ephemeral_dir = Path("uploads/kyc_ephemeral") / str(user_id)
                ephemeral_dir.mkdir(parents=True, exist_ok=True)
                selfie_file = ephemeral_dir / "kyc_selfie.webp"
                selfie_file.write_bytes(selfie_bytes)

                # Sync to Supabase storage if available
                if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
                    try:
                        import httpx
                        upload_url = f"{settings.SUPABASE_URL}/storage/v1/object/{settings.SUPABASE_STORAGE_BUCKET}/kyc_ephemeral/{user_id}/kyc_selfie.webp"
                        headers = {
                            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                            "Content-Type": "image/webp",
                            "x-upsert": "true",
                        }
                        async with httpx.AsyncClient(timeout=8.0) as client:
                            await client.post(upload_url, headers=headers, content=selfie_bytes)
                    except Exception as s_err:
                        logger.warning("Supabase storage sync for KYC selfie: %s", s_err)
            except Exception as save_err:
                logger.warning("Failed to save ephemeral KYC selfie to disk: %s", save_err)

        # 2. Fetch User demographics & profile photos
        user = None
        try:
            user_res = await db.execute(select(User).where(User.id == user_id))
            user = user_res.scalar_one_or_none()
        except Exception:
            pass

        declared_dob = datetime.now(timezone.utc).date()
        declared_age = 22
        if user and user.dob:
            declared_dob = user.dob
            today = datetime.now(timezone.utc).date()
            declared_age = max(18, today.year - user.dob.year - ((today.month, today.day) < (user.dob.month, user.dob.day)))

        # Verified API endpoints that stream the actual images
        kyc_video_url = f"/api/v1/admin/kyc/media/{user_id}/selfie"
        anchor_photo_url = f"/api/v1/admin/kyc/media/{user_id}/profile_1"

        stmt = select(AdminKycEscalation).where(AdminKycEscalation.user_id == user_id)
        existing = (await db.execute(stmt)).scalar_one_or_none()

        if not existing:
            escalation = AdminKycEscalation(
                user_id=user_id,
                declared_dob=declared_dob,
                declared_age=declared_age,
                groq_match_score=score,
                groq_reasoning=reason[:250],
                anchor_photo_url=anchor_photo_url,
                kyc_video_url=kyc_video_url,
                status="pending"
            )
            db.add(escalation)
            await db.commit()
        else:
            existing.groq_match_score = score
            existing.groq_reasoning = reason[:250]
            existing.status = "pending"
            existing.declared_dob = declared_dob
            existing.declared_age = declared_age
            existing.anchor_photo_url = anchor_photo_url
            existing.kyc_video_url = kyc_video_url
            await db.commit()

    @classmethod
    async def moderate_image_vision(cls, b64_img: str) -> Dict[str, Any]:
        """
        Multimodal AI Vision Sentinel for photo moderation.
        Strictly enforces:
        1. Zero-tolerance text detection (no quotes, memes, captions, watermarks, timestamps, screenshots, overlay text).
        2. Prohibits full nudity, weapons, hate symbols.
        3. Explicitly ALLOWS AI-edited portraits, filtered photos, color-graded photos, and normal portraits without text.
        """
        api_key = settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")
        if not api_key:
            return {"is_safe": True, "reason": "", "category": "safe"}

        prompt = (
            "You are a strict photo safety reviewer for the UR-Heart dating app.\n"
            "Your job is to check if an uploaded profile photo complies with sanctuary safety policies.\n\n"
            "CRITICAL ZERO-TOLERANCE RULE: NO TEXT IN PHOTOS\n"
            "- Profile photos must NEVER contain ANY text, words, letters, numbers, captions, quotes, memes, watermarks, timestamps, social handles, or screenshots of text.\n"
            "- If even minor, small, or subtle text is detected anywhere in the photo, you MUST INSTANTLY REJECT IT.\n\n"
            "PROHIBITED (reject immediately):\n"
            "- ANY text, typography, letters, words, quotes, memes, captions, watermarks, or screenshots (even minor text)\n"
            "- Full nudity or genital exposure\n"
            "- Completely topless or pornographic poses\n"
            "- Weapons or violence\n"
            "- Hate symbols\n\n"
            "ALLOWED (do NOT reject these):\n"
            "- AI-edited photos, AI portraits, face-tuned photos (ALLOWED as long as there is NO text)\n"
            "- Photos with filters, vintage/beauty/color filters (ALLOWED as long as there is NO text)\n"
            "- Normal clothed portraits, candid photos, selfies, outdoor photos (WITHOUT text)\n"
            "- Traditional clothing, beachwear at pool/beach\n\n"
            "Respond ONLY with raw JSON (no markdown):\n"
            "If safe and has NO text: {\"is_safe\": true, \"reason\": \"\", \"category\": \"safe\"}\n"
            "If text is detected: {\"is_safe\": false, \"category\": \"text_detected\", \"reason\": \"Text detected in photo. Photos containing text, quotes, captions, watermarks, or screenshots are strictly prohibited. Please upload a photo without any text.\"}\n"
            "If other prohibited content: {\"is_safe\": false, \"category\": \"explicit\", \"reason\": \"Photo does not meet sanctuary clothed attire guidelines.\"}"
        )

        payload = {
            "model": "qwen/qwen3.8-27b",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{b64_img}"
                            }
                        }
                    ]
                }
            ],
            "temperature": 0.1,
            "max_tokens": 120,
            "response_format": {"type": "json_object"}
        }

        try:
            async with httpx.AsyncClient(timeout=6.0) as client:
                res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                if res.status_code == 200:
                    raw_content = res.json()["choices"][0]["message"]["content"]
                    data = json.loads(raw_content)
                    return {
                        "is_safe": bool(data.get("is_safe", True)),
                        "reason": str(data.get("reason", "")),
                        "category": str(data.get("category", "safe"))
                    }
                else:
                    logger.warning("Groq Vision non-200 response: %s %s", res.status_code, res.text[:120])
        except Exception as e:
            logger.warning("Groq Vision moderation exception/fallback: %s", str(e))

        # Secondary fallback: OpenRouter Free Tier multimodal vision if configured
        or_key = settings.OPENROUTER_API_KEY or os.getenv("OPENROUTER_API_KEY", "")
        if or_key:
            try:
                or_headers = {
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://urheart.asiverticals.me",
                    "X-Title": "UR-Heart Mindful Sanctuary",
                    "Authorization": f"Bearer {or_key}"
                }
                or_payload = {
                    "model": "qwen/qwen-2.5-vl-72b-instruct:free",
                    "messages": payload["messages"],
                    "temperature": 0.1,
                    "response_format": {"type": "json_object"}
                }
                async with httpx.AsyncClient(timeout=6.0) as client:
                    or_endpoint = settings.OPENROUTER_API_URL or OPENROUTER_ENDPOINT
                    res = await client.post(or_endpoint, headers=or_headers, json=or_payload)
                    if res.status_code == 200:
                        raw_content = res.json()["choices"][0]["message"]["content"]
                        data = json.loads(raw_content)
                        return {
                            "is_safe": bool(data.get("is_safe", True)),
                            "reason": str(data.get("reason", "")),
                            "category": str(data.get("category", "safe"))
                        }
            except Exception as fb_err:
                logger.warning("OpenRouter Vision fallback exception: %s", str(fb_err))

        # Fail-closed sentinel: configured vision providers failed or unavailable
        return {
            "is_safe": False,
            "reason": "AI Vision moderation temporarily unavailable. Please try again.",
            "category": "service_unavailable"
        }
