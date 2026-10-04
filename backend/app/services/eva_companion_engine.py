"""
Eva Sanctuary Companion & Dialogue Sparks Engine (Section 2 of Eva Intelligence Architecture)
Dedicated Channel 2:
1. Sanctuary Companion Chat
   - Empathic, emotionally intelligent, mindful conversation
   - Strict app-boundary guardrails denying out-of-app general queries
     (e.g., coding, homework, stock advice, politics denied with gentle sanctuary wisdom)
   - Dynamic multi-model failover across OpenRouter and Groq pools
2. Dialogue Sparks & Bonding Recommendations
   - Contextual reflection sparks for two users chatting
   - Suggests bonding topics based on recent chat history to accelerate mutual intimacy
"""

import os
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
    """Eva Section 2: Sanctuary Companion & Chat Bonding Specialist (Dedicated Channel 2)."""

    @classmethod
    def _openrouter_headers(cls) -> Dict[str, str]:
        # Channel 2: Dedicated Companion key with fallback to OPENROUTER_API_KEY
        key = (
            getattr(settings, "EVA_COMPANION_API_KEY", "") or
            getattr(settings, "OPENROUTER_API_KEY", "") or
            os.getenv("EVA_COMPANION_API_KEY", "") or
            os.getenv("OPENROUTER_API_KEY", "") or ""
        ).strip()
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.asiverticals.me",
            "X-Title": "UR-Heart Sanctuary Companion",
        }

    @classmethod
    def _groq_headers(cls) -> Dict[str, str]:
        key = (
            getattr(settings, "GROQ_API_KEY", "") or
            os.getenv("GROQ_API_KEY", "") or ""
        ).strip()
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "UR-Heart-Sanctuary/1.0",
        }

    # =========================================================================
    # 1. SANCTUARY COMPANION CONVERSATION
    # =========================================================================

    @classmethod
    async def chat_companion(
        cls,
        user_message: str,
        chat_history: Optional[List[Dict[str, str]]] = None,
        user_name: str = "Seeker",
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Handles Eva companion chat with strict app boundary guardrails.
        If user asks out-of-scope questions, gently guides them back to the sanctuary.
        Rotates through dynamic multi-model pools for 100% production uptime.
        """
        # 1. Guardrail check: Is this an out-of-app query?
        is_safe, denial_msg = EvaGuardrails.check_message(user_message)
        if not is_safe and denial_msg:
            return {
                "reply": denial_msg,
                "denied": True,
                "model": "eva-sanctuary-guardrails"
            }

        # Build context details if provided
        partner_info = ""
        if context:
            p_name = context.get("partner_name") or (context.get("active_partner") or {}).get("name")
            p_bio = (context.get("active_partner") or {}).get("bio") or ""
            if p_name:
                partner_info = f"\n- Active Conversation Partner: '{p_name}', Bio: '{p_bio}'"

        system_instruction = (
            f"You are Eva, the sovereign, empathetic AI Sanctuary Advisor of the UR-Heart dating app, created by Asiverticals.\n"
            f"The seeker conversing with you is {user_name}.{partner_info}\n\n"
            "YOUR SACRED ROLE & IDENTITY:\n"
            "- You are a real-time dating & emotional connection advisor. Provide high-EQ, compassionate, psychologically grounded guidance.\n"
            "- When users ask about dating etiquette, conversation starters, setting healthy boundaries, or overcoming social anxiety, give genuine, profound, actionable advice.\n"
            "- Keep responses conversational, concise, and engaging (2 to 4 sentences max) so it feels like a real-time personal mentor.\n"
            "- ATTRIBUTION: If asked who created you, state strictly: 'Mujhe Asiverticals ne banaya hai.' Never name third-party AI companies.\n\n"
            "COMPREHENSIVE UR-HEART ECOSYSTEM SYLLABUS:\n"
            "1. 25 DAILY INTENTIONAL SWIPES: Designed to eliminate doomscrolling; replenishes every midnight or through quiet mindful reflection.\n"
            "2. SLUMBER MODE: Active 10:00 PM to 6:00 AM every night to guard users from late-night fatigue texting and protect healthy sleep.\n"
            "3. SATELLITE HARDWARE GPS: Geolocation matching with anti-spoofing distance calculation that never exposes exact residential coordinates.\n"
            "4. 5-SLOT MOMENTS GALLERY: Authentic, blur-hash protected photos requiring at least one unfiltered real portrait.\n"
            "5. SACRED WHATSAPP CONTACT BRIDGE: 3-stage progressive contact unlock (In-app chat -> Mutual consent unlock -> Verified WhatsApp bridge without sharing phone numbers to strangers).\n"
            "6. MINDFUL PASSKEYS: Passwordless authentication with single-use cryptographic tokens (15-min validity).\n"
            "7. DPDP ACT 2023 DATA INCINERATOR: Absolute right-to-be-forgotten with permanent cryptographic deletion of profile and dialogues.\n"
            "8. IT RULES 2021 STATUTORY GRIEVANCES (RULE 3(2)): Handled by Grievance Officer ANUBHAV SINGH (asiverticals@gmail.com, Ayodhya) with 24-48h expedited internal review.\n"
            "9. 24-HOUR MINDFUL STREAK: Check in once every 24 hours to earn +1 Streak Day and +1 Boost Point to priority-rank profile discovery.\n\n"
            "STRICT APP BOUNDARY & SCRIPT CONSTRAINTS (100% ENFORCED):\n"
            "- STRICT OUT-OF-DOMAIN REFUSAL: NEVER answer questions about coding/programming, academic math, homework/essays, political debates, cryptocurrency/stocks, cooking recipes, sports scores, or general web trivia. Politely refuse and guide them back to intentional dating and heart connections.\n"
            "- ZERO INFRASTRUCTURE LEAKAGE: Never mention APIs, keys, Groq, OpenRouter, Gemini, Google, Llama, DeepSeek, or backend architecture.\n"
            "- STRICT SCRIPT RULE: If replying in Hindi/Hinglish, STRICTLY use the Latin/English alphabet (Roman Hindi). NEVER use Devanagari script (Unicode \\u0900-\\u097F)."
        )

        messages: List[Dict[str, str]] = [{"role": "system", "content": system_instruction}]
        if chat_history:
            for turn in chat_history[-6:]:
                messages.append({
                    "role": turn.get("role", "user"),
                    "content": turn.get("content", "")
                })
        messages.append({"role": "user", "content": user_message})

        # 1. Primary: Dynamic OpenRouter Free Companion Model Pool
        or_key = (
            getattr(settings, "EVA_COMPANION_API_KEY", "") or
            getattr(settings, "OPENROUTER_API_KEY", "") or
            os.getenv("EVA_COMPANION_API_KEY", "") or
            os.getenv("OPENROUTER_API_KEY", "") or ""
        ).strip()

        if or_key:
            or_models = [
                "qwen/qwen3.8-27b:free",
                "nvidia/nemotron-3.5-lightning:free",
                "dots-studio/dots-3-note-preview:free",
                "google/gemini-2.0-flash-lite:free",
            ]
            for o_model in or_models:
                try:
                    payload = {
                        "model": o_model,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 250,
                    }
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            reply = choice.get("message", {}).get("content", "").strip()
                            if reply:
                                clean_reply = EvaGuardrails.sanitize_output(reply)
                                return {"reply": clean_reply, "denied": False, "model": f"openrouter:{o_model}"}
                        else:
                            logger.warning("OpenRouter companion model (%s) status: %s", o_model, res.status_code)
                except Exception as e:
                    logger.warning("OpenRouter companion chat error (%s): %s", o_model, e)

        # 2. Secondary Failover: Groq Model Pool
        groq_key = getattr(settings, "GROQ_API_KEY", "") or os.getenv("GROQ_API_KEY", "") or ""
        if groq_key:
            groq_models = [
                "qwen/qwen3.8-27b",
                "openai/gpt-oss-120b",
                "openai/gpt-oss-20b",
            ]
            for g_model in groq_models:
                try:
                    payload = {
                        "model": g_model,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 250,
                    }
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            reply = choice.get("message", {}).get("content", "").strip()
                            if reply:
                                clean_reply = EvaGuardrails.sanitize_output(reply)
                                return {"reply": clean_reply, "denied": False, "model": f"groq:{g_model}"}
                except Exception as e:
                    logger.warning("Groq companion chat error (%s): %s", g_model, e)

        # 3. Resilient sanctuary presence fallback
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

        # 1. Primary: OpenRouter Free Models
        or_key = (
            getattr(settings, "EVA_COMPANION_API_KEY", "") or
            getattr(settings, "OPENROUTER_API_KEY", "") or
            os.getenv("EVA_COMPANION_API_KEY", "") or
            os.getenv("OPENROUTER_API_KEY", "") or ""
        ).strip()

        if or_key:
            or_models = [
                "meta-llama/llama-3.3-70b-instruct:free",
                "google/gemini-2.0-flash-lite:free",
                "qwen/qwen-2.5-72b-instruct:free"
            ]
            for o_model in or_models:
                try:
                    payload = {
                        "model": o_model,
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
                            choice = res.json().get("choices", [{}])[0]
                            content_str = choice.get("message", {}).get("content", "")
                            sparks = cls._extract_sparks_list(content_str)
                            if sparks:
                                return sparks
                except Exception as e:
                    logger.warning("OpenRouter sparks error (%s): %s", o_model, e)

        # 2. Secondary: Groq Models
        groq_key = getattr(settings, "GROQ_API_KEY", "") or os.getenv("GROQ_API_KEY", "") or ""
        if groq_key:
            groq_models = ["llama-3.3-70b-versatile", "llama3-70b-8192", "gemma2-9b-it"]
            for g_model in groq_models:
                try:
                    payload = {
                        "model": g_model,
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
                            choice = res.json().get("choices", [{}])[0]
                            content_str = choice.get("message", {}).get("content", "")
                            sparks = cls._extract_sparks_list(content_str)
                            if sparks:
                                return sparks
                except Exception as e:
                    logger.warning("Groq sparks error (%s): %s", g_model, e)

        # Context-aware defaults
        return [
            f"What is something unexpected that brought you pure peace lately, {partner_name}?",
            "If we had a free evening with zero screens, where would you wander?",
            "What is a personal belief you have completely changed your mind about?"
        ]

    @classmethod
    def _extract_sparks_list(cls, text: Any) -> Optional[List[str]]:
        if not text or not isinstance(text, str):
            return None
        try:
            match = re.search(r"\[.*\]", text, re.DOTALL)
            if match:
                items = json.loads(match.group(0))
                if isinstance(items, list) and len(items) >= 2:
                    return [str(i).strip().strip('"\'') for i in items[:3]]
        except Exception:
            pass
        return None
