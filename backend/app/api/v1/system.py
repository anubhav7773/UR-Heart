from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from app.models.schemas import APIResponse

router = APIRouter(prefix="/system", tags=["System & In-App Auto Update"])


class AppVersionData(BaseModel):
    latest_version: str = "1.0.0"
    latest_build_number: int = 1
    min_supported_version: str = "1.0.0"
    min_supported_build_number: int = 1
    apk_url: Optional[str] = None
    release_notes: str = "✨ Bug fixes and performance improvements."
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
