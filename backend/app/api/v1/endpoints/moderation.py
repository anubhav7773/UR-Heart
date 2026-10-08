from fastapi import APIRouter, File, HTTPException, UploadFile, status
from pydantic import BaseModel, Field
from app.services.photo_moderator import PhotoModerationService
from app.services.chat_sanitizer import ChatSanitizerService

router = APIRouter(prefix="/moderation", tags=["Safety & Moderation"])


class ChatModerationRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=1000)


class ChatModerationResponse(BaseModel):
    is_safe: bool
    sanitized_text: str
    flagged: bool = False


@router.post("/photo", status_code=status.HTTP_200_OK)
async def moderate_photo(file: UploadFile = File(...)):
    """
    Dual-stage AI & CV photo moderation gatekeeper:
    1. Early-exit OpenCV QR, Tesseract OCR & Torso Skin ratio
    2. Groq Llama-3.2 Vision multimodal intimacy/shirtless detection
    Returns 200 with status or rejection message.
    """
    contents = await file.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty image payload provided."
        )

    is_safe, message, category = await PhotoModerationService.inspect_photo_bytes_with_ai(contents)
    if not is_safe:
        return {
            "status": "rejected",
            "is_safe": False,
            "category": category,
            "reason": message
        }

    return {
        "status": "approved",
        "is_safe": True,
        "message": "Photo verified safe"
    }


@router.post("/chat", status_code=status.HTTP_200_OK, response_model=ChatModerationResponse)
async def moderate_chat(payload: ChatModerationRequest):
    """
    Real-Time NLP chat sanitizer enforcing IT Rules 2021 off-platform restrictions.
    Throws HTTP 422 on detected numbers, transliterated digits, or social handles.
    """
    is_safe, sanitized_or_reason = ChatSanitizerService.sanitize_message(payload.text)

    if not is_safe:
        raise HTTPException(
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", status.HTTP_422_UNPROCESSABLE_ENTITY),
            detail=sanitized_or_reason
        )

    return ChatModerationResponse(
        is_safe=True,
        sanitized_text=sanitized_or_reason,
        flagged=False
    )
