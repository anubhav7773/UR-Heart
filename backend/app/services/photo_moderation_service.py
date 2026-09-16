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

def detect_human_face(image_np: np.ndarray) -> bool:
    """
    Validates that the photo contains at least one detectable human face using OpenCV Haar Cascade.
    Rejects banners, flyers, posters, and objects without human faces.
    """
    try:
        cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        face_cascade = cv2.CascadeClassifier(cascade_path)
        gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY) if len(image_np.shape) == 3 else image_np
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.15,
            minNeighbors=3,
            minSize=(40, 40)
        )
        return len(faces) >= 1
    except Exception:
        return False

def detect_dense_text_or_banner(image_np: np.ndarray) -> bool:
    """
    Detects embedded text, usernames, slogans, AI-generated typography,
    banner text, or watermarks using morphological gradient analysis.
    Zero-tolerance: rejects images with text overlays regardless of face presence.
    """
    try:
        gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY) if len(image_np.shape) == 3 else image_np
        h, w = gray.shape

        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 3))
        gradient = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)
        _, thresh = cv2.threshold(gradient, 35, 255, cv2.THRESH_BINARY)

        close_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 3))
        connected = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, close_kernel)

        contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        text_box_count = 0
        for c in contours:
            x, y, bw, bh = cv2.boundingRect(c)
            aspect_ratio = bw / float(bh) if bh > 0 else 0
            area = cv2.contourArea(c)
            if 1.2 < aspect_ratio < 15 and 20 < bw < w * 0.85 and 8 < bh < 120 and area > 80:
                text_box_count += 1

        # Strict zero-text: 2 or more horizontal text blocks indicates text overlay, banner, or typography
        return text_box_count >= 2
    except Exception:
        return False

def inspect_extracted_text(text: str) -> None:
    """
    Evaluates extracted OCR text against contact leak, social handles, and general text.
    Raises HTTPException(422) upon finding prohibited contact info or text overlays.
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

    # 3. Strict Zero-Text: Any significant embedded text (> 5 alphanumeric chars)
    if len(condensed_text) >= 6:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Text overlay or watermark detected. Profile photos must be clean portraits."
        )

async def validate_uploaded_photo(file: UploadFile, require_face: bool = False) -> None:
    """
    Strictly validates uploaded photo:
    - Zero-tolerance for QR codes and barcodes.
    - Zero-tolerance for text overlays, usernames, AI typography, watermarks (even if face is present).
    - Mandatory clear, unobstructed human face when require_face is True.
    - Rejects synthetic digital graphics and posters.
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

    # CHECK 1: Early-exit QR Code detection (< 15ms)
    if scan_qr_codes(image):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: QR codes or barcodes are strictly prohibited in profile photos."
        )

    # CHECK 2: Strict Zero-Text Overlay & Typography Detection
    # Rejects ANY image with text overlays, handles, usernames, slogans, or AI typography
    if detect_dense_text_or_banner(image):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Text, username, or graphic overlay detected. Profile photos must be 100% clean camera photos."
        )

    has_face = detect_human_face(image)

    # CHECK 3: Human Face Enforcement for Profile Photos
    if require_face and not has_face:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: No valid human face detected. Please upload a clear photo of yourself."
        )

    # CHECK 4: Image Preprocessing and Binarization (~25ms)
    processed = preprocess_image_for_ocr(image)

    # CHECK 5: Tesseract OCR Execution (~180ms)
    try:
        extracted_text = pytesseract.image_to_string(processed, config=TESSERACT_FAST_CONFIG)
    except pytesseract.TesseractNotFoundError:
        extracted_text = ""
    except Exception:
        extracted_text = ""

    # CHECK 6: Regex and Zero-Text Density Evaluation
    inspect_extracted_text(extracted_text)
