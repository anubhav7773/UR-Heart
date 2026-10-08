import io
from unittest.mock import patch
import cv2
import numpy as np
import pytest
from fastapi import UploadFile
from app.services.photo_moderator import scan_and_validate_photo
from app.core.exceptions import PolicyViolationException


@pytest.mark.asyncio
async def test_clean_photo_passes_validation():
    """Clean plain photo without QR or text overlays passes validation."""
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    img[:] = (200, 200, 200)
    _, buffer = cv2.imencode('.jpg', img)

    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_clean.jpg"
    )

    # Should not raise exception
    await scan_and_validate_photo(file)


@pytest.mark.asyncio
async def test_qr_code_detected_and_rejected():
    """Verifies that when QR/barcode detector triggers, photo is rejected with PolicyViolationException."""
    img = np.zeros((200, 200, 3), dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)

    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_qr.jpg"
    )

    with patch("app.services.photo_moderator.scan_qr_and_barcodes", return_value=True):
        with pytest.raises(PolicyViolationException) as exc_info:
            await scan_and_validate_photo(file)

        assert "QR Codes" in exc_info.value.detail


@pytest.mark.asyncio
async def test_ai_edited_and_filtered_photo_without_text_passes():
    """AI-edited, portrait-enhanced, or filtered photo without text passes validation cleanly."""
    # Synthetic filtered portrait canvas (warm vintage color filter gradient)
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    for y in range(400):
        # Warm golden hour / vintage filter curve
        img[y, :] = (int(80 + y * 0.2), int(120 + y * 0.15), int(180 + y * 0.1))

    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_vintage_filter.jpg"
    )

    # Must pass without raising PolicyViolationException
    await scan_and_validate_photo(file)


@pytest.mark.asyncio
async def test_photo_with_text_detected_and_instant_rejected():
    """Photo with text overlay (quote, meme, caption, watermark) is instantly rejected."""
    img = np.full((400, 400, 3), 255, dtype=np.uint8)
    cv2.putText(img, "Hello World", (30, 200), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 0), 2)

    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_text_meme.jpg"
    )

    with pytest.raises(PolicyViolationException) as exc_info:
        await scan_and_validate_photo(file)

    assert "Text detected in photo" in exc_info.value.detail


@pytest.mark.asyncio
async def test_photo_with_minor_text_instant_rejected():
    """Photo with even minor text (small watermark or caption) is instantly rejected."""
    img = np.full((400, 400, 3), 240, dtype=np.uint8)
    cv2.putText(img, "Sanctuary", (20, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (15, 15, 15), 2)

    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_minor_watermark.jpg"
    )

    with pytest.raises(PolicyViolationException) as exc_info:
        await scan_and_validate_photo(file)

    assert "Text detected in photo" in exc_info.value.detail


@pytest.mark.asyncio
async def test_endpoint_moderate_photo_rejects_text():
    """Endpoint POST /api/v1/moderation/photo returns structured rejection for text."""
    from app.api.v1.endpoints.moderation import moderate_photo

    img = np.full((400, 400, 3), 255, dtype=np.uint8)
    cv2.putText(img, "Hello World", (30, 200), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 0), 2)
    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_endpoint_text.jpg"
    )

    res = await moderate_photo(file)
    assert res["status"] == "rejected"
    assert res["is_safe"] is False
    assert res["category"] == "text_detected"
    assert "Text detected in photo" in res["reason"]


@pytest.mark.asyncio
async def test_endpoint_moderate_photo_approves_clean():
    """Endpoint POST /api/v1/moderation/photo returns approval for clean photo."""
    from app.api.v1.endpoints.moderation import moderate_photo

    img = np.full((400, 400, 3), 200, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_endpoint_clean.jpg"
    )

    res = await moderate_photo(file)
    assert res["status"] == "approved"
    assert res["is_safe"] is True
    assert res["message"] == "Photo verified safe"


@pytest.mark.asyncio
async def test_structured_contact_leak_category_propagation():
    """Verifies contact leaks / digits return category='contact_leak' across the flow."""
    from app.services.photo_moderator import PhotoModerationService

    img = np.full((300, 300, 3), 200, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)

    with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value="Call +91 9876543210"):
        is_safe, reason, category = await PhotoModerationService.inspect_photo_bytes_async(buffer.tobytes())
        assert is_safe is False
        assert category == "contact_leak"
        assert "Contact numbers" in reason


@pytest.mark.asyncio
async def test_single_collar_or_belt_stripe_not_falsely_rejected():
    """Verifies that a single horizontal stripe/collar does NOT falsely trigger contour rejection."""
    from app.services.photo_moderator import detect_cv_text_regions

    img_collar = np.full((300, 300, 3), 230, dtype=np.uint8)
    # Draw a single clean dark horizontal line representing a collar edge
    cv2.line(img_collar, (40, 150), (120, 150), (40, 40, 40), 2)

    has_text = detect_cv_text_regions(img_collar)
    assert has_text is False


@pytest.mark.asyncio
async def test_groq_vision_unavailable_fails_closed_when_key_configured():
    """Verifies that when GROQ_API_KEY is configured and request fails, photo is NOT approved."""
    from app.services.groq_service import GroqAiService

    with patch("app.services.groq_service.settings") as mock_settings:
        mock_settings.GROQ_API_KEY = "gsk_mock_configured_key"
        mock_settings.OPENROUTER_API_KEY = ""
        with patch("httpx.AsyncClient.post", side_effect=Exception("Connection timeout")):
            result = await GroqAiService.moderate_image_vision("fake_b64_payload")
            assert result["is_safe"] is False
            assert result["category"] == "service_unavailable"
            assert "unavailable" in result["reason"].lower()


