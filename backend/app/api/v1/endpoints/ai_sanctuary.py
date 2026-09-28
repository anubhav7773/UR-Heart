from typing import List, Dict, Any, Optional
from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from app.services.ai_orchestrator import AiOrchestrator

router = APIRouter(prefix="/ai/eva", tags=["Eva AI Sanctuary"])


class EvaChatRequest(BaseModel):
    message: str = Field(..., max_length=1000)
    history: Optional[List[Dict[str, str]]] = None
    context: Optional[Dict[str, Any]] = None


class EvaChatResponse(BaseModel):
    reply: str
    is_guarded: bool
    status: str = "success"


class DialogueCoachRequest(BaseModel):
    partner_name: str = Field(..., max_length=100)
    last_incoming_message: str = Field(..., max_length=600)
    user_draft_reply: Optional[str] = Field(None, max_length=600)


class GrievanceAssistRequest(BaseModel):
    offender_name: str = Field(..., max_length=100)
    user_narrative: str = Field(..., max_length=1000)


@router.post("/chat", response_model=EvaChatResponse, status_code=status.HTTP_200_OK)
async def chat_with_eva(payload: EvaChatRequest):
    """
    Conversational endpoint with Eva AI Sanctuary.
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
async def get_dialogue_coaching(payload: DialogueCoachRequest):
    """
    Real-time in-chat mindful wingman advice on what to reply to a match.
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
async def assist_grievance_filing(payload: GrievanceAssistRequest):
    """
    Empathetic statutory first-responder assisting user during report / grievance filing.
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
