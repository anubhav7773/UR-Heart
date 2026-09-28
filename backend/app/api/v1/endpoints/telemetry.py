from datetime import datetime, timezone
from typing import Any, Dict, Optional
from fastapi import APIRouter, Request, status
from pydantic import BaseModel, Field

router = APIRouter(prefix="/telemetry", tags=["Real-Time Activity Telemetry"])


class ActivityLogPayload(BaseModel):
    category: str = Field(..., description="E.g. AUTH, NAVIGATION, KYC, GPS, AI, MODERATION")
    action: str = Field(..., description="Action performed e.g. SCREEN_OPENED, DOB_SELECTED, VIDEO_KYC_STARTED")
    user_id: Optional[str] = "anonymous"
    screen: Optional[str] = None
    details: Optional[Dict[str, Any]] = None
    timestamp: Optional[str] = None


@router.post("/activity", status_code=status.HTTP_200_OK)
async def record_activity(payload: ActivityLogPayload, request: Request):
    """
    Real-Time Render Activity Telemetry Stream.
    Instantly outputs structured log to Render stdout with flush=True so every
    event on the mobile client is immediately visible in Render Live Logs.
    """
    client_ip = request.client.host if request.client else "unknown"
    utc_now = payload.timestamp or datetime.now(timezone.utc).isoformat()
    
    # Format high-visibility log for Render Dashboard
    print(
        f"\n==================== [UR-HEART LIVE ACTIVITY] ====================\n"
        f"TIME      : {utc_now}\n"
        f"CATEGORY  : {payload.category.upper()}\n"
        f"ACTION    : {payload.action}\n"
        f"USER      : {payload.user_id}\n"
        f"SCREEN    : {payload.screen or 'N/A'}\n"
        f"CLIENT IP : {client_ip}\n"
        f"DETAILS   : {payload.details or {}}\n"
        f"==================================================================\n",
        flush=True
    )
    
    return {
        "status": "logged",
        "timestamp": utc_now,
        "action": payload.action
    }
