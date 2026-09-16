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
    Detects banner text and poster layouts using OpenCV edge and morphological analysis.
    Identifies high-contrast horizontal text blocks characteristic of banners/posters.
    """
    try:
        gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY) if len(image_np.shape) == 3 else image_np
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 3))
        gradient = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)
        _, thresh = cv2.threshold(gradient, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        close_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 3))
        connected = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, close_kernel)

        contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        text_box_count = 0
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            aspect_ratio = w / float(h) if h > 0 else 0
            if 1.5 < aspect_ratio < 12 and w > 40 and 10 < h < 100:
                text_box_count += 1

        return text_box_count >= 3
    except Exception:
        return False

def inspect_extracted_text(text: str, has_face: bool = True) -> None:
    """
    Evaluates extracted OCR text against contact leak, social handles, and banner text.
    Raises HTTPException(422) upon finding prohibited contact info or banner overlays.
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

    # 3. Evaluation: Banner / Flyer text without a human face
    if not has_face and len(cleaned_text) > 15:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Text banners and posters are not permitted. Please upload a real photo."
        )

async def validate_uploaded_photo(file: UploadFile, require_face: bool = False) -> None:
    """
    Validates uploaded photo for embedded text, phone numbers, social handles, QR codes,
    and ensures human face presence when required.
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

    has_face = detect_human_face(image)

    # OPTIMIZATION 2: Human Face Enforcement for Profile Photos
    if require_face and not has_face:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: No valid human face detected. Please upload a clear photo of yourself."
        )

    # OPTIMIZATION 3: Banner/Poster Layout Detection (no face + dense text blocks)
    if not has_face and detect_dense_text_or_banner(image):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Text banners, posters, and flyers are not allowed as profile photos."
        )

    # OPTIMIZATION 4: Image Preprocessing and Binarization (~25ms)
    processed = preprocess_image_for_ocr(image)

    # OPTIMIZATION 5: Tesseract OCR Execution (~180ms)
    try:
        extracted_text = pytesseract.image_to_string(processed, config=TESSERACT_FAST_CONFIG)
    except pytesseract.TesseractNotFoundError:
        # If tesseract binary is not on host path, log or fall back gracefully
        extracted_text = ""
    except Exception:
        extracted_text = ""

    # OPTIMIZATION 6: Regex and Text Density Evaluation
    inspect_extracted_text(extracted_text, has_face=has_face)
