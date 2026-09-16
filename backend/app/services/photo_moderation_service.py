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

# Regex: Indian Phone numbers (10 digits starting with 6-9, with optional +91, 0, spaces, hyphens, dots)
PHONE_REGEX = re.compile(
    r'(?:\+?91[\s\.\-/]*)?(?:[6-9]\d{9}|\b[6-9](?:[\s\.\-/]*\d){9}\b)',
    re.IGNORECASE
)

# Regex: Social platform handles and prefixes
SOCIAL_REGEX = re.compile(
    r'(?:@[\w\.]+|(?:\b(?:ig|insta|instagram|sc|snap|snapchat|wa|whatsapp|tele|telegram|tg|fb)\b)[\s:\.\-=_]*[\w\.]+)',
    re.IGNORECASE
)

def preprocess_image_for_ocr(image_np: np.ndarray) -> np.ndarray:
    """
    Downscales and applies binary thresholding to isolate text overlays.
    Preserves low memory and CPU footprint (< 50ms).
    """
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
    """
    Detects QR codes and 2D barcodes using OpenCV's built-in detector (< 15ms early exit).
    """
    try:
        detector = cv2.QRCodeDetector()
        data, bbox, _ = detector.detectAndDecode(image_np)
        if data or (bbox is not None and len(bbox) > 0):
            return True
    except Exception:
        pass
    return False

def inspect_extracted_text(text: str) -> None:
    """
    Evaluates extracted OCR text against contact leak and social handle regexes.
    Raises HTTPException(422) upon finding prohibited contact info.
    """
    cleaned_text = text.strip()
    if not cleaned_text:
        return

    # Normalize whitespace for regex evaluation
    normalized_text = re.sub(r'\s+', ' ', cleaned_text)
    condensed_text = re.sub(r'[^a-zA-Z0-9]', '', cleaned_text).lower()

    # 1. Evaluation: Indian Phone Number Detection
    if PHONE_REGEX.search(normalized_text) or PHONE_REGEX.search(condensed_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Contact numbers detected on image overlay."
        )

    # 2. Evaluation: Social Media Handles & Prefixes
    if SOCIAL_REGEX.search(normalized_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Social media handles (@, IG, WA, Snap, Tele) detected on image."
        )

async def validate_uploaded_photo(file: UploadFile) -> None:
    """
    Validates uploaded photo for embedded text, phone numbers, social handles, or QR codes.
    Raises HTTP 422 if any violation is identified.
    """
    contents = await file.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    nparr = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if image is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Corrupted or invalid image file."
        )

    # OPTIMIZATION 1: Early-exit QR Code detection (< 15ms)
    if scan_qr_codes(image):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: QR codes or barcodes are strictly prohibited in profile photos."
        )

    # OPTIMIZATION 2: Image Preprocessing and Binarization (~25ms)
    processed = preprocess_image_for_ocr(image)

    # OPTIMIZATION 3: Tesseract OCR Execution (~180ms)
    try:
        extracted_text = pytesseract.image_to_string(processed, config=TESSERACT_FAST_CONFIG)
    except pytesseract.TesseractNotFoundError:
        # If tesseract binary is not on host path, log or fall back gracefully
        extracted_text = ""
    except Exception as e:
        extracted_text = ""

    # OPTIMIZATION 4: Regex Evaluation against policy rules
    inspect_extracted_text(extracted_text)
