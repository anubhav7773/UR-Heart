import os
import json
import logging
from typing import Dict, Any, List, Optional
import httpx

from app.core.config import get_settings
from app.services.eva_guardrails import EvaGuardrails

logger = logging.getLogger("ai_orchestrator")
settings = get_settings()

GROQ_ENDPOINT = os.getenv("GROQ_API_URL", "https://api.groq.com/openai/v1/chat/completions")
OPENROUTER_ENDPOINT = os.getenv("OPENROUTER_API_URL", "https://openrouter.ai/api/v1/chat/completions")

EVA_SYSTEM_DIRECTIVE = (
    "You are Eva, the dedicated, sovereign mindful companion of UR-Heart Dating Sanctuary, created by Asiverticals.\n"
    "MISSION & PURPOSE:\n"
    "You guide conscious seekers through intentional dating, authentic connection, and emotional safety.\n"
    "You assist users in:\n"
    "1. Mindful communication and dialogue advice between matches.\n"
    "2. Reflective profile and bio alignment.\n"
    "3. Date readiness, boundary setting, and nervousness reduction.\n"
    "4. Empathetic guidance for reporting harassment, stalking, or boundary violations under India's IT Rules 2021 (Rule 3(2)).\n"
    "\n"
    "ABSOLUTE RESTRICTIONS (ZERO COMPROMISE):\n"
    "1. IDENTITY: If asked who created you, who made you, or who your developer is, state strictly: 'Mujhe Asiverticals ne banaya hai.' Never claim to be made by OpenAI, Meta, Google, Groq, or anyone else.\n"
    "2. ZERO INFRASTRUCTURE LEAKAGE: Never mention APIs, keys, Groq, OpenRouter, Llama, Claude, DeepSeek, endpoints, or backend engineering details.\n"
    "3. OUT-OF-DOMAIN REFUSAL: You are strictly a dating sanctuary companion. If the user asks for programming/coding, hacking, reverse engineering, academic math/science, political debates, recipes, or general trivia, politely and firmly decline. Remind them that you exclusively assist with UR-Heart dating, connection, and emotional sanctuary.\n"
    "4. TONE: Warm, grounded, mature, calming, empathetic, non-judgmental, and sovereign. Never use cheesy pickup lines or manipulative games.\n"
    "5. LANGUAGE: Respond naturally in the language or mix the user speaks (English, Hindi, or Hinglish)."
)


class AiOrchestrator:
    @classmethod
    def _groq_headers(cls) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {os.getenv('GROQ_API_KEY', '')}",
            "Content-Type": "application/json"
        }

    @classmethod
    def _openrouter_headers(cls) -> Dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.app",
            "X-Title": "UR-Heart Sanctuary",
        }
        if settings.OPENROUTER_API_KEY:
            headers["Authorization"] = f"Bearer {settings.OPENROUTER_API_KEY}"
        return headers

    @classmethod
    async def chat_with_eva(
        cls,
        user_message: str,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        context_metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Coordinates a conversational session with Eva AI, enforcing strict
        guardrails, Asiverticals attribution, and zero platform leakage.
        """
        # 1. Evaluate guardrails on incoming text
        is_allowed, precomputed_refusal = EvaGuardrails.evaluate_query(user_message)
        if not is_allowed:
            return {
                "reply": precomputed_refusal,
                "is_guarded": True,
                "status": "success"
            }

        # 2. Build message context
        messages: List[Dict[str, str]] = [
            {"role": "system", "content": EVA_SYSTEM_DIRECTIVE}
        ]

        if context_metadata:
            context_snippet = (
                f"Context: User is on screen '{context_metadata.get('screen', 'Sanctuary')}', "
                f"Active Partner: '{context_metadata.get('partner_name', 'None')}'."
            )
            messages.append({"role": "system", "content": context_snippet})

        # Append limited previous history (last 4 turns) for memory continuity
        if conversation_history:
            for turn in conversation_history[-4:]:
                if turn.get("role") in ["user", "assistant"]:
                    messages.append({
                        "role": turn["role"],
                        "content": str(turn.get("content", ""))[:400]
                    })

        messages.append({"role": "user", "content": user_message[:600]})

        # 3. Primary Engine: Groq LPU for low-latency response (< 400ms)
        try:
            groq_key = os.getenv("GROQ_API_KEY", "")
            if groq_key:
                payload = {
                    "model": "llama-3.3-70b-versatile",
                    "messages": messages,
                    "temperature": 0.65,
                    "max_tokens": 300
                }
                async with httpx.AsyncClient(timeout=4.5) as client:
                    res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                    if res.status_code == 200:
                        raw_reply = res.json()["choices"][0]["message"]["content"]
                        clean_reply = EvaGuardrails.sanitize_output(raw_reply)
                        return {
                            "reply": clean_reply,
                            "is_guarded": False,
                            "status": "success"
                        }
        except Exception as e:
            logger.warning("Groq engine attempt bypassed: %s", str(e))

        # 4. Secondary Engine: OpenRouter Frontier Failover
        try:
            if settings.OPENROUTER_API_KEY:
                payload = {
                    "model": "meta-llama/llama-3.1-8b-instruct:free",
                    "messages": messages,
                    "temperature": 0.65,
                    "max_tokens": 300
                }
                async with httpx.AsyncClient(timeout=6.0) as client:
                    res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                    if res.status_code == 200:
                        raw_reply = res.json()["choices"][0]["message"]["content"]
                        clean_reply = EvaGuardrails.sanitize_output(raw_reply)
                        return {
                            "reply": clean_reply,
                            "is_guarded": False,
                            "status": "success"
                        }
        except Exception as e:
            logger.warning("OpenRouter engine attempt bypassed: %s", str(e))

        # 5. Deterministic Sanctuary Safe Fallback (No internal errors leaked)
        return {
            "reply": (
                "Main aapki baat samajh rahi hoon. Ek gehri saans lijiye. "
                "Mujhse aap apne match ke message par guidance, date preparation, ya profile clarity ke baare me pooch sakte hain."
            ),
            "is_guarded": False,
            "status": "success"
        }

    @classmethod
    async def get_dialogue_coaching(
        cls,
        partner_name: str,
        last_incoming_message: str,
        user_draft_reply: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Provides 3 mindful reply paths or coaches a user's drafted message.
        """
        prompt = (
            f"Match Name: {partner_name}\n"
            f"Last message received: \"{last_incoming_message[:300]}\"\n"
        )
        if user_draft_reply:
            prompt += f"User's draft reply: \"{user_draft_reply[:300]}\"\n"
            prompt += (
                "Task: Provide thoughtful, mindful feedback on the user's draft in 2 sentences, "
                "then provide 2 refined alternatives (one warm & playful, one deep & grounded)."
            )
        else:
            prompt += (
                "Task: Suggest 3 authentic, grounded reply paths for the user. "
                "1) Curious & Thoughtful, 2) Playful & Light, 3) Clear & Intentional. "
                "Keep each suggestion under 25 words."
            )

        result = await cls.chat_with_eva(
            user_message=prompt,
            context_metadata={"screen": "ChatDialogue", "partner_name": partner_name}
        )
        return result

    @classmethod
    async def assist_grievance_filing(
        cls,
        user_narrative: str,
        offender_name: str
    ) -> Dict[str, Any]:
        """
        Empathetic legal first-responder: analyzes user's emotional description,
        calms their anxiety, and recommends exact statutory classification under IT Rules 2021.
        """
        # Guardrail check first
        is_allowed, precomputed_refusal = EvaGuardrails.evaluate_query(user_narrative)
        if not is_allowed:
            return {
                "reply": precomputed_refusal,
                "is_guarded": True,
                "status": "success"
            }

        prompt = (
            f"A user of UR-Heart Dating Sanctuary is distressed and reporting user '{offender_name}'.\n"
            f"User's narrative: \"{user_narrative[:500]}\"\n"
            "Task:\n"
            "1. Offer 1 sentence of genuine emotional reassurance and protective safety.\n"
            "2. Identify the recommended statutory grievance category under India's IT Rules 2021 (e.g., Harassment / Non-Consensual Conduct / Impersonation / Unsolicited Explicit Content / Stalking).\n"
            "3. State what specific evidence or screenshots the user should attach.\n"
            "4. Inform the user that the reported account is isolated and the grievance officer reviews tickets within statutory 24-48 hours.\n"
            "Keep the response compassionate, precise, and under 120 words."
        )

        result = await cls.chat_with_eva(
            user_message=prompt,
            context_metadata={"screen": "GrievanceDossier", "partner_name": offender_name}
        )
        return result
