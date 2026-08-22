from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from app.models.schemas import APIResponse

router = APIRouter(prefix="/system", tags=["System & In-App Auto Update"])


class AppVersionData(BaseModel):
    min_version: str = "1.0.0"
    min_required_version: str = "1.0.0"
    latest_version: str = "1.0.1"
    latest_build_number: int = 2003
    min_supported_version: str = "1.0.0"
    min_supported_build_number: int = 2000
    apk_url: Optional[str] = "https://github.com/anubhav7773/UR-Heart/releases/download/v1.0.1/UR-Heart-arm64-v8a.apk"
    download_url: Optional[str] = "https://github.com/anubhav7773/UR-Heart/releases/download/v1.0.1/UR-Heart-arm64-v8a.apk"
    release_notes: str = "Bug fixes: WebSocket chat stability, bubble alignment, and UI cleanup."
    force_update: bool = False
    is_force_update: bool = False


@router.get("/app-version", response_model=APIResponse[AppVersionData])
async def get_app_version():
    """
    Public configuration endpoint returning the latest client version and direct APK download URL.
    Enables beta testers/friends to download and install new APK updates directly inside the app.
    """
    return APIResponse(
        success=True,
        message="App version configuration retrieved successfully.",
        data=AppVersionData()
    )

