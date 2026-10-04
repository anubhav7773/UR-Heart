import os
import json
import re
import html
import random
import logging
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
            if not item or len(item) < 40:
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
                    result_frames.append(clean_b64)
            except Exception as e:
                logger.warning("Frame extraction notice: %s", e)
                result_frames.append(item)

        return result_frames if result_frames else input_b64_list

    @classmethod
    async def verify_kyc_liveness_secure(
        cls,
        user_id: UUID,
        anchor_b64: str,
        frames_b64: List[str],
        expected_pose: Optional[str] = None,
        db_session: Any = None
    ) -> KycAiEvaluation:
        """
        Evaluates video KYC using Eva Section 1 (Identity & Persona Engine).
        Provides safe OpenCV attribute checking and resilient multi-model vision failover.
        """
        from app.services.eva_identity_engine import EvaIdentityEngine
        eval_result = await EvaIdentityEngine.verify_kyc_liveness(
            user_id=user_id,
            anchor_b64=anchor_b64,
            frames_b64=frames_b64,
            expected_pose=expected_pose,
            db_session=db_session
        )

        # Hook admin escalation queue if manual review is required
        if (eval_result.status == "pending_manual_review" or not eval_result.is_live_human) and db_session is not None:
            try:
                await cls._escalate_to_admin_desk(
                    user_id=user_id,
                    score=eval_result.face_match_score,
                    reason=eval_result.rejection_reason or "Automated biometric review pending",
                    db=db_session
                )
            except Exception as e:
                logger.warning("Failed to escalate KYC to admin desk: %s", e)

        return KycAiEvaluation(
            is_live_human=eval_result.is_live_human,
            face_match_score=eval_result.face_match_score,
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
        db: Any
    ) -> None:
        """Inserts an escalation row into the admin queue table."""
        from app.models.domain.admin_escalations import AdminKycEscalation
        from sqlalchemy import select

        stmt = select(AdminKycEscalation).where(AdminKycEscalation.user_id == user_id)
        existing = (await db.execute(stmt)).scalar_one_or_none()

        if not existing:
            escalation = AdminKycEscalation(
                user_id=user_id,
                declared_dob=datetime.now(timezone.utc).date(),
                declared_age=22,
                groq_match_score=score,
                groq_reasoning=reason[:250],
                anchor_photo_url=f"users/{user_id}/moments/slot_1.webp",
                kyc_video_url=f"kyc_ephemeral/{user_id}/kyc_selfie.webp",
                status="pending"
            )
            db.add(escalation)
            await db.commit()
        else:
            existing.groq_match_score = score
            existing.groq_reasoning = reason[:250]
            existing.status = "pending"
            await db.commit()
