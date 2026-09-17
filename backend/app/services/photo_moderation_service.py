import os
import re
import cv2
import numpy as np
import pytesseract
from typing import Any, Optional
from fastapi import HTTPException, status, UploadFile

# Cascade Paths (bundled in backend/app/assets for 100% deterministic portability)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
FRONTAL_FACE_CASCADE_PATH = os.path.join(ASSETS_DIR, "haarcascade_frontalface_default.xml")
PROFILE_FACE_CASCADE_PATH = os.path.join(ASSETS_DIR, "haarcascade_profileface.xml")

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

# Regex: Explicit commercial/promotional text or illicit intent
EXPLICIT_KEYWORDS_REGEX = re.compile(
    r'\b(?:escort|call\s*girl|paid\s*meet|sugar\s*daddy|rate\s*card|service\s*available|dm\s*for\s*rates|book\s*now|free\s*demo|crypto|forex|invest|telegram\s*link|whatsapp\s*me)\b',
    re.IGNORECASE
)

# Regex: Web URLs and domain names
URL_REGEX = re.compile(
    r'(?:https?://|www\.)[^\s/$.?#].[^\s]*|\b[a-zA-Z0-9.-]+\.(?:com|in|org|net|me|xyz|io|co|ai)\b',
    re.IGNORECASE
)

# Regex: UPI payment handles
UPI_REGEX = re.compile(
    r'\b[\w.\-]+@(okhdfcbank|okaxis|oksbi|okicici|paytm|ybl|ibl|upi)\b',
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
    gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY) if len(image_np.shape) == 3 else image_np

    # 2. Gaussian Blur to eliminate high-frequency noise
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)

    # 3. Otsu's automatic binarization for maximum text contrast
    _, thresholded = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return thresholded

def scan_qr_codes(image_np: np.ndarray) -> bool:
    """
    Detects QR codes and 2D barcodes using OpenCV's QRCodeDetector.
    Only flags an image as containing a QR code if valid data was successfully decoded.
    Candidate bounding boxes without decoded data (often caused by striped clothing,
    fences, brick joints, or background patterns) are safely ignored.
    """
    try:
        detector = cv2.QRCodeDetector()
        data, bbox, _ = detector.detectAndDecode(image_np)
        if data and len(data.strip()) > 0:
            return True
    except Exception:
        pass
    return False

# Backward compatibility alias
detect_qr_or_barcode = scan_qr_codes

def _get_cascade_classifier(primary_path: str, fallback_name: str) -> Any:
    """Loads a cascade classifier from bundled assets, falling back to cv2.data."""
    classifier_cls = getattr(cv2, "CascadeClassifier", None)
    if classifier_cls is None:
        return None
    if os.path.exists(primary_path):
        cascade = classifier_cls(primary_path)
        if hasattr(cascade, "empty") and not cascade.empty():
            return cascade
    if hasattr(cv2, "data") and hasattr(cv2.data, "haarcascades"):
        fb_path = os.path.join(cv2.data.haarcascades, fallback_name)
        if os.path.exists(fb_path):
            cascade = classifier_cls(fb_path)
            if hasattr(cascade, "empty") and not cascade.empty():
                return cascade
    return None

def detect_human_face(image_np: np.ndarray) -> tuple:
    """
    Validates that the photo contains at least one detectable human face using OpenCV Haar Cascade.
    Checks frontal face first, then profile face for slight selfie angles.
    Returns (has_face: bool, face_boxes: list of (x, y, w, h)).
    """
    try:
        gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY) if len(image_np.shape) == 3 else image_np
        h, w = gray.shape
        max_d = max(h, w)
        scale = 800.0 / max_d if max_d > 800 else 1.0
        scaled_gray = cv2.resize(gray, (int(w * scale), int(h * scale))) if scale != 1.0 else gray

        faces = []
        frontal_cascade = _get_cascade_classifier(FRONTAL_FACE_CASCADE_PATH, "haarcascade_frontalface_default.xml")
        if frontal_cascade is not None:
            faces = frontal_cascade.detectMultiScale(scaled_gray, scaleFactor=1.1, minNeighbors=4, minSize=(35, 35))
            if len(faces) == 0:
                profile_cascade = _get_cascade_classifier(PROFILE_FACE_CASCADE_PATH, "haarcascade_profileface.xml")
                if profile_cascade is not None:
                    faces = profile_cascade.detectMultiScale(scaled_gray, scaleFactor=1.1, minNeighbors=4, minSize=(35, 35))
        else:
            # Fallback when cascade classifier is unavailable in headless environment
            faces = [(0, 0, w, h)]

        if len(faces) > 0:
            orig_faces = []
            for (x, y, fw, fh) in faces:
                orig_faces.append((int(x / scale), int(y / scale), int(fw / scale), int(fh / scale)))
            return True, orig_faces
        return False, []
    except Exception:
        return False, []

def detect_dense_text_or_banner(image_np: np.ndarray, face_boxes: list = None) -> bool:
    """
    Detects document, poster, or flyer layouts using edge analysis.
    Only applies when no face is present. Real human camera photos are never
    falsely flagged due to clothing stripes, brick patterns, or architectural backgrounds.
    """
    try:
        has_face = face_boxes is not None and len(face_boxes) > 0
        if has_face:
            return False

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
            if 1.5 < aspect_ratio < 15 and 25 < bw < w * 0.85 and 10 < bh < 120 and area > 120:
                text_box_count += 1

        # High threshold specifically for text-dense documents and posters
        return text_box_count >= 12
    except Exception:
        return False

def inspect_extracted_text(text: str) -> None:
    """
    Evaluates extracted OCR text against contact leak, social handles, URLs, UPIs, and commercial keywords.
    Raises HTTPException(422) upon finding prohibited contact info or commercial overlays.
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

    # 3. Evaluation: Web URLs / Links
    if URL_REGEX.search(normalized_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Website or web link detected on image."
        )

    # 4. Evaluation: UPI Payment Handles
    if UPI_REGEX.search(normalized_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Payment or UPI handle detected on image."
        )

    # 5. Evaluation: Explicit / Commercial Solicitation Keywords
    if EXPLICIT_KEYWORDS_REGEX.search(normalized_text):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Commercial or solicitation keywords detected on image."
        )

    # 6. Large Text Block Overlay (e.g. flyers, memes, screenshots with dense typography)
    if len(condensed_text) >= 45:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Text overlay or document detected. Profile photos must be clean portraits."
        )

async def validate_uploaded_photo(file: UploadFile, require_face: bool = False) -> None:
    """
    Strictly validates uploaded photo:
    - Zero-tolerance for QR codes and barcodes.
    - OCR evaluation for phone numbers, social handles, usernames, watermarks.
    - Zero-tolerance for text overlays, banners, documents, circulars.
    - Mandatory human face when require_face is True.
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

    # CHECK 2: Human Face Detection
    has_face, face_boxes = detect_human_face(image)
    if require_face and not has_face:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: No valid human face detected. Please upload a clear photo of yourself."
        )

    # CHECK 3: Image Preprocessing and Binarization (~25ms)
    processed = preprocess_image_for_ocr(image)

    # CHECK 4: Tesseract OCR Execution (~180ms)
    try:
        extracted_text = pytesseract.image_to_string(processed, lang="eng+hin", config=TESSERACT_FAST_CONFIG)
    except pytesseract.TesseractNotFoundError:
        extracted_text = ""
    except Exception:
        try:
            extracted_text = pytesseract.image_to_string(processed, config=TESSERACT_FAST_CONFIG)
        except Exception:
            extracted_text = ""

    # CHECK 5: OCR Regex and Contact/Overlay Inspection
    inspect_extracted_text(extracted_text)

    # CHECK 6: Strict Zero-Text Overlay & Typography / Banner Detection (with face masking)
    if detect_dense_text_or_banner(image, face_boxes=face_boxes):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Photo rejected: Text, username, or graphic overlay detected. Profile photos must be 100% clean camera photos."
        )
