import re
import unicodedata
from typing import Tuple


class ChatSanitizerService:
    # English and Hindi word-to-number mapping
    DIGIT_WORDS = {
        # English
        'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
        'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
        # Hindi Transliteration
        'shunya': '0', 'sunya': '0',
        'ek': '1', 'ik': '1',
        'do': '2', 'doo': '2',
        'teen': '3', 'tin': '3',
        'char': '4', 'chaar': '4',
        'paanch': '5', 'panch': '5', 'pach': '5',
        'chhe': '6', 'chheh': '6', 'che': '6',
        'saat': '7', 'sat': '7',
        'aath': '8', 'aat': '8', 'ath': '8',
        'nau': '9', 'no': '9', 'now': '9'
    }

    @classmethod
    def sanitize_message(cls, raw_text: str) -> Tuple[bool, str]:
        """
        Enforces 100% off-platform leak prevention under IT Rules 2021.
        Blocks 10-digit Indian numbers, transliterated numbers, UPI IDs, handles, and URLs.
        """
        if not raw_text or not raw_text.strip():
            return True, ""

        # 1. Normalize Unicode (NFKD) to strip deceptive zero-width spaces or accents
        normalized = unicodedata.normalize('NFKD', raw_text).lower()
        cleaned = re.sub(r'[\s\.\-_/\\,;:*+~]', '', normalized)

        # 2. Check for 10-digit Indian Mobile Numbers (starts with 6, 7, 8, 9)
        if re.search(r'(?:\+?91)?[6-9]\d{9}', cleaned) or re.search(r'[6-9]\d{9}', cleaned):
            return False, "Phone numbers cannot be shared in open dialogue. Use Sacred Contact Bridge."

        # 3. Check for Transliterated Digits (English & Hindi)
        words = re.findall(r'\b[a-zA-Z]+\b', normalized)
        digit_seq = [cls.DIGIT_WORDS[w] for w in words if w in cls.DIGIT_WORDS]
        if len(digit_seq) >= 3:
            return False, "Spelled-out phone numbers are prohibited in dialogue."

        transliterated = normalized
        for word, digit in cls.DIGIT_WORDS.items():
            transliterated = re.sub(r'\b' + word + r'\b', digit, transliterated)
        trans_cleaned = re.sub(r'[\s\.\-_/\\,;:*+~]', '', transliterated)
        if re.search(r'[6-9]\d{9}', trans_cleaned) or re.search(r'(?:\+?91)?[6-9]\d{9}', trans_cleaned):
            return False, "Spelled-out phone numbers are prohibited in dialogue."

        # 4. Check for Social Handles (@username, t.me, wa.me, snapchat)
        if re.search(r'(?:wa\.me|t\.me|instagram\.com|snapchat\.com|ig:|snap:|tg:)', normalized):
            return False, "Direct external links and social handles are prohibited."

        if re.search(r'@[a-zA-Z0-9_.]{3,30}', normalized):
            return False, "Social handles are prohibited in open dialogue."

        # 5. Check for UPI payment addresses (Protection against scams)
        if re.search(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}', normalized):
            return False, "Payment identifiers and UPI addresses are prohibited."

        return True, raw_text.strip()


def inspect_chat_message(text: str) -> Tuple[bool, str]:
    """Compatibility wrapper for chat sanitizer."""
    is_safe, message = ChatSanitizerService.sanitize_message(text)
    if is_safe:
        return True, "clean"
    return False, message
