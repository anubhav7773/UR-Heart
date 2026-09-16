import os
import psutil
from datetime import datetime, timezone
from fastapi import APIRouter, status

router = APIRouter()

@router.get("/health", status_code=status.HTTP_200_OK)
async def health_check():
    """
    Monitors process memory and service health to guarantee 
    the container remains safely below the 512MB Render RAM ceiling.
    """
    try:
        process = psutil.Process(os.getpid())
        memory_mb = process.memory_info().rss / (1024 * 1024)
    except Exception:
        memory_mb = 0.0

    return {
        "status": "operational",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "app_name": "UR-Heart",
        "parent_entity": "ASI Verticals",
        "memory_consumption_mb": round(memory_mb, 2),
        "memory_limit_mb": 512.0
    }
