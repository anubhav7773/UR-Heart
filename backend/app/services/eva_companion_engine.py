"""
Eva Sanctuary Companion & Dialogue Sparks Engine (Section 2 of Eva Intelligence Architecture)
Specialized Sentinel for:
1. Sanctuary Companion Chat
   - Empathic, emotionally intelligent, mindful conversation
   - Strict app-boundary guardrails denying out-of-app general queries
     (e.g., coding, homework, stock advice, politics denied with gentle sanctuary wisdom)
2. Dialogue Sparks & Bonding Recommendations
   - Contextual reflection sparks for two users chatting
   - Suggests bonding topics based on recent chat history to accelerate mutual intimacy
"""

import json
import logging
import re
from typing import Any, Dict, List, Optional
import httpx
from pydantic import BaseModel

from app.core.config import get_settings
from app.services.eva_guardrails import EvaGuardrails

logger = logging.getLogger("urheart.eva.companion")
settings = get_settings()

GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"


class EvaCompanionEngine:
    """Eva Section 2: Sanctuary Companion & Chat Bonding Specialist."""

    @classmethod
    def _groq_headers(cls) -> Dict[str, str]:
        key = getattr(settings, "GROQ_API_KEY", "") or ""
        return {
            "Authorization": f"Bearer {key.strip()}",
            "Content-Type": "application/json",
        }

    @classmethod
    def _openrouter_headers(cls) -> Dict[str, str]:
        key = getattr(settings, "OPENROUTER_API_KEY", "") or ""
        return {
            "Authorization": f"Bearer {key.strip()}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.asiverticals.me",
            "X-Title": "UR-Heart Sanctuary Companion",
        }

    # =========================================================================
    # 1. SANCTUARY COMPANION CONVERSATION
    # =========================================================================

    @classmethod
    async def chat_companion(
        cls,
        user_message: str,
        chat_history: Optional[List[Dict[str, str]]] = None,
        user_name: str = "Seeker"
    ) -> Dict[str, Any]:
        """
        Handles Eva companion chat with strict app boundary guardrails.
        If user asks out-of-scope questions, gently guides them back to the sanctuary.
        """
        # 1. Guardrail check: Is this an out-of-app query?
        is_safe, denial_msg = EvaGuardrails.check_message(user_message)
        if not is_safe and denial_msg:
            return {
                "reply": denial_msg,
                "denied": True,
                "model": "eva-sanctuary-guardrails"
            }

        system_instruction = (
            f"You are Eva, the mindful AI Sanctuary Companion in the UR-Heart dating app.\n"
            f"The user speaking with you is {user_name}.\n"
            "YOUR PURPOSE:\n"
            "- Guide the user in emotional vulnerability, dating reflection, self-discovery, and meaningful connection.\n"
            "- Be warm, empathetic, mindful, gentle, and psychologically grounded.\n"
            "- Keep answers concise (2 to 4 sentences max) so dialogue flows like a real mindful conversation.\n"
            "- STRICT APP BOUNDARY: NEVER answer questions about writing code, math equations, essays, general web trivia, "
            "financial investments, or political news. If asked, gently remind them that your sanctuary presence is here "
            "solely for their heart, dating journey, and emotional presence."
        )

        messages: List[Dict[str, str]] = [{"role": "system", "content": system_instruction}]
        if chat_history:
            for turn in chat_history[-6:]:
                messages.append({
                    "role": turn.get("role", "user"),
                    "content": turn.get("content", "")
                })
        messages.append({"role": "user", "content": user_message})

        # Try Groq primary
        groq_key = getattr(settings, "GROQ_API_KEY", "") or ""
        if groq_key:
            try:
                payload = {
                    "model": "llama-3.3-70b-versatile",
                    "messages": messages,
                    "temperature": 0.65,
                    "max_tokens": 250,
                }
                async with httpx.AsyncClient(timeout=8.0) as client:
                    res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                    if res.status_code == 200:
                        reply = res.json()["choices"][0]["message"]["content"].strip()
                        return {"reply": reply, "denied": False, "model": "groq:llama-3.3-70b-versatile"}
            except Exception as e:
                logger.warning("Groq companion chat error: %s", e)

        # Fallback to OpenRouter
        or_key = getattr(settings, "OPENROUTER_API_KEY", "") or ""
        if or_key:
            try:
                payload = {
                    "model": "google/gemini-2.0-flash-lite:free",
                    "messages": messages,
                    "temperature": 0.65,
                    "max_tokens": 250,
                }
                async with httpx.AsyncClient(timeout=8.0) as client:
                    res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                    if res.status_code == 200:
                        reply = res.json()["choices"][0]["message"]["content"].strip()
                        return {"reply": reply, "denied": False, "model": "openrouter:gemini-2.0-flash-lite:free"}
            except Exception as e:
                logger.warning("OpenRouter companion chat error: %s", e)

        # Resilient fallback
        fallback_reply = (
            f"I hear the intention behind your words, {user_name}. "
            "In this quiet sanctuary, take a slow breath. What is your heart truly seeking in your connections today?"
        )
        return {"reply": fallback_reply, "denied": False, "model": "eva-core-presence"}

    # =========================================================================
    # 2. DIALOGUE SPARKS & BONDING RECOMMENDATIONS
    # =========================================================================

    @classmethod
    async def generate_bonding_sparks(
        cls,
        recent_dialogue_texts: List[str],
        partner_name: str = "Seeker"
    ) -> List[str]:
        """
        Analyzes the last few messages between two users and generates 3 tailored
        bonding prompts/questions that deepen authentic conversation naturally.
        """
        context_str = " | ".join(recent_dialogue_texts[-6:]) if recent_dialogue_texts else "Initial greeting phase"
        system_prompt = (
            "You are Eva's Chat Bonding Alchemist for UR-Heart dating app.\n"
            "Given recent dialogue snippets between two users, produce EXACTLY 3 engaging, insightful, "
            "vulnerability-inducing conversation sparks / questions they can ask each other.\n"
            "CRITERIA:\n"
            "- Spark curiosity, shared values, subtle playful warmth, and emotional resonance.\n"
            "- Avoid dry questions like 'How was work?' or 'What are your hobbies?'.\n"
            "- Keep each spark under 15 words.\n"
            "- Return ONLY a JSON list of 3 strings: [\"...\", \"...\", \"...\"]"
        )

        user_content = f"Recent dialogue: {context_str}\nPartner: {partner_name}\nGenerate 3 bonding sparks:"

        # Try Groq primary
        groq_key = getattr(settings, "GROQ_API_KEY", "") or ""
        if groq_key:
            try:
                payload = {
                    "model": "llama-3.3-70b-versatile",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_content}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 150,
                }
                async with httpx.AsyncClient(timeout=6.0) as client:
                    res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                    if res.status_code == 200:
                        content_str = res.json()["choices"][0]["message"]["content"]
                        sparks = cls._extract_sparks_list(content_str)
                        if sparks:
                            return sparks
            except Exception as e:
                logger.warning("Groq sparks error: %s", e)

        # Fallback to OpenRouter
        or_key = getattr(settings, "OPENROUTER_API_KEY", "") or ""
        if or_key:
            try:
                payload = {
                    "model": "google/gemini-2.0-flash-lite:free",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_content}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 150,
                }
                async with httpx.AsyncClient(timeout=6.0) as client:
                    res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                    if res.status_code == 200:
                        content_str = res.json()["choices"][0]["message"]["content"]
                        sparks = cls._extract_sparks_list(content_str)
                        if sparks:
                            return sparks
            except Exception as e:
                logger.warning("OpenRouter sparks error: %s", e)

        # Context-aware defaults
        return [
            f"What is something unexpected that brought you pure peace lately, {partner_name}?",
            "If we had a free evening with zero screens, where would you wander?",
            "What is a personal belief you have completely changed your mind about?"
        ]

    @classmethod
    def _extract_sparks_list(cls, text: str) -> Optional[List[str]]:
        try:
            match = re.search(r"\[.*\]", text, re.DOTALL)
            if match:
                items = json.loads(match.group(0))
                if isinstance(items, list) and len(items) >= 2:
                    return [str(i).strip().strip('"\'') for i in items[:3]]
        except Exception:
            pass
        return None
