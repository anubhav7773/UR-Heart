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
