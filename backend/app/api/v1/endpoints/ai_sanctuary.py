from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request, status
from pydantic import BaseModel, Field

from app.core.limiter import limiter
from app.core.security import get_current_user, get_current_user_optional
from app.models.domain.user import User
from app.services.ai_orchestrator import AiOrchestrator

router = APIRouter(prefix="/ai/eva", tags=["Eva AI Sanctuary"])


class EvaChatRequest(BaseModel):
    message: str = Field(..., max_length=300, description="Chat message strictly capped at 300 characters to prevent Groq wallet drain")
    history: Optional[List[Dict[str, str]]] = None
    context: Optional[Dict[str, Any]] = None


class EvaChatResponse(BaseModel):
    reply: str
    is_guarded: bool
    status: str = "success"
    model: Optional[str] = None


class WingmanSuggestion(BaseModel):
    type: str  # "spark" | "resonance" | "segue"
    label: str  # "🔥 Playful Spark" | "🌱 Deep Resonance" | "☕ Smooth Segue"
    text: str


class DialogueCoachRequest(BaseModel):
    partner_name: str = Field(..., max_length=100)
    last_incoming_message: str = Field(..., max_length=300)
    user_draft_reply: Optional[str] = Field(None, max_length=300)
    partner_id: Optional[str] = Field(None, max_length=100)
    partner_bio: Optional[str] = Field(None, max_length=500)
    partner_interests: Optional[List[str]] = None
    recent_messages: Optional[List[Dict[str, Any]]] = None


class WingmanResponse(BaseModel):
    coach_insight: str = ""
    suggestions: List[WingmanSuggestion] = []
    reply: str
    is_guarded: bool = False
    status: str = "success"
    engine: Optional[str] = None


class ChatSparksRequest(BaseModel):
    partner_name: str = Field(..., max_length=100)
    partner_bio: Optional[str] = Field(None, max_length=500)
    recent_messages: Optional[List[Dict[str, str]]] = None


class ChatSparksResponse(BaseModel):
    sparks: List[str]
    status: str = "success"


class GrievanceAssistRequest(BaseModel):
    offender_name: str = Field(..., max_length=100)
    user_narrative: str = Field(..., max_length=500)


@router.post("/chat", response_model=EvaChatResponse, status_code=status.HTTP_200_OK)
@limiter.limit("30/hour")
async def chat_with_eva(
    request: Request,
    payload: EvaChatRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Conversational endpoint with Eva AI Sanctuary (Section 2 - OpenRouter Engine).
    SEC-HIGH-03: Strictly bound to authenticated User session with 30 msgs/hour rate limit.
    Enforces 100% domain boundary, Asiverticals attribution, and zero API platform leakage.
    """
    from app.services.eva_companion_engine import EvaCompanionEngine
    user_name = getattr(current_user, "full_name", "Seeker") or "Seeker"
    result = await EvaCompanionEngine.chat_companion(
        user_message=payload.message,
        chat_history=payload.history,
        user_name=user_name,
        context=payload.context
    )

    return EvaChatResponse(
        reply=result["reply"],
        is_guarded=result.get("denied", False),
        status="success",
        model=result.get("model")
    )


@router.post("/wingman", response_model=WingmanResponse, status_code=status.HTTP_200_OK)
@limiter.limit("30/hour")
async def get_dialogue_coaching(
    request: Request,
    payload: DialogueCoachRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Real-time in-chat mindful wingman advice powered by GeminiWingmanEngine (Engine 3).
    Synthesizes both seekers' profiles and dialogue context to craft 3 magnetic suggestions.
    SEC-HIGH-03: Authenticated session required with 30 calls/hour rate limiting.
    """
    from app.services.gemini_wingman_engine import GeminiWingmanEngine

    my_profile = {
        "full_name": getattr(current_user, "full_name", "You"),
        "bio": getattr(current_user, "bio", ""),
        "interests": getattr(current_user, "interests", []) or [],
        "intentions": getattr(current_user, "intentions", ""),
    }
    partner_profile = {
        "full_name": payload.partner_name,
        "bio": payload.partner_bio or "",
        "interests": payload.partner_interests or [],
    }

    result = await GeminiWingmanEngine.generate_wingman_guidance(
        partner_name=payload.partner_name,
        last_incoming_message=payload.last_incoming_message,
        user_draft_reply=payload.user_draft_reply,
        my_profile=my_profile,
        partner_profile=partner_profile,
        recent_messages=payload.recent_messages or []
    )

    suggestions_list = [
        WingmanSuggestion(
            type=s.get("type", "spark"),
            label=s.get("label", "Suggestion"),
            text=s.get("text", "")
        )
        for s in result.get("suggestions", [])
    ]

    return WingmanResponse(
        coach_insight=result.get("coach_insight", ""),
        suggestions=suggestions_list,
        reply=result.get("reply", ""),
        is_guarded=result.get("is_guarded", False),
        status=result.get("status", "success"),
        engine=result.get("engine")
    )


@router.post("/chat-sparks", response_model=ChatSparksResponse, status_code=status.HTTP_200_OK)
@limiter.limit("60/hour")
async def get_chat_bonding_sparks(
    request: Request,
    payload: ChatSparksRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Real-time in-chat mindful bonding sparks based on conversation dialogue analysis.
    Accelerates connection between seekers without degrading UX.
    """
    result = await AiOrchestrator.generate_chat_sparks(
        partner_name=payload.partner_name,
        partner_bio=payload.partner_bio or "",
        recent_messages=payload.recent_messages or []
    )
    return ChatSparksResponse(
        sparks=result.get("sparks", []),
        status=result.get("status", "success")
    )


@router.post("/grievance-assist", response_model=EvaChatResponse, status_code=status.HTTP_200_OK)
@limiter.limit("10/hour")
async def assist_grievance_filing(
    request: Request,
    payload: GrievanceAssistRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Empathetic statutory first-responder assisting user during report / grievance filing.
    SEC-HIGH-03: Authenticated session required with 10 calls/hour rate limiting.
    Maps emotional description to IT Rules 2021 categories and advises on evidence.
    """
    result = await AiOrchestrator.assist_grievance_filing(
        user_narrative=payload.user_narrative,
        offender_name=payload.offender_name
    )

    return EvaChatResponse(
        reply=result["reply"],
        is_guarded=result.get("is_guarded", False),
        status=result.get("status", "success")
    )


class FeedbackRequest(BaseModel):
    category: str = Field(default="ux_deficiency", max_length=50)
    description: str = Field(..., max_length=2000)
    user_sentiment: Optional[str] = "neutral"


FEEDBACK_VAULT: List[Dict[str, Any]] = []


@router.post("/feedback", status_code=status.HTTP_201_CREATED, summary="Record User App Feedback & Deficiencies")
async def record_user_feedback(
    payload: FeedbackRequest,
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    """
    Records in-app user feedback, complaints, and missing features.
    """
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "category": payload.category,
        "description": payload.description,
        "sentiment": payload.user_sentiment,
        "user_id": str(current_user.id) if current_user else "anonymous"
    }
    FEEDBACK_VAULT.append(entry)
    AiOrchestrator._recorded_feedback.append(entry)
    print(f"[EVA FEEDBACK RECORDED] {entry}", flush=True)
    return {
        "status": "success",
        "message": "Aapka feedback record kar liya gaya hai. Asiverticals team is par kaam kar rahi hai.",
        "entry": entry
    }
