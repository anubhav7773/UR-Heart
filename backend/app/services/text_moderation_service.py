import re
from typing import Tuple

# Explicit, abusive, and harassing keywords (Hinglish, Hindi, English)
PROFANITY_AND_ABUSE_KEYWORDS = {
    "abuse", "harass", "nude", "sex", "hookup", "slut", "randi", "chutiya",
    "bhadwe", "bkl", "bsdk", "fuck", "bitch", "whore", "porn", "xxx",
    "rate", "paid", "callgirl", "escort", "nudes", "strip"
}

# Regex pattern for external links, WhatsApp links, Telegram handles, and URLs
URL_REGEX = re.compile(
    r'(https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9_-]+\.(com|org|net|me|in|io|app)|t\.me/[^\s]+|wa\.me/[^\s]+)',
    re.IGNORECASE
)

# Regex pattern for 10-digit phone numbers and masked contact numbers
PHONE_REGEX = re.compile(
    r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}|\b\d{10}\b'
)


def validate_direct_dm_content(text: str) -> Tuple[bool, str]:
    """
    Screens direct DM content for abuse, explicit content, links, and contact numbers.
    Returns (is_valid, reason).
    """
    if not text or not text.strip():
        return False, "Message content cannot be empty."

    clean_text = text.strip()

    # 1. Block external links
    if URL_REGEX.search(clean_text):
        return False, "Prohibited: External links, websites, and handles are not allowed in direct DMs."

    # 2. Block phone numbers and contact leaks
    if PHONE_REGEX.search(clean_text):
        return False, "Prohibited: Sharing phone numbers or off-platform contacts is not allowed."

    # 3. Block abusive, explicit, or harassing vocabulary
    lowered = clean_text.lower()
    tokens = set(re.findall(r'\b\w+\b', lowered))

    matched_abuses = tokens.intersection(PROFANITY_AND_ABUSE_KEYWORDS)
    if matched_abuses:
        return False, "Prohibited: Message contains abusive or explicit language."

    return True, "Approved"
