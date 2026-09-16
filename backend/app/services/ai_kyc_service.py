import os
import json
import tempfile
import subprocess
import cv2
import httpx
from uuid import UUID
from typing import Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue
from app.services.storage_service import purge_user_storage_assets

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_BASE_URL = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
ADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"

def verify_face_in_video(video_path: str) -> bool:
    """
    Samples 5 evenly spaced frames from the video and runs Haar Cascade face detection.
    Requires at least 2 sampled frames to contain exactly 1 single human face.
    """
    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return False

        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        bundled_cascade = os.path.join(base_dir, "assets", "haarcascade_frontalface_default.xml")
        cascade_path = bundled_cascade if os.path.exists(bundled_cascade) else (getattr(cv2.data, "haarcascades", "") + "haarcascade_frontalface_default.xml")
        face_cascade = cv2.CascadeClassifier(cascade_path)
        
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames <= 0:
            total_frames = 5

        step = max(1, total_frames // 5)
        faces_detected_frames = 0
        total_sampled = 0

        for frame_idx in range(0, total_frames, step):
            if total_sampled >= 5:
                break
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            ret, frame = cap.read()
            if not ret or frame is None:
                continue
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5)
            if len(faces) == 1:
                faces_detected_frames += 1
            total_sampled += 1

        cap.release()
        return faces_detected_frames >= 2
    except Exception:
        return False

def extract_audio_track(video_path: str, audio_path: str) -> bool:
    """
    Extracts 16kHz mono WAV audio from video using FFmpeg.
    """
    cmd = [
        "ffmpeg", "-y", "-i", video_path,
        "-vn", "-acodec", "pcm_s16le",
        "-ar", "16000", "-ac", "1",
        audio_path
    ]
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        return res.returncode == 0 and os.path.exists(audio_path) and os.path.getsize(audio_path) > 100
    except Exception:
        return False

async def transcribe_audio_groq(audio_path: str, user_id: UUID) -> str:
    """
    Calls Groq Whisper-large-v3 to transcribe audio track.
    Auto-detects Hindi / Hinglish / English vernacular speech.
    """
    if not GROQ_API_KEY or not os.path.exists(audio_path):
        return ""

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            with open(audio_path, "rb") as audio_file:
                res = await client.post(
                    f"{GROQ_BASE_URL}/audio/transcriptions",
                    headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                    files={"file": (f"{user_id}.wav", audio_file, "audio/wav")},
                    data={"model": "whisper-large-v3", "language": "hi"}
                )
                if res.status_code == 200:
                    return res.json().get("text", "").strip()
    except Exception:
        pass
    return ""

async def evaluate_semantic_match_groq(
    user_name: str,
    user_city: str,
    transcript: str
) -> Dict[str, Any]:
    """
    Invokes Groq Llama-3 (llama-3.1-8b-instant) in JSON mode to verify
    if the spoken transcript matches the user's registered name and city.
    """
    if not GROQ_API_KEY or not transcript:
        return {"name_match": False, "city_match": False, "confidence": 0.0}

    system_prompt = (
        "You are an identity verification officer. A user stated their name and city in a 5-second video. "
        "Compare the user's transcript with registered data. Return strictly JSON with keys: "
        "'name_match': bool, 'city_match': bool, 'confidence': float (0.0 to 1.0)."
    )
    user_payload = f"Registered Name: {user_name}\nRegistered City: {user_city}\nSpoken Transcript: '{transcript}'"

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.post(
                f"{GROQ_BASE_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "llama-3.1-8b-instant",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_payload}
                    ],
                    "response_format": {"type": "json_object"}
                }
            )
            if res.status_code == 200:
                result = json.loads(res.json()["choices"][0]["message"]["content"])
                return {
                    "name_match": bool(result.get("name_match", False)),
                    "city_match": bool(result.get("city_match", False)),
                    "confidence": float(result.get("confidence", 0.0))
                }
    except Exception:
        pass
    return {"name_match": False, "city_match": False, "confidence": 0.0}

async def process_video_kyc(
    user_id: UUID,
    file_bytes: bytes,
    user_name: str,
    user_city: str,
    db: Optional[AsyncSession] = None
) -> Dict[str, Any]:
    """
    Complete 5-Stage Video KYC Pipeline:
    1. Write temporary video & verify human face via OpenCV.
    2. Extract audio track via FFmpeg.
    3. Transcribe audio with Groq Whisper-large-v3.
    4. Perform semantic verification with Groq Llama-3.1-8b.
    5. Route to Auto-Approval & DPDP storage purge OR Admin Review Queue.
    """
    temp_dir = tempfile.gettempdir()
    temp_video_path = os.path.join(temp_dir, f"{user_id}_kyc.mp4")
    temp_audio_path = os.path.join(temp_dir, f"{user_id}_kyc.wav")

    try:
        with open(temp_video_path, "wb") as f:
            f.write(file_bytes)

        # 1. OpenCV Face Check
        has_valid_face = verify_face_in_video(temp_video_path)

        # 2. FFmpeg Audio Extraction
        extract_audio_track(temp_video_path, temp_audio_path)

        # 3. Groq Whisper Transcription
        transcript = await transcribe_audio_groq(temp_audio_path, user_id)

        # 4. Groq LLM Semantic Check
        semantic_res = await evaluate_semantic_match_groq(user_name, user_city, transcript)
        confidence_score = semantic_res.get("confidence", 0.0)
        name_match = semantic_res.get("name_match", False)
        semantic_pass = name_match or (confidence_score >= 0.75)

        # 5. Routing Decision
        # Auto-Approval Criteria: has_valid_face AND (name_match OR confidence >= 0.75) AND confidence >= 0.80
        if has_valid_face and semantic_pass and confidence_score >= 0.80:
            if db:
                await db.execute(
                    update(User)
                    .where(User.id == user_id)
                    .values(
                        kyc_status=True,
                        kyc_state="verified",
                        kyc_ai_confidence=confidence_score,
                        kyc_transcript=transcript
                    )
                )
                await db.commit()

            # Immediately purge raw video to satisfy Section 8(7) DPDP Act 2023
            await purge_user_storage_assets(user_id)
            return {
                "status": "auto_verified",
                "confidence": confidence_score,
                "transcript": transcript,
                "has_valid_face": True
            }
        else:
            # Fallback to Admin Manual Review Queue
            ai_flags = []
            if not has_valid_face:
                ai_flags.append("face_detection_failed")
            if not semantic_pass:
                ai_flags.append("transcript_mismatch")

            if db:
                queue_item = KycReviewQueue(
                    user_id=user_id,
                    video_storage_path=f"kyc-temp/{user_id}_kyc.mp4",
                    registered_name=user_name,
                    registered_city=user_city,
                    extracted_transcript=transcript,
                    ai_confidence_score=confidence_score,
                    ai_flags=ai_flags,
                    status="unreviewed"
                )
                db.add(queue_item)
                await db.execute(
                    update(User)
                    .where(User.id == user_id)
                    .values(
                        kyc_state="pending_manual_review",
                        kyc_ai_confidence=confidence_score,
                        kyc_transcript=transcript
                    )
                )
                await db.commit()

            return {
                "status": "queued_for_admin_review",
                "assigned_admin": ADMIN_EMAIL,
                "confidence": confidence_score,
                "ai_flags": ai_flags
            }

    finally:
        # Guarantee strict cleanup of local temp files
        for p in (temp_video_path, temp_audio_path):
            if os.path.exists(p):
                try:
                    os.remove(p)
                except Exception:
                    pass
