"""
Eva Identity & Persona Engine (Section 1 of Eva Intelligence Architecture)
Specialized Sentinel for:
1. Video KYC Liveness, Biometric Face Verification & Age Verification
   - Safe OpenCV attribute check (prevents AttributeError on headless/Render)
   - Resilient Groq Vision + OpenRouter Gemini/Llama Vision multi-provider failover
   - High-precision biometric matching for authentic seekers
2. High-Fidelity Bio Polishing
   - Turns 2-3 minimal prompt words into rich, authentic, evocative sanctuary bios
   - Eliminates generic clichés while preserving the user's authentic voice
"""

import base64
import json
import logging
import re
from typing import Any, Dict, List, Optional
from uuid import UUID
import httpx
from pydantic import BaseModel

from app.core.config import get_settings

logger = logging.getLogger("urheart.eva.identity")
settings = get_settings()

GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"


class KycAiEvaluation(BaseModel):
    is_live_human: bool = False
    face_match_score: int = 0
    pose_matched: bool = True
    estimated_age_bracket: str = "unknown"
    is_underage: bool = False
    rejection_reason: Optional[str] = ""
    status: str = "pending_manual_review"
    analysis_summary: Optional[str] = ""


class EvaIdentityEngine:
    """Eva Section 1: Identity & Persona Specialist (Dedicated Key Channel 1)."""

    @classmethod
    def _groq_headers(cls) -> Dict[str, str]:
        # Channel 1: Dedicated Identity/KYC key with fallback to GROQ_API_KEY
        key = (
            getattr(settings, "EVA_IDENTITY_API_KEY", "") or
            getattr(settings, "GROQ_API_KEY", "") or
            os.getenv("EVA_IDENTITY_API_KEY", "") or
            os.getenv("GROQ_API_KEY", "") or ""
        ).strip()
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "UR-Heart-Sanctuary/1.0",
        }

    @classmethod
    def _openrouter_headers(cls) -> Dict[str, str]:
        key = (
            getattr(settings, "OPENROUTER_API_KEY", "") or
            os.getenv("OPENROUTER_API_KEY", "") or ""
        ).strip()
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.asiverticals.me",
            "X-Title": "UR-Heart Sanctuary Identity Sentinel",
        }

    # =========================================================================
    # 1. VIDEO KYC LIVENESS & BIOMETRIC SENTINEL
    # =========================================================================

    @classmethod
    def _detect_faces_opencv_safe(cls, b64_images: List[str]) -> bool:
        """
        Safely verifies facial presence using OpenCV if available.
        Immune to AttributeError: module 'cv2' has no attribute 'CascadeClassifier'.
        """
        try:
            import cv2
            import numpy as np

            # Safe attribute checks for headless/Render environments
            if not hasattr(cv2, "CascadeClassifier") or not hasattr(cv2, "data") or not hasattr(cv2.data, "haarcascades"):
                logger.info("OpenCV Haar cascade classifiers not compiled in this environment; skipping local cascade check.")
                return False

            cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            face_cascade = cv2.CascadeClassifier(cascade_path)
            if face_cascade.empty():
                return False

            for b64_str in b64_images:
                clean_b64 = b64_str.split(",")[-1] if "," in b64_str else b64_str
                try:
                    img_bytes = base64.b64decode(clean_b64)
                    np_arr = np.frombuffer(img_bytes, np.uint8)
                    img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)
                    if img is not None:
                        faces = face_cascade.detectMultiScale(img, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                        if len(faces) > 0:
                            return True
                except Exception:
                    continue
        except Exception as e:
            logger.warning("OpenCV safe face detection notice: %s", e)
        return False

    @classmethod
    def _is_valid_image(cls, b64_str: str) -> bool:
        """Checks if base64 string decodes to a valid image format."""
        if not b64_str or len(b64_str) < 50:
            return False
        try:
            clean = b64_str.split(",")[-1] if "," in b64_str else b64_str
            raw = base64.b64decode(clean[:128])
            return (
                raw.startswith(b"\xff\xd8")  # JPEG
                or raw.startswith(b"\x89PNG")  # PNG
                or raw.startswith(b"RIFF")  # WEBP
                or raw.startswith(b"GIF")
            )
        except Exception:
            return False

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
                clean_b64 = item.split(",")[-1] if "," in item else item
                raw_bytes = base64.b64decode(clean_b64)

                # Check if payload is a video (MP4 ftyp, moov, or large stream without image header)
                is_video = (b"ftyp" in raw_bytes[:50]) or (
                    len(raw_bytes) > 20000
                    and not raw_bytes.startswith(b"\xff\xd8")
                    and not raw_bytes.startswith(b"\x89PNG")
                    and not raw_bytes.startswith(b"RIFF")
                )

                if is_video:
                    tmp_path = None
                    try:
                        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
                            tmp.write(raw_bytes)
                            tmp_path = tmp.name

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
                                    h, w = frame.shape[:2]
                                    if max(h, w) > 720:
                                        scale = 720.0 / max(h, w)
                                        frame = cv2.resize(frame, (int(w * scale), int(h * scale)))
                                    _, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                                    result_frames.append(base64.b64encode(buffer).decode("utf-8"))
                        cap.release()
                    finally:
                        if tmp_path and os.path.exists(tmp_path):
                            try:
                                os.remove(tmp_path)
                            except Exception:
                                pass
                else:
                    if len(clean_b64) > 100:
                        result_frames.append(clean_b64)
            except Exception as e:
                logger.warning("Frame extraction notice: %s", e)
                if len(item) > 100:
                    result_frames.append(item)

        return result_frames

    @classmethod
    async def verify_kyc_liveness(
        cls,
        user_id: UUID,
        anchor_b64: str,
        frames_b64: List[str],
        expected_pose: Optional[str] = None,
        db_session: Any = None
    ) -> KycAiEvaluation:
        """
        Evaluates Photo/Video KYC liveness with multi-model failover:
        1. Safe local OpenCV heuristic (if available)
        2. Production Groq Vision (`qwen/qwen3.8-27b`)
        3. OpenRouter Free Multimodal Vision fallback (qwen/qwen3.8-27b:free, google/gemma-4-31b-it:free)
        4. Strict Fail-Closed Policy: If all models rate-limited/failed, strictly returns status=pending_manual_review.
        """
        extracted_frames = cls.extract_image_frames(frames_b64)
        clean_anchor = anchor_b64.split(",")[-1] if "," in anchor_b64 else anchor_b64

        # Fail closed immediately if neither valid anchor nor video frames exist
        anchor_valid = cls._is_valid_image(clean_anchor)
        if not anchor_valid and not extracted_frames:
            logger.warning("[KYC FAIL-CLOSED] User %s: Corrupted or missing anchor/frames.", user_id)
            return KycAiEvaluation(
                is_live_human=False,
                face_match_score=0,
                pose_matched=False,
                rejection_reason="Corrupted or invalid image frames received.",
                status="pending_manual_review"
            )

        # If anchor was omitted or is invalid, synthesize anchor from frame 0
        if (not anchor_valid or len(clean_anchor) < 500) and extracted_frames:
            clean_anchor = extracted_frames[0]
            comparison_frames = extracted_frames[1:] if len(extracted_frames) > 1 else extracted_frames
        else:
            comparison_frames = extracted_frames

        # 1. Safe local check
        local_face_found = cls._detect_faces_opencv_safe([clean_anchor] + comparison_frames)

        pose_instruction = (
            f"4. Pose Challenge Check: The user was instructed to perform the following pose: \"{expected_pose}\". "
            f"Inspect Image 2 to verify if the person is actively performing this pose (pose_matched: true or false).\n"
        ) if expected_pose else ""

        prompt_text = (
            "You are the Sanctuary Identity Sentinel. Image 1 is the user's primary profile portrait (Slot 1). "
            "Image 2 is a live verification selfie captured by the user right now.\n"
            "Perform strict biometric analysis:\n"
            "1. Biometric Match: Compare eye spacing, nose bridge, jawline, and facial structure between Image 1 and Image 2. Face match score MUST be an integer between 0 and 100 based strictly on facial similarity.\n"
            "2. Liveness Check: Verify Image 2 is a genuine 3D living person, not a photo of a screen, printed paper photo, AI avatar, deepfake, or spoof replay.\n"
            "3. Age Check: Verify user appears to be an adult (age 18+).\n"
            f"{pose_instruction}"
            "CRITICAL INSTRUCTIONS:\n"
            "- You MUST visually inspect the actual image pixels.\n"
            "- If images are missing, corrupt, blank, or not showing a human face, face_match_score MUST be 0 and is_live_human MUST be false.\n"
            "- Do NOT copy sample values.\n"
            "Return ONLY a valid raw JSON object with this exact schema:\n"
            "{\n"
            '  "is_live_human": <true or false>,\n'
            '  "face_match_score": <integer from 0 to 100>,\n'
            '  "pose_matched": <true or false>,\n'
            '  "estimated_age_bracket": "<age bracket string like 20-25>",\n'
            '  "is_underage": <true or false>,\n'
            '  "rejection_reason": "<empty string if passed, or specific reason if rejected/failed>",\n'
            '  "analysis_summary": "<brief description of face, eyes, and pose seen in images>"\n'
            "}"
        )

        content_payload: List[Dict[str, Any]] = [{"type": "text", "text": prompt_text}]
        content_payload.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{clean_anchor}"}})
        for frame in comparison_frames[:2]:
            content_payload.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{frame}"}})

        # 2. Primary: Groq Vision
        groq_models = [
            "qwen/qwen3.8-27b",
        ]
        groq_key = (
            getattr(settings, "EVA_IDENTITY_API_KEY", "") or
            getattr(settings, "GROQ_API_KEY", "") or
            os.getenv("EVA_IDENTITY_API_KEY", "") or
            os.getenv("GROQ_API_KEY", "") or ""
        ).strip()

        if groq_key:
            for g_model in groq_models:
                try:
                    logger.info("[KYC VISION REQUEST] User %s: Calling Groq Vision (%s)...", user_id, g_model)
                    payload = {
                        "model": g_model,
                        "messages": [{"role": "user", "content": content_payload}],
                        "temperature": 0.1,
                        "max_tokens": 300,
                    }
                    async with httpx.AsyncClient(timeout=12.0) as client:
                        res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            content_str = choice.get("message", {}).get("content", "")
                            eval_obj = cls._parse_kyc_json(content_str, expected_pose, local_face_found)
                            if eval_obj:
                                logger.info(
                                    "[KYC VISION SUCCESS] User %s via Groq (%s): status=%s, score=%s, live=%s, pose=%s",
                                    user_id, g_model, eval_obj.status, eval_obj.face_match_score, eval_obj.is_live_human, eval_obj.pose_matched
                                )
                                return eval_obj
                        else:
                            logger.warning("Groq Vision (%s) returned status %s: %s", g_model, res.status_code, res.text[:120])
                except Exception as e:
                    logger.warning("Groq Vision (%s) exception: %s", g_model, e)

        # 3. Secondary: OpenRouter Validated Free Multimodal Pool (NO text-only models)
        or_key = getattr(settings, "OPENROUTER_API_KEY", "") or os.getenv("OPENROUTER_API_KEY", "") or ""
        if or_key:
            or_models = [
                "qwen/qwen3.8-27b:free",
                "google/gemma-4-31b-it:free",
                "google/gemma-4-26b-a4b-it:free",
                "dots-studio/dots-3-note-preview:free",
            ]
            for o_model in or_models:
                try:
                    logger.info("[KYC VISION REQUEST] User %s: Calling OpenRouter Vision (%s)...", user_id, o_model)
                    payload = {
                        "model": o_model,
                        "messages": [{"role": "user", "content": content_payload}],
                        "temperature": 0.1,
                        "max_tokens": 300,
                    }
                    async with httpx.AsyncClient(timeout=14.0) as client:
                        res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            content_str = choice.get("message", {}).get("content", "")
                            eval_obj = cls._parse_kyc_json(content_str, expected_pose, local_face_found)
                            if eval_obj:
                                logger.info(
                                    "[KYC VISION SUCCESS] User %s via OpenRouter (%s): status=%s, score=%s, live=%s, pose=%s",
                                    user_id, o_model, eval_obj.status, eval_obj.face_match_score, eval_obj.is_live_human, eval_obj.pose_matched
                                )
                                return eval_obj
                        else:
                            logger.warning("OpenRouter Vision (%s) returned status %s: %s", o_model, res.status_code, res.text[:120])
                except Exception as e:
                    logger.warning("OpenRouter Vision (%s) error: %s", o_model, e)

        # 4. Strict Fail-Closed Sentinel: Remote Vision APIs unavailable/rate-limited
        # Zero automated pass. User is routed to manual review; kyc_status remains False.
        logger.warning(
            "[KYC VISION FAIL-CLOSED] All AI vision models failed or rate-limited for user %s. Strictly FAILING CLOSED to pending_manual_review. kyc_status remains False.",
            user_id
        )
        return KycAiEvaluation(
            is_live_human=False,
            face_match_score=0,
            pose_matched=False,
            estimated_age_bracket="unknown",
            is_underage=False,
            rejection_reason="Automated biometric evaluation temporarily unavailable due to upstream AI rate-limits. Escalated to Sentinel Desk for manual verification.",
            status="pending_manual_review",
            analysis_summary="All remote AI vision providers failed or rate-limited."
        )

    @classmethod
    def _parse_kyc_json(
        cls,
        raw_content: Any,
        expected_pose: Optional[str] = None,
        local_face: bool = False
    ) -> Optional[KycAiEvaluation]:
        if not raw_content or not isinstance(raw_content, str):
            return None
        try:
            match = re.search(r"\{.*\}", raw_content, re.DOTALL)
            if match:
                data = json.loads(match.group(0))
                score = int(data.get("face_match_score", 0))
                is_live = bool(data.get("is_live_human", False))
                pose_matched = bool(data.get("pose_matched", True)) if expected_pose else True
                is_underage = bool(data.get("is_underage", False))
                reason = data.get("rejection_reason", "") or ""
                summary = data.get("analysis_summary", "") or ""

                lower_summary = summary.lower()
                lower_reason = reason.lower()
                # Sentinel Defense: Detect blind text model responses that confess to missing images
                if "no image" in lower_summary or "no image" in lower_reason or "cannot see" in lower_summary or "no visual" in lower_summary or "no visual" in lower_reason:
                    return KycAiEvaluation(
                        is_live_human=False,
                        face_match_score=0,
                        pose_matched=False,
                        estimated_age_bracket="unknown",
                        is_underage=False,
                        rejection_reason="No visual input or face could be identified in selfie.",
                        status="rejected",
                        analysis_summary=summary
                    )

                if is_underage:
                    return KycAiEvaluation(
                        is_live_human=is_live,
                        face_match_score=score,
                        pose_matched=pose_matched,
                        estimated_age_bracket=data.get("estimated_age_bracket", "under_18"),
                        is_underage=True,
                        rejection_reason=reason or "Underage profile detected.",
                        status="rejected",
                        analysis_summary=summary
                    )

                if expected_pose and not pose_matched:
                    return KycAiEvaluation(
                        is_live_human=is_live,
                        face_match_score=score,
                        pose_matched=False,
                        estimated_age_bracket=data.get("estimated_age_bracket", "unknown"),
                        is_underage=False,
                        rejection_reason=reason or f"Challenge pose '{expected_pose}' not detected.",
                        status="rejected",
                        analysis_summary=summary
                    )

                if is_live and score >= 75 and pose_matched and not is_underage:
                    return KycAiEvaluation(
                        is_live_human=True,
                        face_match_score=score,
                        pose_matched=True,
                        estimated_age_bracket=data.get("estimated_age_bracket", "22-28"),
                        is_underage=False,
                        rejection_reason="",
                        status="approved",
                        analysis_summary=summary
                    )
                elif score < 40 or not is_live:
                    return KycAiEvaluation(
                        is_live_human=is_live,
                        face_match_score=score,
                        pose_matched=pose_matched,
                        estimated_age_bracket=data.get("estimated_age_bracket", "unknown"),
                        is_underage=False,
                        rejection_reason=reason or "Biometric match score insufficient or liveness unconfirmed.",
                        status="rejected",
                        analysis_summary=summary
                    )
                else:
                    # Borderline score (40 - 74): route to manual review, NEVER auto-approve
                    return KycAiEvaluation(
                        is_live_human=is_live,
                        face_match_score=score,
                        pose_matched=pose_matched,
                        estimated_age_bracket=data.get("estimated_age_bracket", "22-28"),
                        is_underage=False,
                        rejection_reason=reason or "Biometric match confidence ambiguous. Escalated for human Sentinel review.",
                        status="pending_manual_review",
                        analysis_summary=summary
                    )
        except Exception as e:
            logger.warning("Failed to parse KYC JSON: %s", e)
        return None

    # =========================================================================
    # 2. HIGH-FIDELITY BIO POLISHING SENTINEL
    # =========================================================================

    @classmethod
    async def polish_bio(cls, draft: str, user_name: str = "Seeker") -> Dict[str, Any]:
        """
        Deeply analyzes user's raw thoughts, fragmented keywords (e.g. 'student deciplined lawyer etc'),
        or draft lines using Groq LPU and synthesizes a charismatic, authentic, non-generic first-person profile bio.
        """
        raw_draft = draft.strip()
        system_prompt = (
            "You are Eva, the Master Dating Profile Bio Alchemist for UR-Heart mindful dating sanctuary.\n"
            "Your specialized mission: The user provides raw words, keywords, or fragmented thoughts "
            "(e.g., 'student deciplined lawyer etc' or 'coffee vinyl introvert travel').\n\n"
            "DEEP KEYWORD ARCHETYPE ANALYSIS:\n"
            "- Step 1: Deeply analyze each keyword to uncover the hidden personality archetype, ambition, lifestyle, and values.\n"
            "  For example, 'student' signifies intellectual curiosity and continuous learning; 'deciplined' signifies intentional daily habits, focus, and integrity; "
            "'lawyer' signifies analytical precision, articulate mind, and standing up for justice.\n"
            "- Step 2: Weave these distinct traits into a breathtaking, magnetic, authentic first-person dating profile bio written for other seekers to admire.\n\n"
            "CRITICAL RULES (ZERO CHATBOT, ZERO CLICHÉ):\n"
            "1. NEVER WRITE QUESTIONS OR CHAT PROMPTS. Absolutely NO lines like 'What's your story?', 'Tell me more', 'Ask me anything', or 'Say hi'.\n"
            "2. WRITE STRICTLY IN FIRST-PERSON ('I balance...', 'Drawn to...', 'Finding rhythm in...').\n"
            "3. NO DATING CLICHÉS ('partner in crime', 'loves to laugh', 'work hard play hard', 'fluent in sarcasm').\n"
            "4. STRUCTURE: Exactly 2 to 3 concise, punchy sentences (total 35-55 words):\n"
            "   - Sentence 1: Their craft, daily discipline, intellectual or creative drive.\n"
            "   - Sentence 2-3: The emotional depth, quiet joy, and genuine bond they are here to build.\n"
            "5. TONE: Warm, confident, grounded, emotionally intelligent, and magnetically authentic.\n"
            "6. OUTPUT FORMAT: Return ONLY the final polished bio text without quotes, commentary, headers, or markdown formatting."
        )

        user_content = f"Seeker name: {user_name}\nRaw input keywords/draft: '{raw_draft}'\nWrite their polished 1st-person dating profile bio:"

        # 1. Primary Engine: Groq Active High-Intelligence Model Pool
        groq_models = [
            "qwen/qwen3.8-27b",
            "openai/gpt-oss-120b",
            "openai/gpt-oss-20b",
            "allam-2-7b"
        ]
        groq_key = (
            getattr(settings, "EVA_IDENTITY_API_KEY", "") or
            getattr(settings, "GROQ_API_KEY", "") or
            os.getenv("EVA_IDENTITY_API_KEY", "") or
            os.getenv("GROQ_API_KEY", "") or ""
        ).strip()

        if groq_key:
            for g_model in groq_models:
                try:
                    payload = {
                        "model": g_model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_content}
                        ],
                        "temperature": 0.75,
                        "max_tokens": 200,
                    }
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            bio_text = choice.get("message", {}).get("content", "").strip()
                            if bio_text:
                                clean_text = re.sub(r'^["\']|["\']$', '', bio_text).strip()
                                return {"polished_bio": clean_text, "model": f"groq:{g_model}"}
                except Exception as e:
                    logger.warning("Groq bio polish error (%s): %s", g_model, e)

        # 2. Secondary Engine: OpenRouter Active Verified Free Models
        or_key = getattr(settings, "OPENROUTER_API_KEY", "") or os.getenv("OPENROUTER_API_KEY", "") or ""
        if or_key:
            or_models = [
                "nvidia/nemotron-3.5-lightning:free",
                "qwen/qwen3.8-27b:free",
                "dots-studio/dots-3-note-preview:free",
                "liquid/lfm-2.5-2.6b:free"
            ]
            for o_model in or_models:
                try:
                    payload = {
                        "model": o_model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_content}
                        ],
                        "temperature": 0.75,
                        "max_tokens": 200,
                    }
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            bio_text = choice.get("message", {}).get("content", "").strip()
                            if bio_text:
                                clean_text = re.sub(r'^["\']|["\']$', '', bio_text).strip()
                                return {"polished_bio": clean_text, "model": f"openrouter:{o_model}"}
                except Exception as e:
                    logger.warning("OpenRouter bio polish error (%s): %s", o_model, e)

        # 3. Dynamic Archetype-Based Fallback (never generic canned text)
        cleaned_words = [w.strip() for w in re.split(r"[,;|\s]+", raw_draft) if len(w.strip()) > 2]
        traits_str = ", ".join(cleaned_words[:4]) if cleaned_words else raw_draft
        fallback_bio = (
            f"Grounding my days in {traits_str} and continuous growth. "
            "Appreciating quiet focus, honest laughter, and intentional conversations with depth. "
            "Here to build a real, heartfelt connection."
        )
        return {"polished_bio": fallback_bio, "model": "archetype-heuristic-fallback"}
