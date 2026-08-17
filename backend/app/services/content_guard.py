"""
Zero-Leak Content Guard Service
================================
Multi-pass heuristic analyzer that intercepts contact info, phone numbers,
social handles, UPI IDs, and map links before the Safe Bridge is unlocked.

Designed to defeat:
- Leetspeak substitutions (e.g., "n1ne" → "nine" → "9")
- Unicode homoglyphs & Devanagari digits (१२३ → 123)
- Zero-width character injection
- Phonetic English/Hinglish word-number sequences
- Spaced/punctuated digit evasion ("9 8 7-6 5 4-3 2 1 0")
"""

import re
import unicodedata
from typing import Tuple

# ---------------------------------------------------------------------------
# Pass 1: Normalization Tables
# ---------------------------------------------------------------------------

# Devanagari digits ०-९ → 0-9
_DEVANAGARI_DIGITS = str.maketrans("०१२३४५६७८९", "0123456789")

# Circled digits ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩ → 1-9, 10
_CIRCLED_MAP = {
    "①": "1", "②": "2", "③": "3", "④": "4", "⑤": "5",
    "⑥": "6", "⑦": "7", "⑧": "8", "⑨": "9", "⑩": "10",
    "⓪": "0", "⓵": "1", "⓶": "2", "⓷": "3", "⓸": "4",
    "⓹": "5", "⓺": "6", "⓻": "7", "⓼": "8", "⓽": "9",
}

# Fullwidth digits ０-９ → 0-9
_FULLWIDTH_DIGITS = str.maketrans("０１２３４５６７８９", "0123456789")

# Leetspeak substitutions (character → digit)
_LEET_MAP = {
    "o": "0", "l": "1", "i": "1", "|": "1",
    "z": "2", "e": "3", "a": "4", "@": "4",
    "s": "5", "$": "5", "b": "8", "g": "9", "q": "9", "t": "7",
}

# Zero-width & invisible unicode characters to strip
_ZERO_WIDTH_RE = re.compile(
    r"[\u200b\u200c\u200d\u200e\u200f\u2060\u2061\u2062\u2063\u2064\ufeff\u00ad\u034f\u061c\u180e]"
)

# ---------------------------------------------------------------------------
# Pass 2: Phonetic Word-to-Digit Dictionary (English + Hinglish)
# ---------------------------------------------------------------------------

WORD_DIGIT_MAP = {
    # English
    "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
    "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
    "ten": "10",
    # Hinglish / Hindi transliteration
    "ek": "1", "do": "2", "teen": "3", "char": "4", "chaar": "4",
    "panch": "5", "paanch": "5", "chhe": "6", "che": "6", "chha": "6",
    "saat": "7", "sat": "7", "aath": "8", "ath": "8",
    "nau": "9", "no": "9", "shunya": "0", "das": "10",
}

# Compiled regex for word-digit replacement (word boundaries)
_WORD_DIGIT_RE = re.compile(
    r"\b(" + "|".join(re.escape(w) for w in sorted(WORD_DIGIT_MAP.keys(), key=len, reverse=True)) + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pass 3: Regex Pattern Interception
# ---------------------------------------------------------------------------

LEAK_PATTERNS = [
    # Indian phone numbers: +91/91/0 prefix + 10 digits (with optional separators)
    re.compile(r"(\+?91|0)?[\s\.\-_]*[6-9][\s\.\-_]*(\d[\s\.\-_]*){9}", re.IGNORECASE),

    # Any sequence of 7+ digits (after normalization strips separators)
    re.compile(r"\d{7,}"),

    # UPI IDs: user@provider
    re.compile(
        r"[a-zA-Z0-9.\-_]{2,256}@(oksbi|okhdfcbank|okaxis|okicici|paytm|ybl|apl|upi|ibl|"
        r"axl|sbi|hdfcbank|icici|kotak|boi|pnb|federal|indus|rbl|idbi|citi|"
        r"axisbank|idfcfirst|jio|freecharge|mobikwik|airtel|phonepe|gpay)",
        re.IGNORECASE,
    ),

    # Generic email pattern (could leak contact)
    re.compile(r"[a-zA-Z0-9.\-_]{2,64}@[a-zA-Z0-9.\-]{2,64}\.[a-zA-Z]{2,10}", re.IGNORECASE),

    # Social platform keywords followed by handle-like tokens
    re.compile(
        r"(insta|ig|instagram|snap|snapchat|telegram|tg|wa|whatsapp|"
        r"fb|facebook|twitter|x\.com|signal|discord|kik|"
        r"id\s*hai|handle|dm\s*karo|dm\s*me|call\s*me|call\s*karo|"
        r"ping\s*me|ping\s*karo|contact|num|number|no\.|phn|phone|fone|mob)"
        r"[\s\:\-\.=_]*(@?[a-zA-Z0-9._]{3,30})",
        re.IGNORECASE,
    ),

    # Standalone @handles (3+ chars)
    re.compile(r"(?:^|\s)@[a-zA-Z0-9._]{3,30}", re.IGNORECASE),

    # URLs and domain patterns
    re.compile(r"[a-zA-Z0-9_\-]+\.(com|me|in|io|co|ai|org|net|app|dev|xyz)", re.IGNORECASE),

    # Maps / geolocation links
    re.compile(
        r"(maps\.google|goo\.gl|gmap|google\.com/maps|maps\.app|"
        r"coordinates|pin\s*code|pincode|geo:)",
        re.IGNORECASE,
    ),
]

# Patterns checked against the collapsed (no-space) version
LEAK_PATTERNS_COLLAPSED = [
    # Phone numbers that were spaced out
    re.compile(r"(\+?91|0)?[6-9]\d{9}"),
    re.compile(r"\d{7,}"),
]

# Raw handle patterns (e.g., "anubhav8400", "priya_07")
HANDLE_PATTERNS = [
    re.compile(r"\b[a-zA-Z]{3,}[_\.][a-zA-Z0-9_\.]{2,}\b"),
    re.compile(r"\b[a-zA-Z0-9_\.]{3,}[0-9]{2,}\b"),
]


# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

def _normalize_unicode(text: str) -> str:
    """Pass 1: Canonical unicode normalization, homoglyph & script digit conversion."""
    # NFKD decomposition to strip diacritics and normalize compatibility chars
    text = unicodedata.normalize("NFKD", text)

    # Convert Devanagari digits
    text = text.translate(_DEVANAGARI_DIGITS)

    # Convert fullwidth digits
    text = text.translate(_FULLWIDTH_DIGITS)

    # Convert circled digits
    for circle, digit in _CIRCLED_MAP.items():
        text = text.replace(circle, digit)

    # Strip zero-width / invisible characters
    text = _ZERO_WIDTH_RE.sub("", text)

    return text


def _apply_leetspeak(text: str) -> str:
    """Convert leetspeak substitutions to digits."""
    result = []
    for ch in text:
        lower_ch = ch.lower()
        result.append(_LEET_MAP.get(lower_ch, ch))
    return "".join(result)


def _replace_word_digits(text: str) -> str:
    """Pass 2: Replace phonetic English/Hinglish number words with digits."""
    def _replacer(match):
        return WORD_DIGIT_MAP.get(match.group(0).lower(), match.group(0))
    return _WORD_DIGIT_RE.sub(_replacer, text)


def _collapse_separators(text: str) -> str:
    """Remove spaces, dots, dashes, underscores — reveals hidden digit sequences."""
    return re.sub(r"[\s\.\-_/\\|~,;:]+", "", text)


def _count_consecutive_digits(text: str) -> int:
    """Find the longest run of consecutive digits in text."""
    matches = re.findall(r"\d+", text)
    return max((len(m) for m in matches), default=0)


def sanitize_and_guard(content: str, is_bridge_unlocked: bool = False) -> Tuple[bool, str]:
    """
    Multi-pass heuristic content guard.

    Returns:
        (is_blocked, reason) — if is_blocked is True, the message must be rejected.

    When `is_bridge_unlocked` is True, all checks are bypassed and the message
    is allowed through unconditionally.
    """
    if not content or not content.strip():
        return False, ""

    # Safe Bridge unlocked → allow everything
    if is_bridge_unlocked:
        return False, ""

    # --- Pass 1: Normalize ---
    normalized = _normalize_unicode(content)
    normalized_lower = normalized.lower()

    # --- Pass 2: Word-digit substitution ---
    with_word_digits = _replace_word_digits(normalized_lower)

    # --- Pass 3: Collapse separators ---
    collapsed = _collapse_separators(with_word_digits)

    # Also create a leetspeak-decoded collapsed version
    leet_decoded = _apply_leetspeak(collapsed)

    # --- Check all versions against patterns ---

    # Check normalized text against main patterns
    for pattern in LEAK_PATTERNS:
        if pattern.search(normalized_lower) or pattern.search(with_word_digits):
            return True, _block_reason()

    # Check collapsed versions against collapsed patterns
    for pattern in LEAK_PATTERNS_COLLAPSED:
        if pattern.search(collapsed) or pattern.search(leet_decoded):
            return True, _block_reason()

    # Check handle patterns on normalized text
    for pattern in HANDLE_PATTERNS:
        if pattern.search(normalized_lower):
            return True, _block_reason()

    # Check if word-digit replacement produced a long digit sequence
    if _count_consecutive_digits(collapsed) >= 7:
        return True, _block_reason()

    return False, ""


def _block_reason() -> str:
    return (
        "⚠️ Contact details, social IDs, ya phone numbers share karna mana hai. "
        "15 messages complete karke Safe Bridge unlock karein!"
    )
