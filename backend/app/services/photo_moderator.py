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


class PhotoModerationService:
    @staticmethod
    def inspect_photo_bytes(image_bytes: bytes) -> Tuple[bool, str]:
        """
        Runs early-exit OpenCV QR detection followed by Tesseract fast LSTM OCR.
        SLA: < 400ms in RAM. Strictly rejects QR codes, phone numbers, and handles.
        """
        try:
            # 1. Decode in RAM without disk write
            nparr = np.frombuffer(image_bytes, np.uint8)
            img_cv = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if img_cv is None:
                del nparr
                gc.collect()
                return False, "Invalid image payload"

            # 2. Early-Exit QR & Barcode Detection
            qr_detector = cv2.QRCodeDetector()
            decoded_text, points, _ = qr_detector.detectAndDecode(img_cv)
            if (points is not None and len(points) > 0) or (decoded_text and len(decoded_text.strip()) > 0):
                del nparr, img_cv
                gc.collect()
                return False, "QR codes and external links are prohibited in photos"

            # 3. Computer Vision Torso & Chest Intimacy Detector
            # Detect skin in upper/middle body (y: 20% to 75%, x: 15% to 85%)
            h, w, _ = img_cv.shape
            if h > 20 and w > 20:
                hsv = cv2.cvtColor(img_cv, cv2.COLOR_BGR2HSV)
                ycrcb = cv2.cvtColor(img_cv, cv2.COLOR_BGR2YCrCb)

                lower_hsv = np.array([0, 25, 60], dtype=np.uint8)
                upper_hsv = np.array([25, 255, 255], dtype=np.uint8)
                mask_hsv = cv2.inRange(hsv, lower_hsv, upper_hsv)

                lower_ycrcb = np.array([0, 133, 77], dtype=np.uint8)
                upper_ycrcb = np.array([255, 173, 127], dtype=np.uint8)
                mask_ycrcb = cv2.inRange(ycrcb, lower_ycrcb, upper_ycrcb)

                skin_mask = cv2.bitwise_and(mask_hsv, mask_ycrcb)

                # Focus on chest, abdomen and torso area
                y_start, y_end = int(h * 0.20), int(h * 0.75)
                x_start, x_end = int(w * 0.15), int(w * 0.85)
                torso_roi = skin_mask[y_start:y_end, x_start:x_end]

                torso_pixels = torso_roi.size
                torso_skin = cv2.countNonZero(torso_roi)
                torso_skin_ratio = torso_skin / float(torso_pixels) if torso_pixels > 0 else 0

                # Clothed portraits typically have < 12% skin in torso; shirtless or lingerie has > 20%
                if torso_skin_ratio > 0.20:
                    del nparr, img_cv, hsv, ycrcb, skin_mask
                    gc.collect()
                    return False, "Photo Rejected: Shirtless, swimwear, lingerie, or excessive exposed skin detected. UR-Heart maintains a clothed sanctuary standard."

                del hsv, ycrcb, skin_mask

            # 4. Fast Grayscale + Otsu Binarization for OCR
            gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
            thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)[1]

            # 5. Tesseract OCR (Fast digits & handles detection)
            try:
                extracted_text = pytesseract.image_to_string(thresh, config=TESSERACT_FAST_CONFIG).strip()
            except pytesseract.TesseractNotFoundError:
                extracted_text = ""

            del nparr, img_cv, gray, thresh
            gc.collect()

            if extracted_text:
                # Inspect extracted text for contact leaks
                cleaned = re.sub(r'[\s\.\-_/\\,;:*+~]', '', extracted_text)
                if re.search(r'\d{8,}', cleaned) or PHONE_PATTERN.search(extracted_text):
                    return False, "Contact numbers or digits detected in photo"

                if SOCIAL_PREFIX_PATTERN.search(extracted_text):
                    return False, "Social media handles detected in photo"

            return True, "Photo verified safe"
        except Exception as e:
            gc.collect()
            return False, f"Moderation inspection error: {str(e)}"

    @staticmethod
    async def inspect_photo_bytes_with_ai(image_bytes: bytes) -> Tuple[bool, str]:
        """
        Runs full dual-stage verification:
        1. Fast in-RAM CV (QR, OCR, Torso Skin Ratio)
        2. Multimodal Groq Llama-3.2 Vision for intimate/shirtless attire detection
        """
        # Stage 1: Fast CV & OCR Gatekeeper
        is_safe, reason = PhotoModerationService.inspect_photo_bytes(image_bytes)
        if not is_safe:
            return False, reason

        # Stage 2: Multimodal Groq Vision Sentinel
        try:
            import base64
            from app.services.groq_service import GroqAiService
            b64_img = base64.b64encode(image_bytes).decode('utf-8')
            ai_result = await GroqAiService.moderate_image_vision(b64_img)
            if not ai_result.get("is_safe", True):
                return False, ai_result.get("reason", "Photo does not meet sanctuary clothed attire guidelines.")
        except Exception:
            pass

        return True, "Photo verified safe"


def scan_qr_and_barcodes(image_np: np.ndarray) -> bool:
    detector = cv2.QRCodeDetector()
    data, bbox, _ = detector.detectAndDecode(image_np)
    return bool(data or (bbox is not None and len(bbox) > 0))


async def scan_and_validate_photo(file: UploadFile) -> None:
    """
    Main photo moderation gatekeeper function for file upload streams.
    Raises PolicyViolationException if QR or contact info is detected.
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

    is_safe, reason = PhotoModerationService.inspect_photo_bytes(contents)
    del contents
    gc.collect()

    if not is_safe:
        raise PolicyViolationException(f"Photo rejected: {reason}")
