import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user, get_current_user_optional
from app.models.domain.user import User
from app.services.ai_orchestrator import AiOrchestrator

logger = logging.getLogger("urheart.ai_sanctuary")
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
    escalated: bool = False
    ticket_id: Optional[str] = None
    ticket_category: Optional[str] = None


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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Conversational endpoint with Eva AI Sanctuary (Section 2 - 24/7 Sovereign Support Concierge).
    SEC-HIGH-03: Strictly bound to authenticated User session with 30 msgs/hour rate limit.
    Enforces 90% autonomous resolution + 10% critical founder escalation under IT Rules 2021.
    """
    from datetime import timedelta
    from app.services.eva_companion_engine import EvaCompanionEngine
    from app.models.domain.legal import GrievanceDossier, generate_grievance_ref
    from app.api.v1.endpoints.notifications import push_notification

    user_name = getattr(current_user, "full_name", "Seeker") or "Seeker"
    result = await EvaCompanionEngine.chat_companion(
        user_message=payload.message,
        chat_history=payload.history,
        user_name=user_name,
        context=payload.context
    )

    escalated = result.get("escalated", False)
    ticket_ref = None
    ticket_cat = None

    if escalated:
        esc_data = result.get("escalation_data", {})
        ticket_cat = esc_data.get("category", "GENERAL_SUPPORT")
        ticket_ref = generate_grievance_ref()

        try:
            dossier = GrievanceDossier(
                dossier_reference_id=ticket_ref,
                reporter_id=current_user.id,
                reported_user_id=current_user.id,
                violation_category=ticket_cat,
                evidence_text=f"AI Support Escalation: {payload.message[:300]}",
                status="under_review",
                acknowledgment_sent_at=datetime.utcnow(),
                statutory_resolution_due_at=datetime.utcnow() + timedelta(days=15)
            )
            db.add(dossier)
            await db.commit()
            await db.refresh(dossier)
        except Exception as e:
            logger.error("Failed to persist grievance dossier on escalation: %s", e)
            await db.rollback()

        # Instant high-priority push notification to Founder Anubhav Singh (asiverticals@gmail.com)
        try:
            push_notification(
                user_id="asiverticals@gmail.com",
                notif_type="system_test",
                title=f"🚨 [UR-Heart Support Escalation] #{ticket_ref}",
                body=f"User {user_name} ({ticket_cat}): {payload.message[:120]}",
                data={"ticket_id": ticket_ref, "category": ticket_cat, "route": "/settings"}
            )
        except Exception as e:
            logger.warning("Failed to dispatch founder escalation push: %s", e)

        # Instant statutory email alert to Founder Anubhav Singh (asiverticals@gmail.com)
        try:
            import asyncio
            from app.services.email_service import EmailService
            asyncio.create_task(
                EmailService.dispatch_escalation_alert(
                    ticket_id=ticket_ref,
                    category=ticket_cat,
                    user_name=user_name,
                    user_id=str(current_user.id),
                    user_message=payload.message,
                    recipient_email="asiverticals@gmail.com"
                )
            )
        except Exception as e:
            logger.warning("Failed to dispatch founder escalation email: %s", e)

        final_reply = f"{result['reply']}\n\n[Statutory Grievance Ticket #{ticket_ref} Registered · 24-48h Review Desk]"
    else:
        final_reply = result["reply"]

    return EvaChatResponse(
        reply=final_reply,
        is_guarded=result.get("denied", False),
        status="success",
        model=result.get("model"),
        escalated=escalated,
        ticket_id=ticket_ref,
        ticket_category=ticket_cat
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
