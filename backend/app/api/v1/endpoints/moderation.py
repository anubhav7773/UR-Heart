from fastapi import APIRouter, File, UploadFile, Query, HTTPException, status
from app.services.photo_moderation_service import validate_uploaded_photo
from app.services.storage_service import validate_photo_file

router = APIRouter()

ALLOWED_MIME_TYPES = {"image/webp", "image/jpeg", "image/png"}

@router.post("/scan-photo", status_code=status.HTTP_200_OK)
async def scan_photo(
    file: UploadFile = File(...),
    require_face: bool = Query(False, description="Enforce that the photo contains at least one real human face"),
):
    """
    Scans uploaded image for phone numbers, social media handles, and QR codes.
    Enforces Security Check 16 (magic bytes, size <= 150KB, disallowed extensions).
    When require_face is true, ensures a real human face is detected.
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
    await validate_uploaded_photo(file, require_face=require_face)

    return {
        "status": "clean",
        "message": "Photo passed anti-leak moderation."
    }
