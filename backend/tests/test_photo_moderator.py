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
async def test_contact_number_detected_and_rejected():
    """Photo with contact numbers or digits is instantly rejected to protect Sacred Bridge."""
    img = np.full((400, 400, 3), 255, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_contact_phone.jpg"
    )

    with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value="Call +91 9876543210"):
        with pytest.raises(PolicyViolationException) as exc_info:
            await scan_and_validate_photo(file)

        assert "Contact numbers" in exc_info.value.detail or "contact" in exc_info.value.detail.lower()


@pytest.mark.asyncio
async def test_social_handle_detected_and_rejected():
    """Photo with social handles (@handle) is instantly rejected to protect Sacred Bridge."""
    img = np.full((400, 400, 3), 240, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_social_handle.jpg"
    )

    with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value="Follow me @seeker_sanctuary"):
        with pytest.raises(PolicyViolationException) as exc_info:
            await scan_and_validate_photo(file)

        assert "Social media" in exc_info.value.detail or "contact" in exc_info.value.detail.lower()


@pytest.mark.asyncio
async def test_endpoint_moderate_photo_rejects_contact_leak():
    """Endpoint POST /api/v1/moderation/photo returns structured rejection for contact leaks."""
    from app.api.v1.endpoints.moderation import moderate_photo

    img = np.full((400, 400, 3), 255, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_endpoint_contact.jpg"
    )

    with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value="DM me on insta: sacred_soul"):
        res = await moderate_photo(file)
        assert res["status"] == "rejected"
        assert res["is_safe"] is False
        assert res["category"] == "contact_leak"
        assert "Social media" in res["reason"] or "Contact" in res["reason"]


@pytest.mark.asyncio
async def test_endpoint_moderate_photo_approves_clean():
    """Endpoint POST /api/v1/moderation/photo returns approval for clean photo without contact leaks."""
    from app.api.v1.endpoints.moderation import moderate_photo

    img = np.full((400, 400, 3), 200, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)
    file = UploadFile(
        file=io.BytesIO(buffer.tobytes()),
        filename="test_endpoint_clean.jpg"
    )

    with patch("app.services.groq_service.GroqAiService.moderate_image_vision", return_value={"is_safe": True, "reason": "", "category": "safe"}):
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


@pytest.mark.asyncio
async def test_user_uploaded_authentic_photos_pass():
    """Verifies that artistic devotional edits and close-up portraits pass inspection cleanly."""
    import os
    from app.services.photo_moderator import PhotoModerationService

    user_dir = "C:/Users/kshtr/.gemini/antigravity-ide/brain/8d8687f3-41ef-4a8c-8343-f501daafdc1d/.user_uploaded"
    for img_name in ["media_1791461310236.jpg", "media_1791461316955.png"]:
        full_path = os.path.join(user_dir, img_name)
        if os.path.exists(full_path):
            with open(full_path, "rb") as f:
                img_bytes = f.read()
            is_safe, reason, cat = PhotoModerationService.inspect_photo_bytes(img_bytes)
            assert is_safe is True, f"Image {img_name} was falsely rejected: {reason} ({cat})"
            assert cat == "safe"


@pytest.mark.asyncio
async def test_bare_external_links_detected_and_rejected():
    """Bare external links without https:// or www. are detected and rejected to protect Sacred Bridge."""
    from app.services.photo_moderator import PhotoModerationService

    img = np.full((300, 300, 3), 200, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)

    bare_links = [
        "check out instagram.com/seeker_sanctuary",
        "chat on t.me/sacred_user",
        "connect via wa.me/sacred_chat",
        "all links linktr.ee/seeker_profile",
    ]

    for link_text in bare_links:
        with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value=link_text):
            is_safe, reason, category = await PhotoModerationService.inspect_photo_bytes_async(buffer.tobytes())
            assert is_safe is False, f"Failed to reject bare link: {link_text}"
            assert category == "contact_leak"
            assert "Social media handles or external contact links" in reason


@pytest.mark.asyncio
async def test_ordinary_words_not_treated_as_contact_identifiers():
    """Ordinary English phrases like 'call him' or 'oh snap' must never be falsely flagged as contact leaks."""
    from app.services.photo_moderator import PhotoModerationService

    img = np.full((300, 300, 3), 200, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)

    ordinary_phrases = [
        "Call him today for coffee",
        "A wake up call for you",
        "Oh snap dude that looks awesome",
        "Please dm me later tonight",
    ]

    for phrase in ordinary_phrases:
        with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value=phrase):
            is_safe, reason, category = await PhotoModerationService.inspect_photo_bytes_async(buffer.tobytes())
            assert is_safe is True, f"Falsely rejected ordinary phrase '{phrase}': {reason} ({category})"
            assert category == "safe"


@pytest.mark.asyncio
async def test_contact_identifiers_with_delimiters_rejected():
    """Contact handles with explicit delimiters (snap:, ig:, dm me:) are rejected."""
    from app.services.photo_moderator import PhotoModerationService

    img = np.full((300, 300, 3), 200, dtype=np.uint8)
    _, buffer = cv2.imencode('.jpg', img)

    contact_handles = [
        "snap: cool_seeker",
        "ig: sacred_vibes",
        "dm me: @sanctuary_user",
    ]

    for handle in contact_handles:
        with patch("app.services.photo_moderator.pytesseract.image_to_string", return_value=handle):
            is_safe, reason, category = await PhotoModerationService.inspect_photo_bytes_async(buffer.tobytes())
            assert is_safe is False, f"Failed to reject handle: {handle}"
            assert category == "contact_leak"



