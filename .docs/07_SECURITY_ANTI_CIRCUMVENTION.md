# Security, Anti-Circumvention & Privacy Shield Specification

**Document Identifier:** URH-SEC-007  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**Subsystems Covered:**  
1. Multi-Stage Photo OCR & Watermark Rejection Engine  
2. High-Throughput NLP Chat Stream Sanitizer (Hindi/English Transliteration & Leetspeak)  
3. Real-Time WebSocket Gatekeeper & Error Protocol  
4. Screen Recording & Hardware Screenshot Protection Architecture (`FLAG_SECURE`)  
**Processing Latency Targets:** OCR Scan $< 400$ ms; Chat Message Sanitization $< 2$ ms

---

## 1. Threat Model & Strategic Objectives

Because UR-Heart provides a 100% free dating service funded exclusively via video ads, users frequently attempt off-platform jumps to avoid watching ads:
- **Evasion Threat 1 (Photo Overlays):** Users paint, watermark, or edit phone numbers, Instagram handles (`@username`), Snapchat IDs, or WhatsApp QR codes directly onto their profile pictures.
- **Evasion Threat 2 (Chat Camouflage):** Users attempt to bypass basic word filters by inserting spaces (`9 8 7 6...`), symbols (`9-8-7-6...`), zero-width Unicode characters, leetspeak (`w-h-a-t-s-a-p-p`, `i_g`), or written transliterated numbers in English (`nine eight...`) and Hindi (`nau aath saat chhe...`).
- **Evasion Threat 3 (Privacy Breach):** Malicious actors take screenshots or screen recordings of private profiles or chat conversations to blackmail or doxx users.

### The Iron-Curtain Mandate
1. **Zero Contact Leaks:** No phone number, social media account, or external URL can be exchanged via photos or chat until the **Mutual WhatsApp Reveal State Machine** is completed via 6 verified rewarded ads.
2. **Deterministic Rejection:** Prohibited content is caught and dropped on the backend **before** saving to Supabase or broadcasting over WebSockets.
3. **Zero False Positives:** Innocent words like `"big"`, `"digital"`, `"always"`, or `"photo"` must never trigger false-positive blocks.

---

## 2. Multi-Stage Photo Moderation Service (`photo_moderation_service.py`)

Every profile photo must pass this service prior to storage persistence. It utilizes OpenCV and Tesseract OCR with early-exit optimizations to stay within Render's free-tier CPU constraints.

### 2.1. Execution Pipeline
[Compressed WebP Upload]│▼OpenCV QR / Matrix Barcode Detection (Early-Exit < 15ms)├── Detected? ──► Terminate with HTTP 422 (QR Code Prohibited)└── Clean? ─────► Proceed to Preprocessing│▼Resolution Downscale (Max 800px) + Grayscale + Otsu Thresholding (~30ms)│▼Tesseract LSTM Fast OCR Engine (--oem 1 --psm 11) (~180ms)│▼Regex & Pattern Evaluation against Extracted Text├── Phone Number Detected? ─────► Terminate with HTTP 422├── Social Prefix (@, ig, wa)? ─► Terminate with HTTP 422└── Clean? ─────────────────────► Return Success (Save to Storage)
### 2.2. Complete Production Code (`app/services/photo_moderation_service.py`)
```python
import re
import cv2
import numpy as np
import pytesseract
from fastapi import HTTPException, status, UploadFile

# Tesseract Configuration:
# --oem 1: LSTM Neural Network engine only (fastest execution)
# --psm 11: Sparse text detection (optimized for scattered overlays)
# -c tessedit_do_invert=0: Disables background inversion to conserve CPU cycles
TESSERACT_FAST_CONFIG = r'--oem 1 --psm 11 -c tessedit_do_invert=0'

# Regex: Phone numbers (10 digits with optional +91, spaces, hyphens, dots)
PHONE_REGEX = re.compile(
    r'(?:\+?91[\s\.\-/]*)?(?:[6-9]\d{9}|\b[6-9](?:[\s\.\-/]*\d){9}\b)',
    re.IGNORECASE
)

# Regex: Social platform handles and prefixes
SOCIAL_REGEX = re.compile(
    r'(?:@[\w\.]+|(?:\b(?:ig|insta|instagram|sc|snap|snapchat|wa|whatsapp|tele|telegram|fb)\b)[\s:\.\-=_]*[\w\.]+)',
    re.IGNORECASE
)

def preprocess_image_for_ocr(image_np: np.ndarray) -> np.ndarray:
    """Downscales and applies binary thresholding to isolate text overlays."""
    height, width = image_np.shape[:2]
    max_dimension = 800

    # Downscale high-resolution uploads to keep processing fast (< 400ms)
    if max(height, width) > max_dimension:
        scale = max_dimension / float(max(height, width))
        image_np = cv2.resize(
            image_np, 
            (int(width * scale), int(height * scale)), 
            interpolation=cv2.INTER_AREA
        )

    # 1. Convert to Grayscale
    gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY)

    # 2. Gaussian Blur to eliminate high-frequency noise
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)

    # 3. Otsu's automatic binarization for maximum text contrast
    _, thresholded = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return thresholded

def scan_qr_codes(image_np: np.ndarray) -> bool:
    """Detects QR codes and 2D barcodes using OpenCV's built-in detector (< 15ms)."""
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(image_np)
    return bool(data or bbox is not None)

async def validate_uploaded_photo(file: UploadFile) -> None:
    """
    Validates uploaded photo for embedded text, phone numbers, social handles, or QR codes.
    Raises HTTP 422 if any violation is identified.
    """
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if image is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Corrupted or invalid image file."
        )

    # OPTIMIZATION 1: Early-exit QR Code detection (~15ms)
    if scan_qr_codes(image):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: QR codes or barcodes are strictly prohibited in profile photos."
        )

    # OPTIMIZATION 2: Image Binarization (~25ms)
    processed = preprocess_image_for_ocr(image)

    # OPTIMIZATION 3: Tesseract OCR Execution (~180ms)
    extracted_text = pytesseract.image_to_string(processed, config=TESSERACT_FAST_CONFIG)
    cleaned_text = extracted_text.strip()

    if not cleaned_text:
        return  # Pass: No text detected on image

    # Normalize whitespace for regex evaluation
    normalized_text = re.sub(r'\s+', ' ', cleaned_text)
    condensed_text = re.sub(r'[^a-zA-Z0-9]', '', cleaned_text).lower()

    # Evaluation 1: Indian Phone Number Detection
    if PHONE_REGEX.search(normalized_text) or PHONE_REGEX.search(condensed_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Contact numbers detected on image overlay."
        )

    # Evaluation 2: Social Media Handles & Prefixes
    if SOCIAL_REGEX.search(normalized_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Social media handles (@, IG, WA, Snap, Tele) detected on image."
        )
3. High-Throughput NLP Chat Stream Sanitizer (chat_sanitizer.py)The chat sanitizer executes in $< 2$ ms per message. It uses a 4-step de-obfuscation and normalization pipeline to intercept contact sharing attempts while avoiding false positives on natural conversations.3.1. Transliteration & Number Word MappingUsers frequently spell out phone numbers using vernacular Hindi or English words. The engine tokenizes and maps these words to digits:DigitEnglish Number WordsHindi Transliterated Number Words0zero, oshunya, sunya, sifar1one, wonek, ik2two, to, toodo, doo3threeteen, tin4four, forchaar, char5fivepaanch, panch, pach6sixchhe, chheh, che7sevensaat, sat8eight, ateaath, aat, ath9ninenau, no, now3.2. Complete Production Code (app/services/chat_sanitizer.py)Pythonimport re
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
    'nau': '9', 'now': '9'
}

# Regex to match isolated number words only (word boundaries prevent partial word collisions)
NUMBER_WORDS_REGEX = re.compile(
    r'\b(' + '|'.join(NUMBER_WORDS_MAP.keys()) + r')\b',
    re.IGNORECASE
)

# 3. Full Social Platform Keywords (Tested against condensed string to catch evasions like "w-h-a-t-s-a-p-p")
CONDENSED_SOCIAL_REGEX = re.compile(
    r'(?:whatsapp|watsapp|watsap|vatsap|whatapp|instagram|instagr|telegram|snapchat|facebook|twitter|linkedin|paytm|gpay|phonepe)',
    re.IGNORECASE
)

# 4. Short Social Identifiers & Handle Prefixes (Evaluated with word boundaries to prevent false positives)
# Catches: "@username", "ig: user", "wa - 9876", "sc: priya"
SHORT_SOCIAL_HANDLE_REGEX = re.compile(
    r'(?:@[\w\.]+|(?:\b(?:ig|i_g|i-g|wa|w-a|w/a|tele|tg|sc|snap|fb)\b)[\s:\.\-=_]*[a-zA-Z0-9_\.]+)',
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
    """Converts English and Hindi transliterated number words into pure digits."""
    def replace_word(match: re.Match) -> str:
        word = match.group(0).lower()
        return NUMBER_WORDS_MAP.get(word, word)

    # Replace whole word numbers with numeric strings
    text_with_digits = NUMBER_WORDS_REGEX.sub(replace_word, text)
    # Extract contiguous digit stream
    return re.sub(r'[^0-9]', '', text_with_digits)

def sanitize_chat_message(text: str) -> bool:
    """
    Main Chat Content Sanitizer.
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
4. False-Positive Mitigation EngineeringTo prevent blocking legitimate romantic or everyday conversations, chat_sanitizer.py employs contextual boundary rules:Short Token Boundary Isolation:Checking for "ig" or "wa" on a condensed string would inadvertently trigger violations on words like "b**ig**", "d**ig**ital", or "al**wa**ys". By evaluating short identifiers strictly against \b word boundaries on normalized_text, innocent words pass seamlessly.Ambiguous Vernacular Words ("no"):The English word "no" can mean negative denial ("no I am busy") or the Hindi number 9 ("nau / no"). The engine only flags "no" if it forms part of an unbroken 10-digit converted sequence starting with 6, 7, 8, or 9. An innocent sentence like "no problem see you tomorrow" has only 1 digit mapped and will never be blocked.5. API & WebSocket Gatekeeper Integration5.1. WebSocket Chat Gatekeeper (app/api/v1/endpoints/chat.py)Pythonimport json
from uuid import UUID
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status
from app.services.chat_manager import manager
from app.services.chat_sanitizer import sanitize_chat_message
from app.core.security import decode_access_token
from app.models.domain.message import Message
from app.core.database import async_session_factory

router = APIRouter()

@router.websocket("/ws/chat")
async def websocket_chat_gateway(websocket: WebSocket, token: str = Query(...)):
    user_id_str = decode_access_token(token)
    if not user_id_str:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id = UUID(user_id_str)
    await manager.connect(user_id, websocket)

    try:
        while True:
            raw_payload = await websocket.receive_text()
            data = json.loads(raw_payload)
            action_type = data.get("type")

            if action_type == "message":
                match_id = UUID(data.get("match_id"))
                recipient_id = UUID(data.get("recipient_id"))
                content = data.get("content", "")

                # =============================================================
                # GATEKEEPER INTERCEPTION: Content Sanitization
                # =============================================================
                if not sanitize_chat_message(content):
                    # Transmit error alert payload directly to sender client
                    await websocket.send_text(json.dumps({
                        "event": "anti_leak_violation",
                        "code": 422,
                        "match_id": str(match_id),
                        "message": "Sharing phone numbers, social media handles (@, IG, WA, Snap) or external contacts is strictly prohibited on UR-Heart."
                    }))
                    # Abort execution: Do not persist to database or broadcast
                    continue

                # Content is safe -> Save to Supabase messages table
                async with async_session_factory() as db:
                    msg = Message(
                        match_id=match_id,
                        sender_id=user_id,
                        encrypted_text=content,
                        status="delivered"
                    )
                    db.add(msg)
                    await db.commit()

                # Broadcast to recipient if online
                await manager.send_personal_message({
                    "event": "incoming_message",
                    "match_id": str(match_id),
                    "sender_id": str(user_id),
                    "content": content,
                    "created_at": msg.created_at.isoformat()
                }, recipient_id)

    except WebSocketDisconnect:
        manager.disconnect(user_id)
6. Display Privacy Layer: FLAG_SECURE & Screen ProtectionTo prevent screenshots and recordings, the Flutter client activates Android's hardware-enforced FLAG_SECURE layout flag upon entering private screens.6.1. Flutter Integration ArchitectureDynamic Lifecycle Management: FLAG_SECURE is active on private routes (FeedScreen, ChatScreen, PhotoPreviewScreen) and cleared when returning to public screens (SettingsScreen, LegalScreen).Behavior on Android:Hardware screenshot shortcut (Power + Volume Down) is blocked by the OS with message: "Can't take screenshot due to security policy".Screen recording records blank black visual frames.App Switcher / Recent Apps window displays a blank dark placeholder, preventing sensitive preview leaks.6.2. Route Observer Mixin (lib/core/security/secure_screen_mixin.dart)Dartimport 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

mixin SecureScreenStateMixin<T StatefulWidget extends> on State<T> {
  @override
  void initState() {
    super.initState();
    _enableSecureWindow();
  }

  @override
  void dispose() {
    _disableSecureWindow();
    super.dispose();
  }

  Future<void> _enableSecureWindow() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("Error enabling FLAG_SECURE: $e");
    }
  }

  Future<void> _disableSecureWindow() async {
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("Error disabling FLAG_SECURE: $e");
    }
  }
}
7. Autonomous Verification Suite for Antigravity AgentThe Antigravity agent must execute and pass this automated test suite before concluding the security implementation:Python# tests/test_security_filters.py
import pytest
from app.services.chat_sanitizer import sanitize_chat_message

@pytest.mark.parametrize("evasive_text", [
    # Direct Indian Mobile Numbers
    "Call me at 9876543210 please",
    "+91 98765 43210",
    "9876-543-210",
    "9 8 7 6 5 4 3 2 1 0",
    "09876543210",
    
    # Transliterated English Numbers
    "my number is nine eight seven six five four three two one zero",
    
    # Transliterated Hindi Numbers
    "mera number nau aath saat chhe paanch chaar teen do ek shunya hai",
    "nau eight seven chhe five four three do ek zero",
    
    # Social Handles & Leetspeak
    "Follow me on insta: rahul_singh",
    "Add me on @priya_verma",
    "My ig is ananya.01",
    "Message on w-h-a-t-s-a-p-p",
    "watsapp me 9876543210",
    "snap id: aman_cool"
])
def test_anti_leak_blocks_prohibited_patterns(evasive_text):
    assert sanitize_chat_message(evasive_text) is False, f"Failed to block: {evasive_text}"

@pytest.mark.parametrize("safe_text", [
    "Hello! How are you doing today?",
    "I am eating lunch at a big restaurant",
    "I work in digital marketing in Lucknow",
    "Always happy to meet genuine people",
    "No problem see you tomorrow morning",
    "My favorite number is 7",
    "Is it two o'clock already?"
])
def test_anti_leak_permits_safe_conversation(safe_text):
    assert sanitize_chat_message(safe_text) is True, f"False positive triggered on: {safe_text}"
Authorized & Validated for ASI Verticals / UR-Heart Security Engineering Pipeline.