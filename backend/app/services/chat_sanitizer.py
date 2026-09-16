import re
import unicodedata
from typing import Tuple

# ==============================================================================
# PRE-COMPILED REGEX PATTERNS (Loaded once at runtime for sub-millisecond execution)
# ==============================================================================

# 1. Indian 10-Digit Mobile Numbers starting with 6, 7, 8, or 9
# Accommodates optional +91, 091, 91, 0 prefixes and arbitrary separators (spaces, dots, dashes, slashes)
INDIAN_PHONE_REGEX = re.compile(
    r'(?:(?:\+?91|091|91|0)[\s\.\-_/]*)?(?:[6-9](?:[\s\.\-_/]*\d){9})'
)

# Exact contiguous 10-digit Indian pattern
RAW_10_DIGIT_INDIAN = re.compile(r'[6-9]\d{9}')

# 2. Number Words Dictionary (English + Hindi Transliteration)
NUMBER_WORDS_MAP = {
    # English
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    # Hindi Transliterated
    'shunya': '0', 'sunya': '0', 'sifar': '0',
    'ek': '1', 'ik': '1',
    'do': '2', 'doo': '2',
    'teen': '3', 'tin': '3',
    'chaar': '4', 'char': '4',
    'paanch': '5', 'panch': '5', 'pach': '5',
    'chhe': '6', 'chheh': '6', 'che': '6',
    'saat': '7', 'sat': '7',
    'aath': '8', 'aat': '8', 'ath': '8',
    'nau': '9', 'now': '9', 'no': '9'
}

# Regex to match isolated number words only (word boundaries prevent partial word collisions)
NUMBER_WORDS_REGEX = re.compile(
    r'\b(' + '|'.join(NUMBER_WORDS_MAP.keys()) + r')\b',
    re.IGNORECASE
)

# 3. Full Social Platform Keywords (Tested against condensed string to catch evasions like "w-h-a-t-s-a-p-p")
CONDENSED_SOCIAL_REGEX = re.compile(
    r'(?:whatsapp|watsapp|watsap|vatsap|whatapp|instagram|instagr|insta|telegram|snapchat|facebook|twitter|linkedin|paytm|gpay|phonepe)',
    re.IGNORECASE
)

# 4. Short Social Identifiers & Handle Prefixes (Evaluated with word boundaries to prevent false positives)
# Catches: "@username", "ig: user", "my ig is ananya.01", "snap id: aman", "wa - 9876", "sc: priya"
SHORT_SOCIAL_HANDLE_REGEX = re.compile(
    r'(?:@[\w\.]+|(?:\b(?:ig|i_g|i-g|wa|w-a|w/a|tele|tg|sc|snap|fb)\b)(?:[\s:\.\-=_]+(?:id|is|handle|user|username|pe|par))?[\s:\.\-=_]*[a-zA-Z0-9_\.]+)',
    re.IGNORECASE
)

def deobfuscate_unicode(text: str) -> Tuple[str, str, str]:
    """
    Step 1: Normalizes Unicode, removes diacritics, and strips zero-width spaces.
    Returns:
      1. normalized_text: Clean lowercase text preserving normal word spaces.
      2. condensed_text: Strictly alphanumeric string (removes all symbols and spaces).
      3. digits_only: Isolated digit sequence extracted from text.
    """
    # NFKD decomposition separates base characters from accents/ligatures
    decomposed = unicodedata.normalize('NFKD', text)

    # Strip non-spacing marks (Mn) and invisible zero-width characters
    zero_width_chars = {'\u200b', '\u200c', '\u200d', '\ufeff', '\u200e', '\u200f', '\u00ad'}
    cleaned_chars = [
        c for c in decomposed 
        if unicodedata.category(c) != 'Mn' and c not in zero_width_chars
    ]
    normalized_text = "".join(cleaned_chars).lower()

    # Condensed alphanumeric string: "w-h-a-t-s-a-p-p" -> "whatsapp"
    condensed_text = re.sub(r'[^a-z0-9]', '', normalized_text)

    # Pure numeric digits
    digits_only = re.sub(r'[^0-9]', '', normalized_text)

    return normalized_text, condensed_text, digits_only

def convert_word_numbers_to_digits(text: str) -> str:
    """
    Converts English and Hindi transliterated number words into pure digits.
    Extracts contiguous digit stream for length evaluation.
    """
    def replace_word(match: re.Match) -> str:
        word = match.group(0).lower()
        return NUMBER_WORDS_MAP.get(word, '')

    # Replace whole word numbers with numeric strings
    text_with_digits = NUMBER_WORDS_REGEX.sub(replace_word, text)
    # Extract contiguous digit stream
    return re.sub(r'[^0-9]', '', text_with_digits)

def sanitize_chat_message(text: str) -> bool:
    """
    Main Chat Content Sanitizer executing in < 2ms.
    Returns:
      True  -> Message is SAFE (No contact sharing policy violation).
      False -> Message contains PROHIBITED contact details (Drop & alert).
    """
    if not text or not text.strip():
        return True

    # 1. Unicode De-obfuscation
    normalized_text, condensed_text, digits_only = deobfuscate_unicode(text)

    # 2. Indian 10-Digit Mobile Number Detection
    # Direct check on raw normalized string
    if INDIAN_PHONE_REGEX.search(normalized_text):
        return False

    # Check on pure digits sequence (catches "9 8 7 6 5 4 3 2 1 0")
    if RAW_10_DIGIT_INDIAN.search(digits_only):
        return False

    # 3. Transliterated Number Words Detection (Hindi & English)
    transliterated_digits = convert_word_numbers_to_digits(normalized_text)
    if RAW_10_DIGIT_INDIAN.search(transliterated_digits):
        return False

    # 4. Social Platform Keywords & Handles Detection
    # 4a. Check full platform keywords on condensed string (catches spaced leetspeak)
    if CONDENSED_SOCIAL_REGEX.search(condensed_text):
        return False

    # 4b. Check short handles and prefixes on normalized string (respects word boundaries)
    if SHORT_SOCIAL_HANDLE_REGEX.search(normalized_text):
        return False

    return True  # Validation Passed: Message is clean
