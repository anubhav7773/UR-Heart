# AI Video/Audio KYC Verification (Groq API) & Admin Manual Review Specification

**Document Identifier:** URH-KYC-011  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**AI Inference Engine:** Groq Cloud API (Free Tier — Ultra-low latency)  
**Audio Transcription Model:** Groq `whisper-large-v3`  
**Semantic Verification Model:** Groq `llama-3.3-70b-versatile` / `llama-3.1-8b-instant`  
**Super Admin Master Email:** `kshtriyaanubhav9120@gmail.com`  
**Statutory Purge Window:** DPDP Act 2023 — Hard delete video within 24-48 hours post-verification

---

## 1. System Overview & Verification Workflow

To eliminate fake accounts, bots, and impersonation without adding cloud costs, UR-Heart combines Groq's high-speed AI inference with a manual admin fallback:

[User Records 5s Selfie Video + Audio]
│
▼
[Uploaded to Supabase Storage: /kyc-temp/]
│
▼
[FastAPI Backend Background Task]
├── 1. Extract Audio Track (.wav) & 3 Video Frames via OpenCV/FFmpeg
├── 2. Groq Whisper-large-v3: Transcribe spoken Hindi/English text
├── 3. Groq Llama-3: Compare transcript against user's registered Name & City
└── 4. OpenCV Face Cascade: Confirm single centered human face across all frames
│
┌────────────┴────────────┐
▼                         ▼
[Score >= 0.85]          [Score < 0.85 or AI Failure]
Auto-Verify User         Queue for Manual Review
kyc_status = TRUE        kyc_status = 'pending_manual_review'
Purge MP4 from Storage   Alert Admin: kshtriyaanubhav9120@gmail.com
│
▼
[Admin Panel Web / Flutter View]
kshtriyaanubhav9120@gmail.com inspects video
├── Approve ──► kyc_status = TRUE & Purge MP4
└── Reject  ──► Notify user to re-record & Purge MP4


---

## 2. Groq API Integration Architecture

Groq provides sub-second inference on open-weight models with a generous free tier ($0/month):

1. **Audio Transcription (`whisper-large-v3`):**  
   Converts spoken vernacular Hindi, Hinglish, or Indian English from the 5-second video into text in $< 400$ ms.
2. **Semantic Verification Prompt (`llama-3.1-8b-instant`):**  
   Evaluates if the transcribed speech contains the user's declared profile name and city.

---

## 3. Database Updates for KYC State Machine

Execute this SQL via the **Supabase MCP** to support AI confidence scoring and admin manual queue routing:

```sql
-- =============================================================================
-- AI KYC & ADMIN VERIFICATION EXTENSIONS FOR UR-HEART
-- =============================================================================

-- 1. Extend Users Table with Verification Status Enum
DO $$ BEGIN
    CREATE TYPE kyc_review_state AS ENUM ('pending_ai', 'verified', 'pending_manual_review', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS kyc_state kyc_review_state NOT NULL DEFAULT 'pending_ai',
ADD COLUMN IF NOT EXISTS kyc_ai_confidence NUMERIC(3, 2) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS kyc_transcript TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS kyc_failure_reason TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_super_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- Automatically designate Master Admin Account
UPDATE public.users 
SET is_super_admin = TRUE 
WHERE firebase_uid IN (
    SELECT id::text FROM auth.users WHERE email = 'kshtriyaanubhav9120@gmail.com'
);

-- 2. KYC Manual Review Queue Table
CREATE TABLE IF NOT EXISTS public.kyc_review_queue (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    video_storage_path TEXT NOT NULL,
    registered_name VARCHAR(50) NOT NULL,
    registered_city VARCHAR(50) NOT NULL,
    extracted_transcript TEXT DEFAULT '',
    ai_confidence_score NUMERIC(3, 2) DEFAULT 0.00,
    ai_flags TEXT[] DEFAULT ARRAY[]::TEXT[],
    status VARCHAR(20) NOT NULL DEFAULT 'unreviewed' CHECK (status IN ('unreviewed', 'approved', 'rejected')),
    reviewed_by VARCHAR(100) DEFAULT NULL,
    rejection_reason TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ DEFAULT NULL
);

CREATE INDEX idx_kyc_queue_status ON public.kyc_review_queue(status) WHERE status = 'unreviewed';

-- 3. Super Admin RLS Access Policy
ALTER TABLE public.kyc_review_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Super admin has full access to KYC review queue"
ON public.kyc_review_queue FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = public.get_current_user_id() 
          AND (users.is_super_admin = TRUE OR auth.jwt() ->> 'email' = 'kshtriyaanubhav9120@gmail.com')
    )
);
4. Backend AI Verification Service (app/services/ai_kyc_service.py)
This service extracts media assets and runs Groq Whisper + Llama evaluations:

Python
import os
import re
import json
import cv2
import httpx
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue
from app.services.storage_service import supabase_admin, purge_user_storage_assets

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_BASE_URL = "[https://api.groq.com/openai/v1](https://api.groq.com/openai/v1)"
ADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"

async def process_video_kyc(user_id: UUID, file_bytes: bytes, user_name: str, user_city: str, db: AsyncSession):
    """
    1. Extract audio & test face presence via OpenCV.
    2. Transcribe audio using Groq Whisper-large-v3.
    3. Validate match using Groq Llama-3.
    4. Auto-approve if confident; otherwise route to admin queue.
    """
    temp_video_path = f"/tmp/{user_id}_kyc.mp4"
    temp_audio_path = f"/tmp/{user_id}_kyc.wav"

    with open(temp_video_path, "wb") as f:
        f.write(file_bytes)

    # 1. OpenCV: Check single human face in sample frames
    cap = cv2.VideoCapture(temp_video_path)
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    faces_detected_frames = 0
    total_sampled = 0

    while total_sampled < 5:
        ret, frame = cap.read()
        if not ret:
            break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.3, 5)
        if len(faces) == 1:
            faces_detected_frames += 1
        total_sampled += 1
    cap.release()

    has_valid_face = (faces_detected_frames >= 2)

    # 2. Extract audio using FFmpeg
    os.system(f"ffmpeg -y -i {temp_video_path} -vn -acodec pcm_s16le -ar 16000 -ac 1 {temp_audio_path} >/dev/null 2>&1")

    # 3. Transcribe audio via Groq Whisper-large-v3
    transcript = ""
    if os.path.exists(temp_audio_path) and os.path.getsize(temp_audio_path) > 1000:
        async with httpx.AsyncClient(timeout=30.0) as client:
            with open(temp_audio_path, "rb") as audio_file:
                res = await client.post(
                    f"{GROQ_BASE_URL}/audio/transcriptions",
                    headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                    files={"file": (f"{user_id}.wav", audio_file, "audio/wav")},
                    data={"model": "whisper-large-v3", "language": "hi"} # Auto-detects vernacular/Hindi/English
                )
                if res.status_code == 200:
                    transcript = res.json().get("text", "").strip()

    # Clean local temp files
    for p in (temp_video_path, temp_audio_path):
        if os.path.exists(p):
            os.remove(p)

    # 4. Groq LLM Semantic Check
    system_prompt = (
        "You are an identity verification officer. A user stated their name and city in a 5-second video. "
        "Compare the user's transcript with registered data. Return strictly JSON with keys: "
        "'name_match': bool, 'city_match': bool, 'confidence': float (0.0 to 1.0)."
    )
    user_payload = f"Registered Name: {user_name}\nRegistered City: {user_city}\nSpoken Transcript: '{transcript}'"

    confidence_score = 0.0
    semantic_pass = False

    if transcript:
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.post(
                f"{GROQ_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
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
                confidence_score = float(result.get("confidence", 0.0))
                semantic_pass = result.get("name_match", False) or (confidence_score >= 0.75)

    # 5. Routing Decision
    if has_valid_face and semantic_pass and confidence_score >= 0.80:
        # Auto-Verification Pass
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
        # Immediately purge raw video to satisfy DPDP Act 2023
        await purge_user_storage_assets(user_id)
        return {"status": "auto_verified", "confidence": confidence_score}
    else:
        # Fallback to Admin Review Queue
        queue_item = KycReviewQueue(
            user_id=user_id,
            video_storage_path=f"kyc-temp/{user_id}_kyc.mp4",
            registered_name=user_name,
            registered_city=user_city,
            extracted_transcript=transcript,
            ai_confidence_score=confidence_score,
            ai_flags=[
                *([] if has_valid_face else ["face_detection_failed"]),
                *([] if semantic_pass else ["transcript_mismatch"])
            ],
            status="unreviewed"
        )
        db.add(queue_item)
        await db.execute(
            update(User)
            .where(User.id == user_id)
            .values(kyc_state="pending_manual_review", kyc_ai_confidence=confidence_score)
        )
        await db.commit()
        return {"status": "queued_for_admin_review", "assigned_admin": ADMIN_EMAIL}
5. Admin Panel Endpoints (app/api/v1/endpoints/admin_kyc.py)
Endpoints strictly gated to kshtriyaanubhav9120@gmail.com:

Python
from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from app.core.database import get_db
from app.models.domain.user import User
from app.models.domain.kyc_queue import KycReviewQueue
from app.core.security import get_current_user_email
from app.services.storage_service import purge_user_storage_assets

router = APIRouter()
SUPER_ADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"

def verify_super_admin(email: str = Depends(get_current_user_email)):
    if email.lower() != SUPER_ADMIN_EMAIL.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. This portal is restricted to ASI Verticals Master Admin."
        )
    return email

class AdminKycActionRequest(BaseModel):
    queue_id: int
    user_id: UUID
    action: str # 'approve' or 'reject'
    rejection_reason: str = None

# 1. List Unreviewed Profiles
@router.get("/api/v1/admin/kyc/pending-queue")
async def list_pending_kyc(
    admin: str = Depends(verify_super_admin),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(KycReviewQueue).where(KycReviewQueue.status == "unreviewed").order_by(KycReviewQueue.created_at.asc())
    res = await db.execute(stmt)
    items = res.scalars().all()
    return {"admin": admin, "pending_count": len(items), "queue": items}

# 2. Manual Action: Approve / Reject
@router.post("/api/v1/admin/kyc/action")
async def review_kyc_action(
    req: AdminKycActionRequest,
    admin: str = Depends(verify_super_admin),
    db: AsyncSession = Depends(get_db)
):
    if req.action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="Action must be 'approve' or 'reject'.")

    is_approved = (req.action == "approve")

    # Update User Status
    await db.execute(
        update(User)
        .where(User.id == req.user_id)
        .values(
            kyc_status=is_approved,
            kyc_state="verified" if is_approved else "rejected",
            kyc_failure_reason=None if is_approved else req.rejection_reason
        )
    )

    # Update Queue Record
    await db.execute(
        update(KycReviewQueue)
        .where(KycReviewQueue.id == req.queue_id)
        .values(
            status="approved" if is_approved else "rejected",
            reviewed_by=admin,
            rejection_reason=req.rejection_reason,
            resolved_at=datetime.utcnow()
        )
    )
    await db.commit()

    # In both cases, purge the raw video to comply with DPDP Act data minimization
    await purge_user_storage_assets(req.user_id)

    return {
        "status": "success",
        "action_recorded": req.action,
        "reviewed_by": admin,
        "video_purged": True
    }
6. Antigravity Agent Verification Checklist
The Antigravity coding engine must complete and assert the following automated test cases:

[ ] Groq API Connectivity: Mock call to whisper-large-v3 with a sample Hindi WAV file asserts transcript generation without API timeouts.

[ ] Auto-Approval Path: A sample input containing clear face and matching spoken name/city must auto-set kyc_state = 'verified', kyc_status = TRUE, and call purge_user_storage_assets.

[ ] Admin Queue Fallback: A silent video or mismatched transcript must route the record to public.kyc_review_queue with status = 'unreviewed'.

[ ] Admin Route Security: Attempting to call /api/v1/admin/kyc/pending-queue with any email other than kshtriyaanubhav9120@gmail.com must strictly return HTTP 403 Forbidden.

[ ] Data Minimization Integrity: Approving or rejecting a profile from the admin endpoint must hard-delete the video object from Supabase Storage.

Authorized & Validated for ASI Verticals / UR-Heart AI Verification Pipeline.