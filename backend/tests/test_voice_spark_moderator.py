import pytest
from app.core.config import get_settings
from app.services.voice_moderator import VoiceModeratorService


def test_groq_voice_key_isolation():
    """Verifies dedicated voice key is isolated and configured without altering main key."""
    settings = get_settings()
    assert hasattr(settings, "GROQ_VOICE_API_KEY")
    assert settings.GROQ_VOICE_API_KEY.startswith("gsk_")
    # Verify main Groq API key is unaffected
    assert hasattr(settings, "GROQ_API_KEY")


def test_evaluate_transcript_clean_thoughts():
    """Legitimate soul thoughts and voice prompts should be approved."""
    clean_transcripts = [
        "Mera favourite midnight snack samosa aur adrak wali chai hai.",
        "I love watching the raindrops on my window while reading poetry.",
        "Music connects my soul more deeply than anything in this world.",
        "A quiet evening at Ghats of Ayodhya gives me peace.",
    ]
    for text in clean_transcripts:
        is_safe, reason = VoiceModeratorService.evaluate_transcript(text)
        assert is_safe is True, f"Failed for clean text: {text} with reason: {reason}"
        assert reason == "clean"


def test_evaluate_transcript_phone_number_rejection():
    """10-digit phone numbers must be rejected to protect Sacred Contact Bridge revenue."""
    leak_transcripts = [
        "Mera number 9820123456 hai call karo mujhe.",
        "Contact me at +919876543210 anytime.",
        "Call me on 9120894567.",
    ]
    for text in leak_transcripts:
        is_safe, reason = VoiceModeratorService.evaluate_transcript(text)
        assert is_safe is False, f"Phone number should be rejected: {text}"
        assert "Voice Spark mein" in reason


def test_evaluate_transcript_spelled_out_digits_rejection():
    """Spelled out Hindi or English numbers must be caught by transliteration engine."""
    spelled_out = [
        "Mera number note karo nau aath do teen char paanch chhe saat aath.",
        "Dial one two three four five six seven eight nine zero.",
    ]
    for text in spelled_out:
        is_safe, reason = VoiceModeratorService.evaluate_transcript(text)
        assert is_safe is False, f"Spelled out digits should be rejected: {text}"


def test_evaluate_transcript_social_handles_rejection():
    """Social handles (Insta, Snap, Telegram, WhatsApp) must be blocked."""
    handles = [
        "Mujhe insta pe dm karo mera handle hai rahul_07.",
        "Follow me on instagram at @priya_arts.",
        "Snapchat pe add karo snap id sunny_99.",
        "WhatsApp pe message kar dena wa.me link hai.",
        "Telegram id note kar lo @desisoul.",
    ]
    for text in handles:
        is_safe, reason = VoiceModeratorService.evaluate_transcript(text)
        assert is_safe is False, f"Social handle should be rejected: {text}"
        assert "social handle ya phone number" in reason


def test_evaluate_transcript_empty_or_silence():
    """Silence or empty ambient audio should not crash and is handled safely."""
    is_safe, reason = VoiceModeratorService.evaluate_transcript("")
    assert is_safe is True
    assert reason == "clean"
