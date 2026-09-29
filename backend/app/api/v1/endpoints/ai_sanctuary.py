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


class DialogueCoachRequest(BaseModel):
    partner_name: str = Field(..., max_length=100)
    last_incoming_message: str = Field(..., max_length=300)
    user_draft_reply: Optional[str] = Field(None, max_length=300)


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
    Conversational endpoint with Eva AI Sanctuary.
    SEC-HIGH-03: Strictly bound to authenticated User session with 30 msgs/hour rate limit.
    Enforces 100% domain boundary, Asiverticals attribution, and zero API platform leakage.
    """
    result = await AiOrchestrator.chat_with_eva(
        user_message=payload.message,
        conversation_history=payload.history,
        context_metadata=payload.context
    )

    return EvaChatResponse(
        reply=result["reply"],
        is_guarded=result.get("is_guarded", False),
        status=result.get("status", "success")
    )


@router.post("/wingman", response_model=EvaChatResponse, status_code=status.HTTP_200_OK)
@limiter.limit("20/hour")
async def get_dialogue_coaching(
    request: Request,
    payload: DialogueCoachRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Real-time in-chat mindful wingman advice on what to reply to a match.
    SEC-HIGH-03: Authenticated session required with 20 calls/hour rate limiting.
    """
    result = await AiOrchestrator.get_dialogue_coaching(
        partner_name=payload.partner_name,
        last_incoming_message=payload.last_incoming_message,
        user_draft_reply=payload.user_draft_reply
    )

    return EvaChatResponse(
        reply=result["reply"],
        is_guarded=result.get("is_guarded", False),
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
