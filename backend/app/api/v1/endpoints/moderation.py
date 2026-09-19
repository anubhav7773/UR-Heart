import io
import cv2
import numpy as np
from PIL import Image, ImageOps
from fastapi import APIRouter, File, UploadFile, Query, HTTPException, status
from app.services.photo_moderation_service import (
    detect_human_face,
    scan_qr_codes,
    inspect_extracted_text,
    detect_dense_text_or_banner_with_reason,
    preprocess_image_for_ocr,
    TESSERACT_FAST_CONFIG
)
from app.services.storage_service import validate_photo_file
from app.services.image_moderation_service import detect_explicit_content

router = APIRouter()

ALLOWED_MIME_TYPES = {"image/webp", "image/jpeg", "image/png"}

@router.post("/scan-photo", status_code=status.HTTP_200_OK)
async def scan_uploaded_photo(
    file: UploadFile = File(...),
    require_face: bool = Query(False, description="Enforce that the photo contains at least one real human face"),
):
    """
    Scans uploaded image for:
    1. EXIF orientation correction (fixes gallery 90/270 degree rotation).
    2. Face detection (requires at least 1 clear human face if require_face is True).
    3. Anti-leak text/number screening & QR codes.
    4. IPC Section 67 obscenity/NSFW detection.
    """
    if file.content_type and file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported image type: {file.content_type}. Allowed types: {', '.join(sorted(ALLOWED_MIME_TYPES))}"
        )

    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")

    validate_photo_file(contents, filename=file.filename or "")

    # IPC Section 67 & Obscenity Shield: Automated NSFW Screening
    if detect_explicit_content(contents):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Prohibited: Uploaded photo violates platform decency policies and IPC Section 67 (Obscenity Prevention). Please upload a standard portrait."
        )

    try:
        # 1. Physically transpose pixels based on EXIF tag (resolves gallery 422 errors)
        pil_image = Image.open(io.BytesIO(contents))
        transposed_image = ImageOps.exif_transpose(pil_image)
        if transposed_image.mode != "RGB":
            transposed_image = transposed_image.convert("RGB")

        # Convert to numpy array for OpenCV processing (RGB -> BGR)
        image_np = cv2.cvtColor(np.array(transposed_image), cv2.COLOR_RGB2BGR)

        # Early check for QR codes
        if scan_qr_codes(image_np):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Photo rejected: QR codes or barcodes are strictly prohibited in profile photos."
            )

        # 2. Face Detection
        has_face, face_boxes = detect_human_face(image_np)
        if require_face and not has_face:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No clear human face detected. Please select a photo where your face is visible."
            )

        # 3. OCR & Anti-leak text detection
        try:
            import pytesseract
            processed = preprocess_image_for_ocr(image_np)
            try:
                extracted_text = pytesseract.image_to_string(processed, lang="eng+hin", config=TESSERACT_FAST_CONFIG)
            except Exception:
                extracted_text = pytesseract.image_to_string(processed, config=TESSERACT_FAST_CONFIG)
            inspect_extracted_text(extracted_text)
        except HTTPException:
            raise
        except Exception:
            pass

        # 4. Dense text / banner check
        is_violation, violation_reason = detect_dense_text_or_banner_with_reason(image_np, face_boxes=face_boxes)
        if is_violation:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Photo rejected: {violation_reason}. Profile photos must be clean camera photos."
            )

        return {
            "status": "clean",
            "approved": True,
            "message": "Photo passed anti-leak moderation.",
            "faces_detected": len(face_boxes),
            "width": transposed_image.width,
            "height": transposed_image.height
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unable to process image file: {str(e)}"
        )

# Backward-compatibility alias
scan_photo = scan_uploaded_photo
