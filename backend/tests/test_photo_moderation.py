import time
import io
import cv2
import numpy as np
import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from app.main import app
from app.services.photo_moderation_service import (
    preprocess_image_for_ocr,
    scan_qr_codes,
    inspect_extracted_text
)

client = TestClient(app)

def create_clean_image_bytes() -> bytes:
    """Generates a synthetic clean gradient image without any text."""
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    for i in range(400):
        img[i, :, :] = [int(i * 255 / 400), 50, int((400 - i) * 255 / 400)]
    _, buffer = cv2.imencode('.jpg', img)
    return buffer.tobytes()

def create_text_overlay_image_bytes(text: str) -> bytes:
    """Generates a synthetic image with drawn text overlay using cv2.putText."""
    img = np.full((400, 400, 3), 240, dtype=np.uint8)
    # Draw dark text on light background
    cv2.putText(
        img,
        text,
        (20, 200),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.0,
        (10, 10, 10),
        2,
        cv2.LINE_AA
    )
    _, buffer = cv2.imencode('.jpg', img)
    return buffer.tobytes()

def create_qr_code_image_bytes(data: str = "https://ur-heart.com/chat/reveal") -> bytes:
    """Generates a synthetic image containing an encoded QR matrix."""
    encoder = cv2.QRCodeEncoder_create()
    qr_raw = encoder.encode(data)
    # Scale up and add quiet zone (white border)
    qr_scaled = cv2.resize(qr_raw, (280, 280), interpolation=cv2.INTER_NEAREST)
    qr_with_border = cv2.copyMakeBorder(qr_scaled, 30, 30, 30, 30, cv2.BORDER_CONSTANT, value=255)
    # Convert to 3-channel image
    qr_color = cv2.cvtColor(qr_with_border, cv2.COLOR_GRAY2BGR)
    _, buffer = cv2.imencode('.png', qr_color)
    return buffer.tobytes()

# ==============================================================================
# TEST CATEGORY 1: Clean Image Acceptance
# ==============================================================================
def test_clean_image_acceptance():
    """A clean image without text or barcodes must return HTTP 200 clean."""
    image_bytes = create_clean_image_bytes()
    files = {"file": ("clean_profile.jpg", image_bytes, "image/jpeg")}

    response = client.post("/api/v1/moderation/scan-photo", files=files)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["status"] == "clean"
    assert "passed" in data["message"].lower()

# ==============================================================================
# TEST CATEGORY 2: Phone Number Overlay Interception
# ==============================================================================
@pytest.mark.parametrize("phone_sample", [
    "9876543210",
    "+91 98765 43210",
    "98765-43210",
    "Call me 8765432109"
])
def test_phone_number_overlay_interception(phone_sample):
    """An image with phone number text overlay must be rejected with HTTP 422."""
    image_bytes = create_text_overlay_image_bytes(phone_sample)
    files = {"file": ("phone_overlay.jpg", image_bytes, "image/jpeg")}

    with patch("pytesseract.image_to_string", return_value=phone_sample):
        response = client.post("/api/v1/moderation/scan-photo", files=files)

    assert response.status_code == 422, response.text
    assert "Contact numbers detected" in response.json()["detail"]

# ==============================================================================
# TEST CATEGORY 3: Social Handle Overlay Interception
# ==============================================================================
@pytest.mark.parametrize("social_sample", [
    "insta: @priya_01",
    "@rahul_verma",
    "sc: aman_singh",
    "wa: rahul_v",
    "tele: desi_boy"
])
def test_social_handle_overlay_interception(social_sample):
    """An image with social media handle overlay must be rejected with HTTP 422."""
    image_bytes = create_text_overlay_image_bytes(social_sample)
    files = {"file": ("social_overlay.jpg", image_bytes, "image/jpeg")}

    with patch("pytesseract.image_to_string", return_value=social_sample):
        response = client.post("/api/v1/moderation/scan-photo", files=files)

    assert response.status_code == 422, response.text
    assert "Social media handles" in response.json()["detail"]

# ==============================================================================
# TEST CATEGORY 4: QR Code Early-Exit Detection
# ==============================================================================
def test_qr_code_early_exit():
    """An image with an encoded QR matrix must trigger early exit with HTTP 422."""
    qr_bytes = create_qr_code_image_bytes("https://wa.me/919876543210")
    files = {"file": ("qr_contact.png", qr_bytes, "image/png")}

    start_time = time.perf_counter()
    response = client.post("/api/v1/moderation/scan-photo", files=files)
    elapsed_ms = (time.perf_counter() - start_time) * 1000

    assert response.status_code == 422, response.text
    assert "QR codes or barcodes are strictly prohibited" in response.json()["detail"]
    # Early-exit target is < 50ms for local detection
    assert elapsed_ms < 150.0

# ==============================================================================
# TEST CATEGORY 5: Execution Benchmark (< 400ms) & Preprocessor Verification
# ==============================================================================
def test_preprocessing_and_benchmark():
    """Confirms image preprocessing pipeline downscales and finishes well under 400ms."""
    # Large 1600x1200 image
    large_img = np.full((1200, 1600, 3), 180, dtype=np.uint8)
    start_time = time.perf_counter()

    processed = preprocess_image_for_ocr(large_img)
    elapsed_ms = (time.perf_counter() - start_time) * 1000

    assert max(processed.shape[:2]) <= 800
    assert elapsed_ms < 100.0, f"Preprocessing took {elapsed_ms}ms, target is < 100ms"

# ==============================================================================
# TEST CATEGORY 6: Document / Certificate / Poster Interception
# ==============================================================================
def test_document_table_grid_interception():
    """Documents and certificates with table grids must be rejected with HTTP 422."""
    img = np.full((600, 600, 3), 255, dtype=np.uint8)
    # Draw horizontal and vertical grid lines
    for y in range(50, 550, 40):
        cv2.line(img, (50, y), (550, y), (0, 0, 0), 2)
    for x in range(50, 550, 60):
        cv2.line(img, (x, 50), (x, 500), (0, 0, 0), 2)
    _, buffer = cv2.imencode('.jpg', img)

    files = {"file": ("document_form.jpg", buffer.tobytes(), "image/jpeg")}
    response = client.post("/api/v1/moderation/scan-photo", files=files)
    assert response.status_code == 422
    assert "table grid" in response.json()["detail"].lower() or "document" in response.json()["detail"].lower()

def test_camera_watermark_frame_interception():
    """Photos inside thick camera watermark / letterbox borders must be rejected."""
    img = np.full((600, 600, 3), 200, dtype=np.uint8)
    # Draw black outer border around entire image
    cv2.rectangle(img, (0, 0), (600, 600), (5, 5, 5), 40)
    _, buffer = cv2.imencode('.jpg', img)

    files = {"file": ("watermark_border.jpg", buffer.tobytes(), "image/jpeg")}
    response = client.post("/api/v1/moderation/scan-photo", files=files)
    assert response.status_code == 422
    assert "watermark frame" in response.json()["detail"].lower() or "letterbox" in response.json()["detail"].lower()

