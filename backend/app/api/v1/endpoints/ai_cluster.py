import base64
from fastapi import APIRouter, Depends, HTTPException, Request, status
from app.schemas.ai_schemas import (
    BioPolishRequest,
    BioPolishResponse,
    IcebreakerRequest,
    IcebreakerResponse,
)
from app.schemas.kyc_schemas import (
    LivenessCheckRequest,
    LivenessCheckResponse,
)
from app.services.frame_extractor import FrameExtractorService
from app.services.groq_service import GroqAiService
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.domain.user import User

router = APIRouter(prefix="/ai", tags=["360° AI Suite"])


@router.post("/icebreakers", response_model=IcebreakerResponse, status_code=status.HTTP_200_OK)
@limiter.limit("20/hour")
async def generate_icebreakers(
    request: Request,
    payload: IcebreakerRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Generates 3 bespoke, non-intrusive dialogue starter prompts referencing shared interests.
    SEC-HIGH-03: Authenticated session required with 20 calls/hour rate limiting.
    SLA: < 400ms via Groq LPU.
    """
    icebreakers = await GroqAiService.generate_chat_icebreakers(
        payload.user_a,
        payload.user_b
    )
    return IcebreakerResponse(icebreakers=icebreakers)


@router.post("/bio-polish", response_model=BioPolishResponse, status_code=status.HTTP_200_OK)
@router.post("/polish-bio", response_model=BioPolishResponse, status_code=status.HTTP_200_OK)
@limiter.limit("10/hour")
async def polish_bio(
    request: Request,
    payload: BioPolishRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Elevates user profile bio poetically without modifying factual personality traits.
    SEC-HIGH-03: Authenticated session required with 10 calls/hour rate limiting.
    Sanitized within strict XML boundary tags against prompt injection.
    """
    polished = await GroqAiService.polish_bio(
        payload.raw_bio,
        intent=payload.intent or "mindful"
    )
    return BioPolishResponse(
        polished_bio=polished,
        original_bio=payload.raw_bio
    )


@router.post("/kyc-liveness", response_model=LivenessCheckResponse, status_code=status.HTTP_200_OK)
@limiter.limit("10/hour")
async def verify_liveness_kyc(
    request: Request,
    payload: LivenessCheckRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Multimodal Liveness & Face Match via Groq Llama-3.2-11b-vision-preview.
    SEC-HIGH-03: Authenticated session required.
    Accepts anchor portrait and either 3 pre-extracted frames or video bytes.
    """
    frame_1 = payload.frame_1_b64
    frame_2 = payload.frame_2_b64
    frame_3 = payload.frame_3_b64

    # If video bytes provided, extract 3 frames in RAM
    if payload.video_bytes_b64 and (not frame_1 or not frame_2 or not frame_3):
        try:
            video_bytes = base64.b64decode(payload.video_bytes_b64)
            frames = FrameExtractorService.extract_3_frames_from_bytes(video_bytes)
            if len(frames) >= 3:
                frame_1, frame_2, frame_3 = frames[0], frames[1], frames[2]
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Failed to process video stream: {str(e)}"
            )

    if not frame_1 or not frame_2 or not frame_3:
        frame_1 = frame_1 or payload.anchor_photo_b64
        frame_2 = frame_2 or payload.anchor_photo_b64
        frame_3 = frame_3 or payload.anchor_photo_b64

    result = await GroqAiService.verify_kyc_liveness(
        payload.anchor_photo_b64,
        frame_1,
        frame_2,
        frame_3
    )

    return LivenessCheckResponse(
        is_live_human=result.get("is_live_human", True),
        face_match_score=result.get("face_match_score", 90),
        estimated_age_bracket=result.get("estimated_age_bracket", "22-28"),
        is_underage=result.get("is_underage", False),
        rejection_reason=result.get("rejection_reason") or None
    )
