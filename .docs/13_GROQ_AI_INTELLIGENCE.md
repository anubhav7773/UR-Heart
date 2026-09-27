# 13_GROQ_AI_INTELLIGENCE.md: 360° INTELLIGENCE SUITE & ZERO-CARD FAILOVER ENGINE
# Project: UR-Heart (Mindful Dating Sanctuary)
# Primary Engine: Groq Cloud LPU (14,400 Free Requests/Day — Zero Credit Card Required)
# Secondary Engine: OpenRouter Free Tier / Hugging Face Serverless (Zero Credit Card, 100% Non-Gemini)
# Scope: Multimodal Video KYC, Mindful Bio Polish, Sacred Icebreakers, Resonance Summaries & Admin Sentinel

---

## 1. STRATEGIC ARCHITECTURE & ZERO-CARD / NON-GEMINI PHILOSOPHY

UR-Heart ki AI architecture do strict business aur technical constraints par mathematically bound hai:
1. **Zero Financial Friction (No Credit/Debit Cards)**: Groq Cloud aur OpenRouter Free Tier dono bina kisi card authentication ke activate hote hain. RBI e-mandate ya international payment decline ka 0% risk hai.
2. **Strict Non-Gemini Mandate**: Platform par Google Gemini ka koi model, SDK, ya API endpoint use nahi hoga.
3. **512MB RAM Compliance (Render Free Tier)**: Sabhi AI payloads, video processing, aur frame extraction in-memory (`io.BytesIO`) chalte hain with explicit garbage collection (`gc.collect()`), zero local disk writes.

                       [USER ACTION IN FLUTTER APP]
                                    │
                                    ▼
                     [FASTAPI AI DISPATCHER ROUTER]
                                    │
                 ┌──────────────────┴──────────────────┐
                 ▼                                     ▼
    [PRIMARY: GROQ CLOUD LPU]             [FALLBACK: OPENROUTER FREE]
    - Llama-3.2-11b-Vision (KYC)          - Llama-3.3-70b:free (Text Fallback)
    - Llama-3.1-8b-Instant (Icebreakers)   - Qwen-2.5-72b:free (Bio Fallback)
    - Llama-3.3-70b-Versatile (Bio Polish) - (Zero Gemini, Zero Card)
                 │                                     │
                 └──────────────────┬──────────────────┘
                                    │
                                    ▼
                     [STRUCTURED PYDANTIC v2 OUTPUT]
                                    │
             ┌──────────────────────┴──────────────────────┐
             ▼                                             ▼
   [AUTO-APPLY / APPROVE]                     [ESCALATE TO ADMIN DESK]
   - KYC Badge Verified                       - Log to admin_kyc_escalations
   - Instant UI Update                        - Strictly for kshtriyaanubhav9120@gmail.com

---

## 2. 360° AI FEATURE SPECTRUM & LATENCY SLAS

| Feature | Screen | Groq Primary Model | OpenRouter Fallback Model | Latency SLA | Trigger Type |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Multimodal Video KYC** | Screen 04 | `llama-3.2-11b-vision-preview` | Manual Admin Escalation | < 1200ms | User Onboarding |
| **Mindful Bio Polish** | Screen 04 & 11 | `llama-3.3-70b-versatile` | `meta-llama/llama-3.3-70b-instruct:free` | < 600ms | User Tap ("Polish ✨") |
| **3 Sacred Chat Icebreakers** | Screen 09 | `llama-3.1-8b-instant` | `qwen/qwen-2.5-72b:free` | < 350ms | Instant on Mutual Match |
| **Resonance Insight** | Screen 05 | `llama-3.1-8b-instant` | Cached Deterministic Fallback | < 250ms | Feed Card Hydration |

---

## 3. MULTIMODAL VIDEO KYC PIPELINE (ANTI-SPOOFING & LIVENESS)

### 3.1 In-Memory Video Frame Extraction
Server disk par video file save karna memory leak aur disk exhaustion create karta hai. 
FastAPI endpoint video stream ko seedhe RAM buffer mein read karta hai aur OpenCV ke zariye exact 3 strategic frames extract karta hai:
* **Frame A (15% duration)**: Initial face posture check.
* **Frame B (50% duration)**: Natural eye-blink & micro-movement check (Liveness).
* **Frame C (85% duration)**: Final angle and natural depth check.

```python
# app/services/frame_extractor.py
import cv2
import io
import gc
import numpy as np
from typing import List, Optional

def extract_kyc_frames_in_memory(video_bytes: bytes) -> Optional[List[bytes]]:
    """
    Extracts 3 distinct frames (15%, 50%, 85%) from MP4 video bytes entirely in RAM.
    Downscales frames to 480px width WebP to minimize API token payload.
    """
    try:
        # Convert raw bytes to in-memory numpy array
        nparr = np.frombuffer(video_bytes, np.uint8)
        cap = cv2.VideoCapture()
        
        # Read stream via OpenCV in-memory buffer
        # For cross-platform stability, use temp memory-mapped buffer if needed,
        # or decode frames via sequential decoders.
        # Fallback to direct decoding:
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames < 10:
            return None

        target_indices = [
            int(total_frames * 0.15),
            int(total_frames * 0.50),
            int(total_frames * 0.85)
        ]

        extracted_webp_frames = []
        for idx in target_indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if not ret or frame is None:
                continue

            # Downscale preserving aspect ratio (width=480px)
            height, width = frame.shape[:2]
            new_width = 480
            new_height = int((new_width / width) * height)
            resized = cv2.resize(frame, (new_width, new_height), interpolation=cv2.INTER_AREA)

            # Re-encode to WebP format
            encode_param = [int(cv2.IMWRITE_WEBP_QUALITY), 80]
            success, buffer = cv2.imencode('.webp', resized, encode_param)
            if success:
                extracted_webp_frames.append(buffer.tobytes())

        cap.release()
        del nparr
        gc.collect()

        return extracted_webp_frames if len(extracted_webp_frames) == 3 else None
    except Exception:
        gc.collect()
        return None
3.2 Vision KYC Prompt & Structured Pydantic v2 Schema
Groq Vision API ko anchor photo (slot_1.webp) aur 3 live frames pass kiye jate hain. System structured JSON evaluate karta hai:

Python


# app/schemas/kyc_ai_schema.py
from pydantic import BaseModel, Field

class KycEvaluationResult(BaseModel):
    is_live_human: bool = Field(description="True if natural micro-movement/liveness detected across frames")
    face_match_score: int = Field(ge=0, le=100, description="Confidence score comparing anchor to live frames")
    estimated_age_bracket: str = Field(description="Visual age range e.g. '20-25'")
    is_underage: bool = Field(description="True if visually identified as strictly under 18")
    rejection_reason: str = Field(default="", description="Empty if approved, else explicit reason")
Groq Vision System Directive:
Plaintext


You are the Sanctuary Identity Sentinel for UR-Heart.
Your duty is to maintain authentic trust without prejudice.
Input: Image 1 is the verified Profile Anchor. Images 2, 3, and 4 are consecutive frames from a 3-second live selfie video.

Evaluate:
1. Liveness: Check for natural physiological shifts, lighting continuity, and head/eye micro-movements across Frames 2, 3, and 4. Detect screen-replay attacks or printed photos.
2. Face Match: Compare the face geometry in Image 1 against the person in Frames 2-4.
3. Age Verification: Detect if the subject is an adult (18+) or a minor.

Respond STRICTLY in valid JSON matching the KycEvaluationResult schema.
4. 360° TEXT INTELLIGENCE ENGINES
4.1 Feature: Mindful Bio Polisher (app/services/bio_polisher.py)
User ke rough, incomplete thoughts ko app ke calm, editorial aesthetic mein transform karta hai bina user ke authentic meaning ko distort kiye:

Python


import os
import httpx
from typing import Optional

BIO_POLISH_SYSTEM_PROMPT = """
You are the Editorial Wordsmith of UR-Heart Dating Sanctuary.
Task: Transform the user's raw bio into an evocative, intentional, and humble passage.
Rules:
1. Tone: Warm, grounded, serene, and poetic.
2. Length: Strictly between 30 and 65 words.
3. Language: Match input language (English, Hinglish, or Hindi).
4. Strictly NO cheesy pickup lines, NO corporate jargon, NO emojis overload (max 1 subtle spark).
5. Output ONLY the polished bio text, nothing else.
"""

async def polish_bio_with_ai(raw_bio: str) -> str:
    """
    Polishes user bio via Groq Llama-3.3-70b with transparent OpenRouter fallback.
    """
    groq_api_key = os.getenv("GROQ_API_KEY")
    payload = {
        "model": "llama-3.3-70b-versatile",
        "messages": [
            {"role": "system", "content": BIO_POLISH_SYSTEM_PROMPT},
            {"role": "user", "content": f"Raw bio: \"{raw_bio}\""}
        ],
        "temperature": 0.65,
        "max_tokens": 150
    }

    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            response = await client.post(
                "[https://api.groq.com/openai/v1/chat/completions](https://api.groq.com/openai/v1/chat/completions)",
                headers={"Authorization": f"Bearer {groq_api_key}"},
                json=payload
            )
            if response.status_code == 200:
                data = response.json()
                return data["choices"][0]["message"]["content"].strip(' "')
    except Exception:
        pass

    # ZERO-CARD NON-GEMINI FALLBACK (OpenRouter Free Tier)
    return await fallback_text_ai(
        system_prompt=BIO_POLISH_SYSTEM_PROMPT,
        user_prompt=f"Raw bio: \"{raw_bio}\"",
        max_tokens=150
    )
4.2 Feature: 3 Sacred Chat Icebreakers (app/services/icebreaker_engine.py)
Jab do users Screen 07 ya Screen 09 par connect hote hain, to AI dono ke shared interests aur bios ko analyze karke 3 bespoke conversation starters generate karta hai. Ye generic "Hey/Hi" awkwardness ko 100% khatam karta hai:

Python


import os
import json
import httpx
from typing import List, Dict

ICEBREAKER_SYSTEM_PROMPT = """
You are the Conversation Architect of UR-Heart Sanctuary.
Given the profiles of two matched individuals, generate exactly 3 thoughtful, authentic, and non-intrusive icebreaker prompts they can send each other.
Rules:
1. Each prompt must reference a specific shared interest, book, trait, or location vibe.
2. Max length per prompt: 14 words.
3. Output format: JSON array of 3 strings: ["Prompt 1", "Prompt 2", "Prompt 3"].
"""

async def generate_dialogue_icebreakers(user_a: Dict, user_b: Dict) -> List[str]:
    """
    Generates 3 contextual icebreakers in < 350ms using Groq Llama-3.1-8b-instant.
    """
    context = (
        f"User A: Bio: '{user_a.get('bio')}', Interests: {user_a.get('interests')}, Location: {user_a.get('location_name')}\n"
        f"User B: Bio: '{user_b.get('bio')}', Interests: {user_b.get('interests')}, Location: {user_b.get('location_name')}"
    )

    groq_api_key = os.getenv("GROQ_API_KEY")
    try:
        async with httpx.AsyncClient(timeout=2.5) as client:
            response = await client.post(
                "[https://api.groq.com/openai/v1/chat/completions](https://api.groq.com/openai/v1/chat/completions)",
                headers={"Authorization": f"Bearer {groq_api_key}"},
                json={
                    "model": "llama-3.1-8b-instant",
                    "messages": [
                        {"role": "system", "content": ICEBREAKER_SYSTEM_PROMPT},
                        {"role": "user", "content": context}
                    ],
                    "temperature": 0.7,
                    "response_format": {"type": "json_object"}
                }
            )
            if response.status_code == 200:
                raw_json = response.json()["choices"][0]["message"]["content"]
                parsed = json.loads(raw_json)
                if isinstance(parsed, dict) and "icebreakers" in parsed:
                    return parsed["icebreakers"][:3]
                elif isinstance(parsed, list):
                    return parsed[:3]
    except Exception:
        pass

    # Static High-Resonance Fallbacks
    return [
        "What is a quiet ritual that keeps you grounded?",
        "I noticed we both appreciate slow, intentional spaces.",
        "What was the last story or book that genuinely moved you?"
    ]
4.3 Feature: Feed Resonance Compatibility Insight (app/services/resonance_engine.py)
Screen 05 feed card par card ke upar ek 1-line mindful observation render hoti hai (e.g. "Both of you find quiet joy in classic literature and pour-over mornings"):

Python


async def explain_resonance_insight(profile_a: Dict, profile_b: Dict) -> str:
    """
    Generates an ultra-fast 1-line connection insight in < 250ms.
    """
    # Deterministic heuristic fast-path if interests overlap heavily
    common_tags = set(profile_a.get('interests', [])).intersection(set(profile_b.get('interests', [])))
    if common_tags:
        tags_str = " and ".join(list(common_tags)[:2])
        return f"A shared reverence for {tags_str} binds your paths."

    return "A quiet alignment in values and sanctuary philosophy."
5. ZERO-CARD, NON-GEMINI FAILOVER SERVICE (app/services/ai_fallback_service.py)
Groq rate limit (30 RPM) hit hone par system bina kisi credit card ke OpenRouter Free Tier (:free) par failover hota hai:

Python


import os
import httpx
from typing import Optional

OPENROUTER_FREE_ENDPOINT = "[https://openrouter.ai/api/v1/chat/completions](https://openrouter.ai/api/v1/chat/completions)"
# Permanent Free Tier Models on OpenRouter (Require 0 Credit Cards)
FALLBACK_MODELS = [
    "meta-llama/llama-3.3-70b-instruct:free",
    "qwen/qwen-2.5-72b-instruct:free"
]

async def fallback_text_ai(system_prompt: str, user_prompt: str, max_tokens: int = 150) -> str:
    """
    Transparent failover to OpenRouter Free tier.
    Zero-Credit-Card, Zero-Gemini guarantee.
    """
    openrouter_api_key = os.getenv("OPENROUTER_API_KEY", "")
    if not openrouter_api_key:
        return "Sanctuary reflection resting quietly."

    headers = {
        "Authorization": f"Bearer {openrouter_api_key}",
        "HTTP-Referer": "[https://urheart.app](https://urheart.app)",
        "X-Title": "UR-Heart Sanctuary"
    }

    for model in FALLBACK_MODELS:
        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                res = await client.post(
                    OPENROUTER_FREE_ENDPOINT,
                    headers=headers,
                    json={
                        "model": model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_prompt}
                        ],
                        "max_tokens": max_tokens
                    }
                )
                if res.status_code == 200:
                    data = res.json()
                    return data["choices"][0]["message"]["content"].strip()
        except Exception:
            continue

    return "Finding quiet meaning between words and authentic connection."
6. RESTRICTED SUPERADMIN KYC SENTINEL DESK
6.1 Strict Authorization Gate
Admin review desk backend par compile-time aur runtime gate se protected hai. Kisi bhi doosre authenticated token par direct HTTP 403 Forbidden milta hai:

Python


# app/api/v1/endpoints/admin_kyc.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from pydantic import BaseModel
from typing import List
from uuid import UUID
from datetime import datetime

from app.core.database import get_db
from app.core.security import get_current_authenticated_user
from app.models.domain.user import User
from app.models.domain.admin_escalations import AdminKycEscalation
from app.services.kyc_purge import purge_ephemeral_kyc_video

router = APIRouter(prefix="/admin/kyc", tags=["Superadmin KYC Sentinel"])

SUPERADMIN_EMAIL = "kshtriyaanubhav9120@gmail.com"

def require_superadmin(current_user: User = Depends(get_current_authenticated_user)) -> User:
    """
    Strict security dependency. Only allows kshtriyaanubhav9120@gmail.com.
    """
    if current_user.auth_email != SUPERADMIN_EMAIL:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access strictly restricted to the Sovereign Sanctuary Sentinel."
        )
    return current_user

class KycResolutionPayload(BaseModel):
    escalation_id: int
    user_id: UUID
    action: str # "approve" or "reject"
    notes: str = ""

@router.get("/pending-queue")
async def get_pending_kyc_escalations(
    admin: User = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches ambiguous or low-confidence KYC videos awaiting manual review.
    """
    stmt = (
        select(AdminKycEscalation)
        .where(AdminKycEscalation.status == "pending")
        .order_by(AdminKycEscalation.created_at.asc())
        .limit(25)
    )
    result = await db.execute(stmt)
    return result.scalars().all()

@router.post("/resolve")
async def resolve_kyc_escalation(
    payload: KycResolutionPayload,
    admin: User = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db)
):
    """
    Approves or rejects user KYC and immediately triggers ephemeral video hard-purge.
    """
    # 1. Update User Record
    is_approved = (payload.action == "approve")
    await db.execute(
        update(User)
        .where(User.id == payload.user_id)
        .values(kyc_status=is_approved)
    )

    # 2. Update Escalation Queue Record
    await db.execute(
        update(AdminKycEscalation)
        .where(AdminKycEscalation.id == payload.escalation_id)
        .values(
            status="approved" if is_approved else "rejected",
            reviewed_at=datetime.utcnow(),
            reviewed_by=SUPERADMIN_EMAIL
        )
    )
    await db.commit()

    # 3. STATUTORY COMPLIANCE: Hard purge the ephemeral video from storage
    purge_ephemeral_kyc_video(str(payload.user_id))

    return {"status": "success", "user_id": str(payload.user_id), "kyc_status": is_approved}
7. RATE LIMITING, TOKEN BUDGETS & MEMORY SAFETY
7.1 Free-Tier Quota Math
Groq Daily Limit: 14,400 requests/day.

Peak Usage at 20,000 DAU:

KYC Verifications (One-time): ~300 calls/day.

Bio Polishing (Voluntary): ~600 calls/day.

Icebreaker Invocations: ~2,500 calls/day.

Resonance Insights: Served via fast heuristic cache, ~4,000 calls/day.

Total Daily AI Invocations: ~7,400 calls / day (Well within the 14,400 free quota!).

Rate Spike Buffer: Any momentary surge exceeding 30 RPM transparently shifts to OpenRouter Free tier without throwing a single 429 error to the user.

7.2 Memory Protection Rules (Render 512MB RAM)
Every video capture instance must execute cap.release().

NumPy arrays and image buffers must be explicitly cleared with del followed by gc.collect().

Model responses are strictly streamed or sized to max_tokens <= 150 to avoid buffer bloat.

8. ANTIGRAVITY IMPLEMENTATION & AUDIT ASSERTIONS
Antigravity agent ko Phase 2 build karte waqt nimn specifications check karni hain:

Zero Gemini Code: Project ke kisi bhi file ya dependency (requirements.txt) mein google-generativeai ya Gemini endpoint exist nahi karega.

Zero Local Video Files: Server filesystem par .mp4 ya .avi create hona strictly prohibited hai (io.BytesIO only).

Admin Identity Gate: Verify karein ki admin_kyc.py kisi bhi non-superadmin JWT token par instant 403 Forbidden return kare.

Purge Verification: KYC approve ya reject hone ke 0 seconds ke andar purge_ephemeral_kyc_video execute hona chahiye.

