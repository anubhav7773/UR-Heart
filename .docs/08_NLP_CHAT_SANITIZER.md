# 08_NLP_CHAT_SANITIZER.md: OFF-PLATFORM NLP SANITIZER & ZERO-BYPASS GATEKEEPER
# Project: UR-Heart (Mindful Dating Sanctuary)
# SLA Target: Execution Latency < 10ms per Message
# Memory Target: < 2MB Transient RAM under Render 512MB Budget
# Policy: Strict Zero Off-Platform Leakage (Text & Handle Lockdown)

---

## 1. THREAT MODEL & ARCHITECTURAL PHILOSOPHY

Dating platforms par users match hote hi conversations ko Instagram, Snapchat, ya WhatsApp par shift karne ki koshish karte hain. Isse:
1. Platform ki safety aur intermediary accountability (IT Rules 2021) compromise hoti hai.
2. In-app gamification aur ad economy (Quick Reflection, Deep Resonance, WhatsApp Reveal) bypass ho jati hai.
3. Bad actors harassment aur unverified communication channel create karte hain[cite: 1].

### 1.1 The Immutable Boundary Rule
* **No Plaintext Contact Sharing in Chat Ever**: Chahe users kitne bhi purane match hon, 1:1 chat messages mein phone numbers, social handles (@ig, snap, tele), URLs, emails, ya UPI IDs share karna **100% blocked** hai.
* **The ONLY Official Off-Platform Bridge (Dual 3-Ad Ritual)**: WhatsApp number sirf aur sirf Screen 10 ke **Enclave Reveal Ritual** ke through exchange ho sakta hai[cite: 1, 11, 24]. Jab dono users independently 3-3 rewarded video ads complete kar lete hain, tab system database level par ephemeral token generate karta hai aur unke profile card par verified WhatsApp button unmask karta hai[cite: 1, 11, 24]. Chat bubbles ke andar raw text mein number share karna kisi bhi condition mein permit nahi hoga[cite: 1].

---

## 2. EVASION ATTACK VECTORS & COUNTERMEASURES

Spammers aur users standard regex word filters ko bypass karne ke liye multiple evasion techniques use karte hain[cite: 1]:

| Evasion Attack Vector | Example Malicious Payload | Countermeasure Applied |
| :--- | :--- | :--- |
| **Zero-Width Invisibility** | `w​h​a​t​s​a​p​p` (`\u200b`, `\u200c`, `\ufeff`)[cite: 1] | Strip all Unicode Category `Mn` and zero-width codes before scanning[cite: 1]. |
| **Punctuation Spacing** | `9 . 8 - 7 _ 6 / 5 4 3 2 1 0` | Condense string to pure digits (`digits_only`) and evaluate 10-digit window[cite: 1]. |
| **Hindi Transliteration** | `nau aath saat chhe paanch char teen do ek shunya`[cite: 1] | Phonetic number word mapping dictionary converted to raw digits[cite: 1]. |
| **English Word Transliteration**| `nine eight seven six five four...`[cite: 1] | Lexical conversion from spelled numbers to integer digits[cite: 1]. |
| **Leetspeak & Homoglyphs** | `wh@ts@pp`, `!nst@gr@m`, `ph0ne`, `w-a-t-s-a-p` | NFKD character decomposition + custom character normalization table[cite: 1]. |
| **Subdomain / Deep Links** | `wa.me/9198...`, `t.me/username`, `ig.me` | Universal URL, URI scheme, and Top-Level Domain (TLD) pattern blocker. |
| **Payment Handles (UPI)** | `username@okhdfcbank`, `user@paytm` | Banking VPA & UPI domain signature interceptor. |

---

## 3. COMPREHENSIVE PLATFORM BLOCKLIST SPECIFICATION

NLP filter kisi bhi external social ya messaging app ke presence ko evaluate karta hai:

### 3.1 Prohibited Messaging Networks
* **WhatsApp**: `whatsapp`, `watsapp`, `watsap`, `vatsap`, `whatapp`, `wa`, `w-a`, `w/a`, `wa.me`[cite: 1].
* **Instagram**: `instagram`, `insta`, `instagr`, `ig`, `i_g`, `i-g`, `@`, `ig.me`[cite: 1].
* **Telegram**: `telegram`, `tele`, `tg`, `t.me`[cite: 1].
* **Snapchat**: `snapchat`, `snap`, `sc`, `sc-add`[cite: 1].
* **Others**: `discord`, `facebook`, `fb`, `twitter`, `tiktok`, `threads`, `reddit`, `linkedin`, `signal`, `wechat`, `viber`, `kik`, `session`, `skype`.

### 3.2 Prohibited Payment & Financial Handles
* `paytm`, `gpay`, `googlepay`, `phonepe`, `bhim`, `upi`, `@okaxis`, `@okhdfcbank`, `@okicici`, `@oksbi`, `@ybl`, `@ibl`.

---

## 4. PRODUCTION NLP SANITIZER ENGINE (`app/services/chat_sanitizer.py`)

Ye module CPU memory leak se bachne ke liye pure Python built-in `unicodedata` aur pre-compiled `re` module par run karta hai (zero heavy external NLP library dependency, sub-10ms response time)[cite: 1]:

```python
import re
import unicodedata
from typing import Tuple

# ============================================================================
# PRE-COMPILED REGEX PATTERNS (Loaded once in memory on worker startup)[cite: 1]
# ============================================================================

# 1. Indian 10-Digit Mobile Numbers (Starts with 6, 7, 8, or 9 with optional country codes)[cite: 1]
INDIAN_PHONE_REGEX = re.compile(
    r'(?:(?:\+?91|091|91|0)[\s\.\-/]*)?([6-9](?:[\s\.\-/]*\d){9})'
)
RAW_10_DIGIT_INDIAN_REGEX = re.compile(r'[6-9]\d{9}')[cite: 1]

# 2. English and Hindi Transliterated Number Word Map[cite: 1]
NUMBER_WORDS_MAP = {
    # English
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    # Hindi Transliteration[cite: 1]
    'shunya': '0', 'sunya': '0',
    'ek': '1', 'ik': '1',
    'do': '2', 'doo': '2',
    'teen': '3', 'tin': '3',
    'chaar': '4', 'char': '4',
    'paanch': '5', 'panch': '5', 'pach': '5',
    'chhe': '6', 'chheh': '6', 'che': '6',
    'saat': '7', 'sat': '7',
    'aath': '8', 'aat': '8', 'ath': '8',
    'nau': '9', 'no': '9', 'now': '9'
}

NUMBER_WORDS_REGEX = re.compile(
    r'\b(' + '|'.join(NUMBER_WORDS_MAP.keys()) + r')\b',
    re.IGNORECASE
)[cite: 1]

# 3. Full Platform Names (Tested on condensed non-spaced string)[cite: 1]
FULL_SOCIAL_KEYWORDS_REGEX = re.compile(
    r'(?:whatsapp|watsapp|watsap|vatsap|whatapp|instagram|instagr|telegram|snapchat|'
    r'facebook|twitter|linkedin|discord|tiktok|threads|signal|paytm|gpay|phonepe|bhim)',
    re.IGNORECASE
)[cite: 1]

# 4. Short Handles and Prefixes (Tested on word-boundary normalized string)[cite: 1]
SHORT_SOCIAL_HANDLE_REGEX = re.compile(
    r'(?:@|ig|i_g|i-g|wa|w-a|w/a|tele|tg|sc|snap|fb)[\s:_\-]*[a-zA-Z0-9_.]{3,30}',
    re.IGNORECASE
)[cite: 1]

# 5. URLs, Web Domains and Email Identifiers
URL_AND_EMAIL_REGEX = re.compile(
    r'(?:https?://\S+|www\.\S+|\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b|'
    r'\b(?:wa\.me|t\.me|ig\.me|snapchat\.com|bit\.ly)/\S+)',
    re.IGNORECASE
)

# 6. UPI Virtual Payment Addresses (VPA)
UPI_VPA_REGEX = re.compile(
    r'\b[a-zA-Z0-9.\-_]{2,256}@(okhdfcbank|okaxis|okicici|oksbi|paytm|ybl|ibl|upi)\b',
    re.IGNORECASE
)


def _deobfuscate_unicode(text: str) -> Tuple[str, str, str]:
    """
    Strips zero-width characters, combining marks, homoglyphs, and accents.
    Returns:
      1. normalized_text: Cleaned text preserving word boundaries[cite: 1]
      2. condensed_text: Pure lowercase alphanumeric string[cite: 1]
      3. digits_only: Isolated digit sequence[cite: 1]
    """
    # NFKD decomposition separates base characters from accents/ligatures[cite: 1]
    decomposed = unicodedata.normalize('NFKD', text)

    clean_chars = []
    for char in decomposed:
        # Exclude combining characters (Category 'Mn') and invisible zero-width spaces[cite: 1]
        if unicodedata.category(char) != 'Mn' and char not in {
            '\u200b', '\u200c', '\u200d', '\ufeff', '\u200e', '\u200f', '\u00a0'
        }:
            clean_chars.append(char)

    normalized_text = "".join(clean_chars).lower()

    # Leetspeak basic substitution mapping
    leetspeak_map = str.maketrans({
        '@': 'a', '$': 's', '!': 'i', '0': 'o', '1': 'i', '3': 'e', '5': 's', '+': 't'
    })
    de_leeted = normalized_text.translate(leetspeak_map)

    # Pure alphanumeric string with all whitespace/punctuation stripped[cite: 1]
    condensed_text = re.sub(r'[^a-z0-9]', '', de_leeted)

    # Isolated digits string[cite: 1]
    digits_only = re.sub(r'[^0-9]', '', normalized_text)

    return normalized_text, condensed_text, digits_only


def _convert_number_words_to_digits(text: str) -> str:
    """
    Converts English and Hindi transliterated written numbers into digits.
    Example: 'mera number hai nau aath saat chaar...' -> '9874...'[cite: 1]
    """
    def replace_word(match: re.Match) -> str:
        word = match.group(0).lower()
        return NUMBER_WORDS_MAP.get(word, word)

    converted_text = NUMBER_WORDS_REGEX.sub(replace_word, text)
    return re.sub(r'[^0-9]', '', converted_text)[cite: 1]


def inspect_chat_message(text: str) -> Tuple[bool, str]:
    """
    Exhaustive NLP Gatekeeper for UR-Heart Chat Messages.
    Returns:
      (True, "clean") -> Safe message allowed to persist and broadcast.
      (False, violation_reason) -> Aborts message, triggers UI warning.
    """
    if not text or not text.strip():
        return True, "clean"

    # Step 1: Unicode Normalization and Character Cleaning[cite: 1]
    normalized_text, condensed_text, digits_only = _deobfuscate_unicode(text)

    # Step 2: Check Indian 10-Digit Mobile Numbers[cite: 1]
    if INDIAN_PHONE_REGEX.search(normalized_text) or RAW_10_DIGIT_INDIAN_REGEX.search(digits_only):
        return False, "PHONE_NUMBER_DETECTED"[cite: 1]

    # Step 3: Check Spelled/Transliterated Phone Numbers (Hindi & English)[cite: 1]
    converted_digits = _convert_number_words_to_digits(normalized_text)
    if RAW_10_DIGIT_INDIAN_REGEX.search(converted_digits):
        return False, "TRANSLITERATED_PHONE_NUMBER_DETECTED"[cite: 1]

    # Step 4: Check Full Social Platform Names[cite: 1]
    if FULL_SOCIAL_KEYWORDS_REGEX.search(condensed_text):
        return False, "SOCIAL_PLATFORM_KEYWORD_DETECTED"[cite: 1]

    # Step 5: Check Short Social Handles & Prefixes (@, IG, WA, SC, TG)[cite: 1]
    if SHORT_SOCIAL_HANDLE_REGEX.search(normalized_text):
        return False, "SOCIAL_HANDLE_PREFIX_DETECTED"[cite: 1]

    # Step 6: Check URLs, Deep Links, and Emails
    if URL_AND_EMAIL_REGEX.search(normalized_text):
        return False, "EXTERNAL_LINK_OR_EMAIL_DETECTED"

    # Step 7: Check UPI Virtual Payment Addresses
    if UPI_VPA_REGEX.search(normalized_text):
        return False, "UPI_PAYMENT_HANDLE_DETECTED"

    return True, "clean"
5. GATEKEEPER INTEGRATION (REST & WEBSOCKET PIPELINE)
FastAPI chat router message ko database mein write karne se pehle sanitize function invoke karta hai[cite: 1]:

Python


from fastapi import APIRouter, HTTPException, WebSocket, status
from app.services.chat_sanitizer import inspect_chat_message[cite: 1]

router = APIRouter()

# 1. REST Fallback Endpoint Gatekeeper[cite: 1]
@router.post("/api/v1/chat/send-message")
async def send_rest_message(payload: dict):
    raw_message = payload.get("text", "")
    is_safe, violation_code = inspect_chat_message(raw_message)

    if not is_safe:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error_code": "OFF_PLATFORM_LEAK_FORBIDDEN",
                "violation": violation_code,
                "message": (
                    "Sharing phone numbers, social media handles (@, IG, WA, Snap), or links "
                    "is strictly prohibited. Complete the 3-ad Enclave Reveal Ritual to connect off-platform."[cite: 1, 11]
                )
            }
        )
    # Proceed to DB Save...[cite: 1]
    return {"status": "accepted"}

# 2. WebSocket Real-Time Gatekeeper[cite: 1]
async def gatekeep_ws_incoming_payload(websocket: WebSocket, raw_text: str) -> bool:
    """Verifies incoming message before broadcasting or writing to Supabase Postgres."""[cite: 1]
    is_safe, violation_code = inspect_chat_message(raw_text)
    
    if not is_safe:
        # Transmit explicit warning modal event directly to Flutter Client[cite: 1]
        await websocket.send_json({
            "event": "policy_violation_alert",
            "violation": violation_code,
            "message": (
                "Message blocked: Sharing external contact info violates UR-Heart sanctuary policies. "
                "Unlock WhatsApp legitimately via the Growth Hub Enclave Ritual."[cite: 1, 11]
            )
        })
        return False  # Abort DB save & broadcast[cite: 1]
        
    return True
6. DUAL-SIDED 3-AD REVEAL WORKFLOW VS CHAT POLICY
Users ko off-platform jump karne ke liye application ke design flow aur security model mein clear differentiation hai[cite: 1, 11, 24]:

                     ┌───────────────────────────────────────────────┐
                     │ User wants to exchange contact info / WhatsApp │
                     └───────────────────────┬───────────────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       ▼                                           ▼
          [Attempt to type in Chat]                 [Use Enclave Reveal Ritual]
                       │                                           │
                       ▼                                           ▼
        Blocked by NLP Chat Sanitizer               Both users watch 3 rewarded ads each[cite: 1, 11, 24]
        (Instant 422 Alert / Dropped)[cite: 1]                     │
                                                                   ▼
                                                    Backend generates ephemeral token (24h)[cite: 1]
                                                                   │
                                                                   ▼
                                                    Official WhatsApp button unlocks in UI[cite: 1, 11, 24]
                                                    (Secure direct launch, zero chat pollution)
Chat Screen Remains Pure: Chat screen hamesha end-to-end encrypted aur contact-sanitized rahegi[cite: 1, 10, 23].

Growth Hub Controls The Key: WhatsApp number tabhi visible hoga jab public.whatsapp_reveal_tokens mein user1_ads_count == 3 AND user2_ads_count == 3[cite: 1].

Direct WhatsApp Launch: Unlock hone ke baad Flutter application WhatsApp URL scheme (https://wa.me/<encrypted_number>) directly trigger karti hai[cite: 11, 24]. Chat room mein number copy-paste karne ki requirement hi eliminate ho jati hai.

7. ANTIGRAVITY VERIFICATION & TEST SUITE
Antigravity agent ko implementation ke baad ye exact test assertions verify karne honge:

Python


# ============================================================================
# TEST ASSERTION SUITE FOR ANTIGRAVITY VERIFICATION
# ============================================================================

def test_nlp_sanitizer():
    # 1. Plain Indian Mobile Number
    assert inspect_chat_message("Call me at 9876543210")[0] is False[cite: 1]
    assert inspect_chat_message("+91 98765 43210")[0] is False[cite: 1]

    # 2. Obfuscated Spaced Number
    assert inspect_chat_message("mera no 9 . 8 - 7 _ 6 / 5 4 3 2 1 0")[0] is False[cite: 1]

    # 3. Hindi Transliterated Number
    assert inspect_chat_message("call nau aath saat chhe paanch chaar teen do ek shunya")[0] is False[cite: 1]

    # 4. Social Handles & Full Platform Names
    assert inspect_chat_message("connect on whatsapp please")[0] is False[cite: 1]
    assert inspect_chat_message("my ig is @alexandra_v")[0] is False[cite: 1]
    assert inspect_chat_message("add on snap sc: alexa")[0] is False[cite: 1]

    # 5. External URLs & UPI VPAs
    assert inspect_chat_message("check out [https://myprofile.com](https://myprofile.com)")[0] is False
    assert inspect_chat_message("pay me on user@okhdfcbank")[0] is False

    # 6. Benign / Safe Sanctuary Messages (MUST PASS - NO FALSE POSITIVES)[cite: 1]
    assert inspect_chat_message("I loved that Haruki Murakami passage on quiet spaces")[0] is True[cite: 10, 23]
    assert inspect_chat_message("Are you still exploring the botanical gardens?")[0] is True[cite: 9, 22]
    assert inspect_chat_message("Guilty as charged. Rain on the glass and black coffee.")[0] is True[cite: 10, 23]
    assert inspect_chat_message("This digital art exhibition is really big and bright")[0] is True[cite: 1]

    print("All NLP Sanitizer assertions passed with 100% accuracy!")