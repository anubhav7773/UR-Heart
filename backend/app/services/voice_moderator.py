import re
import unicodedata
from typing import Optional, Tuple
import httpx

from app.core.config import get_settings
from app.services.chat_sanitizer import ChatSanitizerService


class VoiceModeratorService:
    """
    Dedicated AI Speech-to-Text (STT) gatekeeper for Voice Spark recordings.
    Uses Groq's whisper-large-v3-turbo with a dedicated API key to prevent
    revenue bypass (speaking phone numbers, social handles, or off-platform IDs).
    """

    # Spoken solicitation and platform leak indicators
    VOICE_LEAK_REGEXES = [
        re.compile(r"\b(?:insta(?:gram)?|ig)\b", re.IGNORECASE),
        re.compile(r"\b(?:snap(?:chat)?)\b", re.IGNORECASE),
        re.compile(r"\b(?:telegram|tg)\b", re.IGNORECASE),
        re.compile(r"\b(?:whats?app|wa)\b", re.IGNORECASE),
        re.compile(r"\b(?:call|phone)\s*(?:me|karo|karna|kar|number)\b", re.IGNORECASE),
        re.compile(r"\b(?:contact|dm)\s*(?:me|karo|karna|karein|on)\b", re.IGNORECASE),
        re.compile(r"\b(?:number\s+likho|number\s+hai|mera\s+number)\b", re.IGNORECASE),
        re.compile(r"\b(?:handle\s+hai|id\s+hai|username\s+hai)\b", re.IGNORECASE),
    ]

    @classmethod
    async def transcribe_audio(
        cls,
        content: bytes,
        filename: str = "voice_spark.m4a",
        content_type: str = "audio/m4a"
    ) -> Optional[str]:
        """
        Sends 7-second audio bytes to Groq Whisper API (<300ms transcription).
        Supports English, Hindi, and Hinglish.
        """
        settings = get_settings()
        api_key = getattr(settings, "GROQ_VOICE_API_KEY", "") or ""
        url = getattr(settings, "GROQ_WHISPER_URL", "https://api.groq.com/openai/v1/audio/transcriptions")

        if not api_key:
            print("[VOICE MODERATOR] Warning: GROQ_VOICE_API_KEY missing. Bypassing STT.", flush=True)
            return None

        # Build multipart payload
        files = {
            "file": (filename, content, content_type or "audio/m4a"),
        }
        data = {
            "model": "whisper-large-v3-turbo",
            "response_format": "json"
        }
        headers = {
            "Authorization": f"Bearer {api_key}"
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(url, headers=headers, files=files, data=data)
                if response.status_code == 200:
                    resp_json = response.json()
                    transcript = resp_json.get("text", "").strip()
                    return transcript
                else:
                    print(
                        f"[VOICE MODERATOR] Whisper API error {response.status_code}: {response.text}",
                        flush=True
                    )
                    return None
        except Exception as e:
            print(f"[VOICE MODERATOR] Whisper connection error: {e}", flush=True)
            return None

    @classmethod
    def evaluate_transcript(cls, transcript: str) -> Tuple[bool, str]:
        """
        Evaluates transcribed text for phone numbers, social handles,
        spelled-out digits, and off-platform solicitations.
        """
        if not transcript or not transcript.strip():
            # Pure ambient audio or silence
            return True, "clean"

        # 1. Run through established statutory chat sanitizer
        is_safe, reason = ChatSanitizerService.sanitize_message(transcript)
        if not is_safe:
            return (
                False,
                "Voice Spark mein social handle ya phone number detect hua hai. "
                "Voice Spark sirf dil aur vichaaron ke liye hai. Sacred Bridge ka use karein."
            )

        # 2. Check for voice-specific spoken solicitation keywords
        normalized = unicodedata.normalize("NFKD", transcript).lower()
        for pattern in cls.VOICE_LEAK_REGEXES:
            if pattern.search(normalized):
                return (
                    False,
                    "Voice Spark mein social handle ya phone number detect hua hai. "
                    "Voice Spark sirf dil aur vichaaron ke liye hai. Sacred Bridge ka use karein."
                )

        # 3. Check for 5+ sequential digits (potential partial phone number or PIN)
        clean_digits = re.sub(r"\D", "", normalized)
        if len(clean_digits) >= 5:
            return (
                False,
                "Voice Spark mein numbers detect huye hain. "
                "Voice Spark sirf dil aur vichaaron ke liye hai. Sacred Bridge ka use karein."
            )

        return True, "clean"

    @classmethod
    async def inspect_voice_spark(
        cls,
        content: bytes,
        filename: str = "voice_spark.m4a",
        content_type: str = "audio/m4a"
    ) -> Tuple[bool, str, str]:
        """
        Full gatekeeper pipeline:
        Transcribes audio -> Evaluates transcript against compliance rules.
        Returns: (is_safe, transcript, reason_if_blocked)
        """
        transcript = await cls.transcribe_audio(content, filename, content_type)
        if transcript is None:
            # If Groq Whisper is unavailable or timeout, fail-open gracefully with warning
            # so legitimate users are not blocked by external network blips.
            return True, "", "Whisper service unavailable, audio approved."

        is_safe, reason = cls.evaluate_transcript(transcript)
        if not is_safe:
            return False, transcript, reason

        return True, transcript, "Voice Spark verified safe."
