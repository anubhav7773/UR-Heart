from datetime import datetime
from typing import Dict, List, Optional, Any
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user_optional
from app.models.domain.user import User

router = APIRouter(prefix="/notifications", tags=["In-App Notifications"])

# Memory notification queue keyed by user_id string
NOTIFICATION_STORE: Dict[str, List[Dict[str, Any]]] = {}


def push_notification(
    user_id: str,
    notif_type: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> None:
    """Enqueues an in-app notification for a user."""
    user_key = str(user_id)
    if user_key not in NOTIFICATION_STORE:
        NOTIFICATION_STORE[user_key] = []

    entry = {
        "id": f"notif_{int(datetime.utcnow().timestamp() * 1000)}",
        "type": notif_type,
        "title": title,
        "body": body,
        "data": data or {},
        "is_read": False,
        "created_at": datetime.utcnow().isoformat()
    }
    NOTIFICATION_STORE[user_key].insert(0, entry)
    if len(NOTIFICATION_STORE[user_key]) > 50:
        NOTIFICATION_STORE[user_key] = NOTIFICATION_STORE[user_key][:50]
    print(f"[NOTIFICATION ENQUEUED] user={user_key} type={notif_type} title='{title}'", flush=True)


class MarkReadRequest(BaseModel):
    notification_id: Optional[str] = None


@router.get("", status_code=status.HTTP_200_OK, summary="Get In-App Notifications")
@router.get("/", status_code=status.HTTP_200_OK, summary="Get In-App Notifications")
async def get_notifications(
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    """Returns list of notifications and unread count for current user."""
    if not current_user:
        return {"status": "success", "notifications": [], "unread_count": 0}

    user_key = str(current_user.id)
    items = NOTIFICATION_STORE.get(user_key, [])
    unread = sum(1 for n in items if not n.get("is_read", False))

    return {
        "status": "success",
        "unread_count": unread,
        "notifications": items
    }


@router.post("/mark-read", status_code=status.HTTP_200_OK, summary="Mark Notifications as Read")
async def mark_notifications_read(
    payload: MarkReadRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db)
):
    if not current_user:
        return {"status": "ok", "unread_count": 0}

    user_key = str(current_user.id)
    items = NOTIFICATION_STORE.get(user_key, [])

    if payload.notification_id:
        for n in items:
            if n.get("id") == payload.notification_id:
                n["is_read"] = True
    else:
        for n in items:
            n["is_read"] = True

    return {"status": "success", "unread_count": sum(1 for n in items if not n.get("is_read", False))}
