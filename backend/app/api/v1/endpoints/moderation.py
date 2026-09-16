from fastapi import APIRouter, File, UploadFile, HTTPException, status
from app.services.photo_moderation_service import validate_uploaded_photo
from app.services.storage_service import validate_photo_file

router = APIRouter()

ALLOWED_MIME_TYPES = {"image/webp", "image/jpeg", "image/png"}

@router.post("/scan-photo", status_code=status.HTTP_200_OK)
async def scan_photo(file: UploadFile = File(...)):
    """
    Scans uploaded image for phone numbers, social media handles, and QR codes.
    Enforces Security Check 16 (magic bytes, size <= 150KB, disallowed extensions).
    Returns HTTP 200 with clean status on pass, or raises HTTP 413/422 on violation.
    """
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported image type: {file.content_type}. Allowed types: {', '.join(sorted(ALLOWED_MIME_TYPES))}"
        )

    contents = await file.read()
    validate_photo_file(contents, filename=file.filename or "")

    # Reset file pointer for subsequent OCR processing
    await file.seek(0)
    await validate_uploaded_photo(file)

    return {
        "status": "clean",
        "message": "Photo passed anti-leak moderation."
    }
