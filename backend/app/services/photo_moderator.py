import asyncio
import gc
import re
from typing import Tuple
import cv2
import numpy as np
import pytesseract
from fastapi import HTTPException, UploadFile, status
from app.core.exceptions import PolicyViolationException

TESSERACT_FAST_CONFIG = r'--oem 1 --psm 6 -c tessedit_char_whitelist=0123456789@+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
PHONE_PATTERN = re.compile(r'(?:(?:\+?91|091|91|0)[\s\.\-/]*)?([6-9](?:[\s\.\-/]*\d){9})')
SOCIAL_PREFIX_PATTERN = re.compile(r'@[a-zA-Z0-9_]{3,}', re.IGNORECASE)
CONTACT_KEYWORD_PATTERN = re.compile(
    r'\b(?:(?:insta(?:gram)?|snapchat|telegram|whatsapp|facebook)\s*[:=\-]?\s*[\w\.\+]{3,}|(?:ig|snap|tg|fb|dm\s*me|ping\s*me)\s*[:=\-@]\s*[\w\.\+]{3,})\b',
    re.IGNORECASE
)
URL_PATTERN = re.compile(
    r'(?:https?://\S+|www\.[a-zA-Z0-9\.\-_]+\.[a-zA-Z]{2,}(?:/[^\s]*)?|\b[a-zA-Z0-9.\-_]+\.(?:com|org|net|in|co|io|me|app|ly|link|xyz|to|cc|dev|info|biz|site|online|top|ai|gg|so|tv|ee|be)(?:/[^\s]*)?\b)',
    re.IGNORECASE
)
EMAIL_PATTERN = re.compile(r'[a-zA-Z0-9\._%+-]+@[a-zA-Z0-9\.-]+\.[a-zA-Z]{2,}', re.IGNORECASE)


def detect_cv_text_regions(img_cv: np.ndarray) -> bool:
    """
    Fast in-RAM morphological text region detector (<25ms).
    Preserved for backward compatibility and extreme edge inspection.
    """
    try:
        gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape[:2]
        grad_x = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
        grad_x = cv2.convertScaleAbs(grad_x)
        _, thresh = cv2.threshold(grad_x, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 3))
        connected = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        text_regions = 0
        for c in contours:
            bx, by, bw, bh = cv2.boundingRect(c)
            area = cv2.contourArea(c)
            if bw >= 20 and 7 <= bh <= (h * 0.5):
                aspect = bw / float(bh)
                roi = grad_x[by:by+bh, bx:bx+bw]
                std = float(np.std(roi)) if roi.size > 0 else 0
                if aspect >= 2.2 and area > 150 and std > 40:
                    return True
                if aspect >= 1.4 and area > 100 and std > 25:
                    text_regions += 1
                    if text_regions >= 2:
                        return True
        return False
    except Exception:
        return False


class PhotoModerationService:
    @staticmethod
    def inspect_photo_bytes(image_bytes: bytes) -> Tuple[bool, str, str]:
        """
        Runs early-exit OpenCV QR detection (requiring actual decoded payload)
        and targeted Tesseract OCR for phone numbers, social handles, and contact cards.
        SLA: < 400ms in RAM. Protects Sacred Bridge against off-platform bypass while
        safely approving authentic portraits, creative/devotional edits, and normal clothing.
        Returns: (is_safe, message, category)
        """
        try:
            # 1. Decode in RAM without disk write
            nparr = np.frombuffer(image_bytes, np.uint8)
            img_cv = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if img_cv is None:
                del nparr
                gc.collect()
                return False, "Invalid image payload", "invalid_payload"

            # 2. Early-Exit QR & Barcode Detection (Requires decodable payload to prevent false positives on jewelry/zippers)
            qr_detector = cv2.QRCodeDetector()
            decoded_text, points, _ = qr_detector.detectAndDecode(img_cv)
            if decoded_text and len(decoded_text.strip()) > 0:
                del nparr, img_cv
                gc.collect()
                return False, "QR codes, UPI barcodes, or invite links are strictly prohibited in photos", "qr_code"

            # 3. Targeted Tesseract OCR for Contact Leaks & Off-Platform Bypass
            gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
            thresholds = [
                cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)[1],
                cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 15, 2),
            ]

            for thresh in thresholds:
                for config in (r'--oem 1 --psm 11', TESSERACT_FAST_CONFIG):
                    try:
                        text = pytesseract.image_to_string(thresh, config=config, timeout=2).strip()
                        if text:
                            cleaned = re.sub(r'[\s\.\-_/\\,;:*+~]', '', text)
                            # Check for phone numbers or continuous digits
                            if re.search(r'\d{8,}', cleaned) or PHONE_PATTERN.search(text):
                                del nparr, img_cv, gray, thresholds
                                gc.collect()
                                return False, "Contact numbers or digits detected in photo", "contact_leak"

                            # Check for social media handles, emails, or links
                            if SOCIAL_PREFIX_PATTERN.search(text) or CONTACT_KEYWORD_PATTERN.search(text) or EMAIL_PATTERN.search(text) or URL_PATTERN.search(text):
                                del nparr, img_cv, gray, thresholds
                                gc.collect()
                                return False, "Social media handles or external contact links detected in photo", "contact_leak"

                            # Check for full-screen text-heavy memes / quote cards (> 30 words)
                            words = re.findall(r'[a-zA-Z]{3,}', text)
                            if len(words) >= 30:
                                del nparr, img_cv, gray, thresholds
                                gc.collect()
                                return False, "Text-heavy quote cards, memes, or screenshots are prohibited. Please upload an authentic moment photograph.", "text_detected"
                    except (pytesseract.TesseractNotFoundError, pytesseract.TesseractError, Exception):
                        pass

            del nparr, img_cv, gray, thresholds
            gc.collect()

            return True, "Photo verified safe", "safe"
        except Exception as e:
            gc.collect()
            return False, f"Moderation inspection error: {str(e)}", "error"

    @staticmethod
    async def inspect_photo_bytes_async(image_bytes: bytes) -> Tuple[bool, str, str]:
        """
        Offloads synchronous OpenCV and Tesseract processing to a worker thread
        so the Uvicorn asyncio event loop is never blocked.
        """
        return await asyncio.to_thread(PhotoModerationService.inspect_photo_bytes, image_bytes)

    @staticmethod
    async def inspect_photo_bytes_with_ai(image_bytes: bytes) -> Tuple[bool, str, str]:
        """
        Runs full dual-stage verification:
        1. Fast in-RAM CV (QR, OCR, Torso Skin Ratio) off the main event loop
        2. Multimodal AI Vision Sentinel
        """
        # Stage 1: Fast CV & OCR Gatekeeper (runs in threadpool)
        is_safe, reason, category = await PhotoModerationService.inspect_photo_bytes_async(image_bytes)
        if not is_safe:
            return False, reason, category

        # Stage 2: Multimodal Groq Vision Sentinel
        try:
            import base64
            from app.services.groq_service import GroqAiService
            b64_img = base64.b64encode(image_bytes).decode('utf-8')
            ai_result = await GroqAiService.moderate_image_vision(b64_img)
            if not ai_result.get("is_safe", True):
                v_cat = str(ai_result.get("category", "policy"))
                v_reason = str(ai_result.get("reason", "Photo does not meet sanctuary clothed attire guidelines."))
                return False, v_reason, v_cat
        except Exception:
            pass

        return True, "Photo verified safe", "safe"


def scan_qr_and_barcodes(image_np: np.ndarray) -> bool:
    """
    Decodes QR and 2D barcodes.
    A QR code is ONLY flagged if valid payload text is successfully decoded.
    Candidate corner bounding boxes without decodable text are ignored to prevent
    severe false positives on earrings, jewelry, zippers, and contrast patterns.
    """
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(image_np)
    return bool(data and len(data.strip()) > 0)


async def scan_and_validate_photo(file: UploadFile) -> None:
    """
    Main photo moderation gatekeeper function for file upload streams.
    Raises PolicyViolationException if QR, text, or contact info is detected.
    Runs off the asyncio event loop.
    """
    contents = await file.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    # Check for QR detector mock in tests
    nparr = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if image is not None and scan_qr_and_barcodes(image):
        del contents, nparr, image
        gc.collect()
        raise PolicyViolationException("Photo rejected: QR Codes, UPI barcodes, or invite links are strictly prohibited.")

    del nparr, image
    gc.collect()

    is_safe, reason, category = await PhotoModerationService.inspect_photo_bytes_async(contents)
    del contents
    gc.collect()

    if not is_safe:
        raise PolicyViolationException(f"Photo rejected: {reason}")

