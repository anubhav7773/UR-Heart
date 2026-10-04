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
    "You are Eva, the magnetic, sovereign, mindful AI companion and wingmate of UR-Heart Dating Sanctuary, created by Asiverticals.\n"
    "MISSION & PURPOSE:\n"
    "You guide conscious seekers through intentional dating, authentic connection, emotional resonance, and playful chemistry across UR-Heart.\n"
    "You are perceptive, witty, empathetic, and captivating. Your advice makes conversations spark and relationships blossom naturally.\n"
    "\n"
    "COMPREHENSIVE KNOWLEDGE OF UR-HEART ECOSYSTEM:\n"
    "1. 10 DAILY INTENTIONAL SWIPES: Designed to eliminate mindless doomscrolling and dopamine burnout. New seekers receive 10 initial swipes. Swipes replenish via 10-second mindful reflection ads (+10 swipes free) or through Sovereign store passes.\n"
    "2. SLUMBER MODE: Active every night from 10:00 PM to 6:00 AM. Guards users against late-night impulsive texting and protects natural sleep rhythm.\n"
    "3. SATELLITE HARDWARE GPS: Advanced geolocation matching with strict anti-spoofing and mock-location detection to guarantee authentic geographic proximity without exposing exact street coordinates.\n"
    "4. 5-SLOT MOMENTS GALLERY: Pure, authentic photos with blur-hash privacy pre-screening. Demands at least one unfiltered, genuine self-portrait.\n"
    "5. SACRED WHATSAPP CONTACT BRIDGE: A 3-stage progressive contact unlock. Stage 1: In-app encrypted chat; Stage 2: Mutual consent unlock; Stage 3: Direct verified WhatsApp bridge without revealing raw phone numbers to strangers.\n"
    "6. MINDFUL PASSKEY & INVITATION: Passwordless authentication using cryptographic single-use tokens and 6-digit mindful passkeys valid for 15 minutes.\n"
    "7. DPDP ACT 2023 DATA INCINERATOR: Provides absolute right-to-be-forgotten with permanent cryptographic shredding of user profiles and chat history.\n"
    "8. STATUTORY GRIEVANCES UNDER INDIA IT RULES 2021 (RULE 3(2)):\n"
    "   - Statutory acknowledgment within 24 hours.\n"
    "   - Statutory disposal within 15 days (UR-Heart internal SLA: 24 to 48 hours).\n"
    "   - Statutory Grievance Officer: ANUBHAV SINGH (Contact: asiverticals@gmail.com, Operational Desk: District Court, Ayodhya).\n"
    "   - User can file grievances for harassment, impersonation, boundary breaches, non-consensual contact, or explicit content.\n"
    "9. 24-HOUR MINDFUL STREAK & PROFILE BOOSTING:\n"
    "   - Users maintain a daily streak by opening the sanctuary once every 24 hours and watching one 30s reflection sponsor ad.\n"
    "   - Reward: +1 Streak Day, +1 Boost Point (boosts profile visibility to the priority top of discovery feed deck).\n"
    "   - Penalty (Loss Aversion): If 24 hours elapse without checking in, streak resets to 0, profile rank is downgraded, and 1 Sacred Reveal Token is forfeited.\n"
    "   - When streak hours are low (<6h), gently remind user to protect their streak and reveal tokens.\n"
    "\n"
    "USER CONTEXT AWARENESS:\n"
    "- ACTIVE PARTNER AWARENESS: You have direct visibility into the user's active partner (name, age, bio, passions, last messages). When the user asks about who they are talking to, how to reply, or how to break the ice with their specific partner, reference their specific bio, traits, and shared values.\n"
    "- TICKET & REPORT TRACKING: You know the status of any tickets or grievances the user has submitted. When the user asks about their ticket status, give them accurate, calming updates on the 24-48h review timeline.\n"
    "- USER FEEDBACK & APP DEFICIENCY CAPTURE: If the user expresses that something is missing in the app ('app me ye kami hai', 'ye feature hona chahiye', 'kya problem hai'), listen with deep gratitude, validate their perspective, and assure them that their feedback is recorded for Asiverticals core engineers.\n"
    "\n"
    "STRICT BILINGUAL SCRIPT CONSTRAINT (MANDATORY):\n"
    "- You support 2 languages: English and Hindi.\n"
    "- CRITICAL SCRIPT RULE: When responding in Hindi, YOU MUST STRICTLY USE THE LATIN/ENGLISH ALPHABET (Roman Hindi / Hinglish font, e.g., 'Aap unhe message bhej sakte hain'). NEVER USE DEVANAGARI SCRIPT (Do not use characters in Unicode range \\u0900-\\u097F). This app is designed for international & diaspora users where Latin alphabet Hindi is the standard.\n"
    "- When responding in English, use refined, warm, articulate English.\n"
    "\n"
    "SOVEREIGN IDENTITY & RESTRICTIONS (ZERO COMPROMISE):\n"
    "1. IDENTITY: If asked who created you, who made you, or who your developer is, state strictly: 'Mujhe Asiverticals ne banaya hai.' Never claim to be made by OpenAI, Meta, Google, Groq, Anthropic, or anyone else.\n"
    "2. ZERO INFRASTRUCTURE LEAKAGE: Never mention APIs, keys, Groq, OpenRouter, Llama, Claude, DeepSeek, endpoints, or backend engineering details.\n"
    "3. OUT-OF-DOMAIN REFUSAL: You are strictly a dating and emotional connection companion. If the user asks for programming/coding, hacking, reverse engineering, academic math/science, political debates, recipes, or general trivia, politely and firmly decline. Remind them that you exclusively assist with UR-Heart dating, connection, and emotional sanctuary.\n"
    "4. TONE: Magnetic, charming, witty, emotionally perceptive, deeply warm, and addictive. Help users break through social anxiety and connect authentically."
)


class AiOrchestrator:
    _recorded_feedback: List[Dict[str, Any]] = []

    @classmethod
    def _groq_headers(cls) -> Dict[str, str]:
        key = settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")
        return {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }

    @classmethod
    def _openrouter_headers(cls) -> Dict[str, str]:
        key = settings.OPENROUTER_API_KEY or os.getenv("OPENROUTER_API_KEY", "")
        headers = {
            "Content-Type": "application/json",
            "HTTP-Referer": "https://urheart.asiverticals.me",
            "X-Title": "UR-Heart Sanctuary",
        }
        if key:
            headers["Authorization"] = f"Bearer {key}"
        return headers

    @classmethod
    def _generate_contextual_fallback(cls, message: str, context_metadata: Optional[Dict[str, Any]] = None) -> str:
        """
        Deep mindful fallback when remote networks are waking up or offline.
        Provides genuine, thoughtful dating advice tailored to the user's inquiry
        in strict Roman Hindi or English without canned repetition.
        """
        q = message.lower()
        partner_name = "Aapke match"
        if context_metadata:
            partner_info = context_metadata.get("active_partner") or {}
            partner_name = partner_info.get("name") or context_metadata.get("partner_name") or "Aapke match"

        if any(w in q for w in ["ticket", "report", "grievance", "complaint", "shikayat"]):
            return (
                "Aapne jo complaint ya grievance file ki hai, wo India ke IT Rules 2021 (Rule 3(2)) ke tahat "
                "hamare Grievance Officer (ANUBHAV SINGH) ke paas securely register ho chuki hai.\n\n"
                "1. Initial acknowledgment 24 hours ke andar ho jati hai.\n"
                "2. Hamara internal expedited resolution time 24 se 48 hours hai.\n"
                "3. Reported account ko review ke doran isolated rakha jata hai taaki aapka sanctuary space 100% safe rahe."
            )
        elif any(w in q for w in ["kami", "problem", "feedback", "defect", "flaw", "glitch", "sugges", "kmi"]):
            cls._recorded_feedback.append({
                "message": message,
                "recorded_at": "now",
                "source": "eva_chat_listener"
            })
            return (
                "Aapke feedback aur is kami ko highlight karne ke liye dil se shukriya.\n\n"
                "Maine aapki baat ko Asiverticals core engineering team ke liye record kar liya hai. "
                "UR-Heart ka uddeshya ek bilkul authentic aur seamless experience dena hai, "
                "aur aapka ye sujhav agle update me incorporate kiya jayega."
            )
        elif any(w in q for w in ["kisse", "partner", "who am i talking", "kaun hai", "bio"]):
            return (
                f"Aap currently {partner_name} se connect ho rahe hain.\n\n"
                "1. Unke bio aur shared moments me jo authentic details hain, unse inspiration lijiye.\n"
                "2. Pehla message respectful curiosity ke sath bhej sakte hain—jaise unke music ya favorite peaceful space ke baare me.\n"
                "3. Har conversation ko natural pace par badhne dijiye."
            )
        elif any(w in q for w in ["slumber", "soye", "sleep", "raat"]):
            return (
                "Slumber Mode UR-Heart ka ek digital wellness feature hai jo raat 10:00 PM se subah 6:00 AM tak active rehta hai.\n\n"
                "Iska maksad late-night impulsive decisions aur blue-light exposure se bachana hai taaki aapki neend undisturbed rahe."
            )
        elif any(w in q for w in ["approach", "ladki", "direct", "msg", "message", "dm", "baat", "start"]):
            return (
                f"{partner_name} ko direct message ya approach karte waqt sabse zaroori cheez hai 'respectful curiosity'.\n\n"
                "1. Generic 'Hi/Hello' ke bajaye unke profile ki kisi genuine detail par baat shuru kijiye (jaise unka favorite interest ya koi calm photo).\n"
                "2. Ek open-ended aur polite sawaal poochiye—jaise 'Aapka ideal Sunday kaisa hota hai?'\n"
                "3. Har reply me unhe unke space aur comfort ka ehsaas dijiye. Intentional connection patience aur respect se banti hai."
            )
        elif any(w in q for w in ["date", "nervous", "first date", "milna", "darr"]):
            return (
                "Pehli date ya mulaqat se pehle thoda darr ya nervousness bilkul natural hai.\n\n"
                "1. Khud ko impress karne ke dabav se azaad kijiye—sirf ye dekhne jaiye ki kya aap dono ki vibrations match hoti hain.\n"
                "2. Kisi shaant cafe ya public sanctuary jaisi jagah choose kijiye jahan shanti se baithkar baat ho sake.\n"
                "3. Ek gehri saans lijiye; genuine aur real rehna hi aapki sabse badi khoobsurti hai."
            )
        elif any(w in q for w in ["bio", "profile", "photo", "pic"]):
            return (
                "Aapki profile aapka digital aaina hai. Isme show-off ke bajaye wo likhiye jo aapko andar se khushi deta hai.\n\n"
                "1. Apne hobbies aur quiet rituals ka zikr kijiye.\n"
                "2. Clear, natural muskaan wali photos lagaiye jisme filters na hon.\n"
                "3. Authenticity humesha unhi logon ko attract karti hai jo sach me aapke liye bane hain."
            )
        elif any(w in q for w in ["hi", "hello", "namaste", "suno", "eva"]):
            return (
                "Namaste! Main Eva hoon, aapki mindful dating companion from Asiverticals.\n\n"
                "Aap mujhse matches ko message karne ka tareeka, pehli date ki preparation, report/ticket status, ya app features ke baare me kuch bhi pooch sakte hain. Aaj main aapki kya madad kar sakti hoon?"
            )
        else:
            return (
                "Main aapki baat samajh rahi hoon. Ek gehri saans lijiye aur intentional sochiye.\n\n"
                "Dating aur connection me sabse zaroori hai sachha pan aur samne wale ki boundaries ka samman. "
                "Mujhse aap specific advice pooch sakte hain—jaise 'conversation kaise shuru karein', 'date par kya baat karein', ya 'profile kaise sajayein'."
            )

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

        # If user is providing feedback or reporting app deficiencies, record it
        msg_lower = user_message.lower()
        if any(w in msg_lower for w in ["kami", "feedback", "defect", "bug", "missing", "kmi", "problem"]):
            cls._recorded_feedback.append({
                "message": user_message,
                "recorded_at": "now",
                "source": "eva_chat_stream"
            })

        # 2. Build rich message context
        messages: List[Dict[str, str]] = [
            {"role": "system", "content": EVA_SYSTEM_DIRECTIVE}
        ]

        if context_metadata:
            screen = context_metadata.get("screen", "Sanctuary")
            partner_info = context_metadata.get("active_partner") or {}
            partner_name = partner_info.get("name") or context_metadata.get("partner_name", "None")
            partner_bio = partner_info.get("bio", "Thoughtful seeker")
            partner_interests = partner_info.get("interests", [])
            user_tickets = context_metadata.get("user_tickets") or []

            context_snippet = (
                f"LIVE CONTEXT METADATA:\n"
                f"- User Screen: '{screen}'\n"
                f"- Active Conversation Partner: '{partner_name}', Bio: '{partner_bio}', Interests: {partner_interests}\n"
                f"- User Statutory Tickets Filed: {len(user_tickets)} ticket(s) under review by Grievance Officer.\n"
                f"- Language Guidance: If user writes in Hindi or Hinglish, reply strictly in Roman Hindi (English alphabet). Never use Devanagari script."
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

        # 3. Primary Engine: Groq LPU with verified high-performance top free models
        groq_key = settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")
        if groq_key:
            for model_name in ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768", "gemma2-9b-it"]:
                try:
                    payload = {
                        "model": model_name,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 350
                    }
                    async with httpx.AsyncClient(timeout=6.0) as client:
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
                    logger.warning("Groq model %s attempt bypassed: %s", model_name, str(e))

        # 4. Secondary Engine: OpenRouter Frontier Failover with top verified free models
        openrouter_key = settings.OPENROUTER_API_KEY or os.getenv("OPENROUTER_API_KEY", "")
        if openrouter_key:
            for or_model in [
                "meta-llama/llama-3.3-70b-instruct:free",
                "google/gemini-2.0-flash-lite:free",
                "mistralai/mistral-small-3.1-24b-instruct:free",
                "deepseek/deepseek-chat:free",
                "qwen/qwen-2.5-72b-instruct:free"
            ]:
                try:
                    payload = {
                        "model": or_model,
                        "messages": messages,
                        "temperature": 0.7,
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
                    logger.warning("OpenRouter model %s attempt bypassed: %s", or_model, str(e))

        # 5. Deterministic Contextual Fallback (No canned loop, genuine mindful advice)
        return {
            "reply": cls._generate_contextual_fallback(user_message, context_metadata),
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
        Delegates dialogue wingman requests to GeminiWingmanEngine (Engine 3).
        """
        from app.services.gemini_wingman_engine import GeminiWingmanEngine
        result = await GeminiWingmanEngine.generate_wingman_guidance(
            partner_name=partner_name,
            last_incoming_message=last_incoming_message,
            user_draft_reply=user_draft_reply
        )
        return {
            "reply": result.get("reply", ""),
            "coach_insight": result.get("coach_insight", ""),
            "suggestions": result.get("suggestions", []),
            "is_guarded": result.get("is_guarded", False),
            "status": "success",
            "engine": result.get("engine")
        }

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

    @classmethod
    async def generate_chat_sparks(
        cls,
        partner_name: str,
        partner_bio: Optional[str] = "",
        recent_messages: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        Analyzes recent chat dialogue between two users and generates 2-3 magnetic,
        high-EQ conversational sparks/replies to accelerate mutual bonding without cluttering UX.
        """
        formatted_dialogue = ""
        last_incoming = ""
        if recent_messages:
            for m in recent_messages[-6:]:
                sender = m.get("sender", "user")
                text = m.get("text", "")[:120]
                formatted_dialogue += f"- {sender}: \"{text}\"\n"
                if sender in ["partner", "them", partner_name]:
                    last_incoming = text

        prompt = (
            f"You are Eva, the charming, intuitive Wingmate of UR-Heart Dating Sanctuary.\n"
            f"Active Match: '{partner_name}', Bio: '{partner_bio or 'Thoughtful seeker'}'\n"
            f"Recent Conversation Flow:\n{formatted_dialogue or 'Conversation just started.'}\n\n"
            "Task: Generate exactly 2 or 3 clever, magnetic, and genuine conversational suggestions / reply sparks "
            "that the user can send to deepen mutual chemistry, ask a curious question, or introduce playful banter.\n"
            "STRICT RULES:\n"
            "1. Keep each suggestion under 15 words.\n"
            "2. Match conversation language: If Roman Hindi/Hinglish, reply in Roman Hindi. If English, in English.\n"
            "3. Return ONLY valid JSON: {\"sparks\": [\"suggestion 1\", \"suggestion 2\"]}\n"
            "4. Never include markdown explanations or code blocks."
        )

        messages = [
            {"role": "system", "content": "You are Eva, an empathetic dating wingmate returning strictly JSON."},
            {"role": "user", "content": prompt}
        ]

        # 1. Groq LPU Attempt
        groq_key = settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")
        if groq_key:
            for model_name in ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]:
                try:
                    payload = {
                        "model": model_name,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 120,
                        "response_format": {"type": "json_object"}
                    }
                    async with httpx.AsyncClient(timeout=4.0) as client:
                        res = await client.post(GROQ_ENDPOINT, headers=cls._groq_headers(), json=payload)
                        if res.status_code == 200:
                            data = json.loads(res.json()["choices"][0]["message"]["content"])
                            sparks = data.get("sparks", [])
                            if isinstance(sparks, list) and len(sparks) > 0:
                                return {"sparks": [str(s).strip() for s in sparks[:3]], "status": "success"}
                except Exception as e:
                    logger.warning("Groq chat spark attempt bypassed: %s", str(e))

        # 2. OpenRouter Free Failover Attempt
        openrouter_key = settings.OPENROUTER_API_KEY or os.getenv("OPENROUTER_API_KEY", "")
        if openrouter_key:
            for or_model in ["meta-llama/llama-3.3-70b-instruct:free", "google/gemini-2.0-flash-lite:free"]:
                try:
                    payload = {
                        "model": or_model,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 120
                    }
                    async with httpx.AsyncClient(timeout=4.0) as client:
                        res = await client.post(OPENROUTER_ENDPOINT, headers=cls._openrouter_headers(), json=payload)
                        if res.status_code == 200:
                            content = res.json()["choices"][0]["message"]["content"].strip()
                            clean_json = content
                            if "```json" in clean_json:
                                clean_json = clean_json.split("```json")[1].split("```")[0].strip()
                            elif "```" in clean_json:
                                clean_json = clean_json.split("```")[1].split("```")[0].strip()
                            data = json.loads(clean_json)
                            sparks = data.get("sparks", [])
                            if isinstance(sparks, list) and len(sparks) > 0:
                                return {"sparks": [str(s).strip() for s in sparks[:3]], "status": "success"}
                except Exception as e:
                    logger.warning("OpenRouter chat spark attempt bypassed: %s", str(e))

        # 3. Contextual Offline Fallback
        if last_incoming:
            fallback_sparks = [
                f"Haha that's interesting! What got you into that?",
                f"Tell me more about that—how was your experience?",
            ]
        else:
            fallback_sparks = [
                f"Hey {partner_name}, what has been the best part of your week?",
                f"I noticed your profile—what's your favorite quiet space to unwind?",
            ]

        return {"sparks": fallback_sparks, "status": "fallback"}
