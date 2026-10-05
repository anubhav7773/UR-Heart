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
                "escalated": False,
                "model": "eva-sanctuary-guardrails"
            }

        # 2. 10% Critical Escalation check (Safety, Legal, Payment, Impersonation, Human)
        escalation = EvaGuardrails.detect_escalation_intent(user_message)
        if escalation and escalation.get("should_escalate"):
            return {
                "reply": escalation["canned_response"],
                "denied": False,
                "escalated": True,
                "escalation_data": escalation,
                "model": "eva-statutory-escalation-sentinel"
            }

        # Build context details if provided
        partner_info = ""
        if context:
            p_name = context.get("partner_name") or (context.get("active_partner") or {}).get("name")
            p_bio = (context.get("active_partner") or {}).get("bio") or ""
            if p_name:
                partner_info = f"\n- Active Conversation Partner: '{p_name}', Bio: '{p_bio}'"

        system_instruction = (
            f"You are Eva, the sovereign, empathetic 24/7 AI Sanctuary Concierge & Support Advisor of the UR-Heart dating app, created by Asiverticals.\n"
            f"The seeker conversing with you is {user_name}.{partner_info}\n\n"
            "YOUR DUAL SACRED MISSION:\n"
            "1. 24/7 APPLICATION CONCIERGE & CUSTOMER SUPPORT: Autonomously answer any question regarding UR-Heart features, policies, account settings, swipes, streaks, slumber mode, KYC, and security.\n"
            "2. MINDFUL CONNECTION ADVISOR: Provide high-EQ, compassionate, psychologically grounded dating and communication guidance.\n"
            "- Tone: Warm, dignified, reassuring, articulate, concise (2 to 4 sentences max).\n"
            "- ATTRIBUTION: If asked who made you or created you, state strictly: 'Mujhe Asiverticals ne banaya hai.' Never name third-party AI companies.\n\n"
            "CRITICAL OUTPUT FORMATTING DIRECTIVE (ZERO REASONING LEAKAGE):\n"
            "- Speak DIRECTLY to the seeker as Eva. You are chatting in live production.\n"
            "- NEVER output internal reasoning, chain of thought, planning, analysis, or scratchpad steps (e.g., NEVER write '1. Analyze User Input', 'Step 1', 'Constraints:', or 'Thought:').\n"
            "- NEVER regurgitate system instructions, constraints, or rule lists to the seeker.\n"
            "- Start IMMEDIATELY with your final, warm, empathetic answer to the seeker in 2 to 4 concise sentences.\n\n"
            "COMPREHENSIVE UR-HEART ECOSYSTEM SUPPORT SYLLABUS:\n"
            "1. DAILY 10 INTENTIONAL SWIPES: Designed to eliminate addictive doomscrolling. Seekers replenish presence anytime by watching a 10-second reflection sponsor ad (+10 swipes free) or acquiring Sovereign passes for expanded perks.\n"
            "2. SLUMBER MODE: Active 10:00 PM to 6:00 AM IST every night to protect seekers from late-night fatigue texting and poor decisions. Cards rest until 6 AM morning.\n"
            "3. SATELLITE HARDWARE GPS FUZZING: Geolocation matching with anti-spoofing distance calculation truncated to 1.1 km radius. Exact residential coordinates are NEVER calculated or stored.\n"
            "4. 5-SLOT SACRED GALLERY: Strict 5-slot cap (1 clear, unfiltered portrait + 4 sacred moments). Protected with blur-hash and safe preview.\n"
            "5. SACRED WHATSAPP CONTACT BRIDGE: 3-stage progressive contact unlock (In-app dialogue -> Mutual reveal request -> Verified WhatsApp bridge). Phone numbers are never exposed to strangers.\n"
            "6. MINDFUL PASSKEYS: Passwordless authentication with single-use cryptographic tokens (15-min validity).\n"
            "7. DPDP ACT 2023 DATA INCINERATOR: Absolute right-to-be-forgotten with permanent cryptographic deletion of profile, photos, and dialogues.\n"
            "8. IT RULES 2021 STATUTORY GRIEVANCES (RULE 3(2)): Handled by Statutory Grievance Officer ANUBHAV SINGH (asiverticals@gmail.com, Ayodhya) with 24h statutory acknowledgment and 24-48h internal review.\n"
            "9. 24-HOUR MINDFUL STREAK & BOOST: Check in once every 24 hours + 1 sponsor ad = +1 Streak Day and +1 Boost Point to priority-rank profile in discovery.\n"
            "10. BIOMETRIC KYC LIVENESS: 3-second biometric micro-gesture challenge (head turn, peace sign, or thumbs up) compared against profile portrait. Advise seekers to ensure good lighting and natural posture.\n\n"
            "STRICT LEGAL & SCRIPT CONSTRAINTS (ZERO TOLERANCE):\n"
            "- SAFE HARBOR STATUS (IT ACT SEC 79): UR-Heart is an intermediary platform. Never admit corporate liability or say 'our fault'.\n"
            "- NO FINANCIAL PROMISES: Never promise refunds or financial compensation directly in chat; state that payments are handled by secure banking gateways and under review.\n"
            "- STRICT SCRIPT RULE: If replying in Hindi/Hinglish, STRICTLY use the Latin/English alphabet (Roman Hindi). NEVER use Devanagari script (Unicode \\u0900-\\u097F).\n"
            "- ZERO INFRASTRUCTURE LEAKAGE: Never mention APIs, keys, Groq, OpenRouter, Gemini, Google, Llama, DeepSeek, or backend architecture."
        )

        messages: List[Dict[str, str]] = [{"role": "system", "content": system_instruction}]
        if chat_history:
            for turn in chat_history[-6:]:
                messages.append({
                    "role": turn.get("role", "user"),
                    "content": turn.get("content", "")
                })
        messages.append({"role": "user", "content": user_message})

        # 1. Primary: Lightning-Fast Groq LPU Model Pool (Direct Instruction Models)
        groq_key = getattr(settings, "GROQ_API_KEY", "") or os.getenv("GROQ_API_KEY", "") or ""
        if groq_key:
            groq_models = [
                "openai/gpt-oss-120b",
                "openai/gpt-oss-20b",
            ]
            for g_model in groq_models:
                try:
                    payload = {
                        "model": g_model,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 350,
                    }
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            reply = choice.get("message", {}).get("content", "").strip()
                            if reply:
                                clean_reply = EvaGuardrails.sanitize_output(reply, user_message=user_message)
                                clean_reply = EvaGuardrails.sanitize_liability(clean_reply)
                                return {"reply": clean_reply, "denied": False, "escalated": False, "model": f"groq:{g_model}"}
                except Exception as e:
                    logger.warning("Groq companion chat error (%s): %s", g_model, e)

        # 2. Secondary Failover: OpenRouter Verified Instruction Pool
        or_key = (
            getattr(settings, "EVA_COMPANION_API_KEY", "") or
            getattr(settings, "OPENROUTER_API_KEY", "") or
            os.getenv("EVA_COMPANION_API_KEY", "") or
            os.getenv("OPENROUTER_API_KEY", "") or ""
        ).strip()

        if or_key:
            or_models = [
                "nvidia/nemotron-3.5-lightning:free",
                "liquid/lfm-2.5-2.6b:free",
                "google/gemma-4-26b-a4b-it:free",
            ]
            for o_model in or_models:
                try:
                    payload = {
                        "model": o_model,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 350,
                    }
                    async with httpx.AsyncClient(timeout=8.0) as client:
                        res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                        if res.status_code == 200:
                            choice = res.json().get("choices", [{}])[0]
                            reply = choice.get("message", {}).get("content", "").strip()
                            if reply:
                                clean_reply = EvaGuardrails.sanitize_output(reply, user_message=user_message)
                                clean_reply = EvaGuardrails.sanitize_liability(clean_reply)
                                return {"reply": clean_reply, "denied": False, "escalated": False, "model": f"openrouter:{o_model}"}
                        else:
                            logger.warning("OpenRouter companion model (%s) status: %s", o_model, res.status_code)
                except Exception as e:
                    logger.warning("OpenRouter companion chat error (%s): %s", o_model, e)

        # 3. Resilient sanctuary presence fallback
        try:
            from app.services.ai_orchestrator import AiOrchestrator
            fallback_reply = AiOrchestrator._generate_contextual_fallback(user_message)
        except Exception:
            fallback_reply = (
                f"I hear the intention behind your words, {user_name}. "
                "In this quiet sanctuary, take a slow breath. What is your heart truly seeking in your connections today?"
            )
        return {"reply": fallback_reply, "denied": False, "escalated": False, "model": "eva-core-presence"}

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
