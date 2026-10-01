import asyncio
from datetime import datetime
import logging
from typing import Dict, List, Optional, Any
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db, async_session_factory
from app.core.security import get_current_user
from app.models.domain.user import User
from app.services.chat_manager import manager

logger = logging.getLogger("urheart.notifications")
router = APIRouter(prefix="/notifications", tags=["In-App Notifications"])

# Memory notification queue keyed by user_id string
NOTIFICATION_STORE: Dict[str, List[Dict[str, Any]]] = {}

# Active device FCM token registry (cached in memory for high-throughput push)
USER_FCM_TOKENS: Dict[str, str] = {}


def _dispatch_fcm_push(fcm_token: str, title: str, body: str, data: Optional[Dict[str, Any]] = None) -> None:
    """Dispatches true outside-the-app push notification via Firebase Cloud Messaging."""
    try:
        from app.services.firebase_auth_service import FirebaseAuthService
        app = FirebaseAuthService.get_app()
        if not app:
            return

        from firebase_admin import messaging

        # Ensure all data values are string format for FCM protocol
        clean_data = {}
        if data:
            for k, v in data.items():
                clean_data[str(k)] = str(v)

        msg = messaging.Message(
            token=fcm_token,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=clean_data,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="ur_heart_sacred_dialogue",
                    sound="default",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                    icon="@mipmap/ic_launcher",
                    color="#1B4332",
                ),
            ),
        )
        messaging.send(msg, app=app)
        logger.info("[FCM PUSH SENT] token=...%s title='%s'", fcm_token[-8:], title)
    except Exception as e:
        logger.warning("[FCM PUSH NOTICE] Dispatch failed: %s", e)


def push_notification(
    user_id: str,
    notif_type: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> None:
    """
    Enqueues in-app notification, triggers real-time WebSocket delivery if user is online,
    and dispatches FCM background push notification if device token is registered.
    """
    user_key = str(user_id)
    if user_key not in NOTIFICATION_STORE:
        NOTIFICATION_STORE[user_key] = []

    import uuid as _uuid
    entry = {
        "id": f"notif_{int(datetime.utcnow().timestamp() * 1000)}_{_uuid.uuid4().hex[:6]}",
        "type": notif_type,
        "title": title,
        "body": body,
        "data": data or {},
        "is_read": False,
        "created_at": datetime.utcnow().isoformat()
    }
    NOTIFICATION_STORE[user_key].insert(0, entry)

    try:
        print(f"[NOTIFICATION ENQUEUED] user={user_key} type={notif_type} title='{title}'", flush=True)
    except Exception:
        safe_title = title.encode("ascii", "replace").decode("ascii")
        print(f"[NOTIFICATION ENQUEUED] user={user_key} type={notif_type} title='{safe_title}'", flush=True)

    # 1. Real-time WebSocket delivery to connected client
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            loop.create_task(manager.send_direct_message(user_key, {
                "type": "sanctuary_notification",
                "notification": entry
            }))
    except Exception:
        pass

    # 2. Outside-the-app Background FCM Push
    fcm_token = USER_FCM_TOKENS.get(user_key)
    if fcm_token:
        _dispatch_fcm_push(fcm_token, title, body, data)
    else:
        # Check DB asynchronously if not yet in RAM cache
        async def _check_db_and_push():
            try:
                async with async_session_factory() as session:
                    res = await session.execute(select(User.fcm_token).where(User.id == UUID(user_key)))
                    token_in_db = res.scalar_one_or_none()
                    if token_in_db:
                        USER_FCM_TOKENS[user_key] = token_in_db
                        _dispatch_fcm_push(token_in_db, title, body, data)
            except Exception:
                pass
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                loop.create_task(_check_db_and_push())
        except Exception:
            pass


class RegisterTokenRequest(BaseModel):
    fcm_token: str


@router.post("/register-token", status_code=status.HTTP_200_OK, summary="Register FCM Push Token")
async def register_device_token(
    payload: RegisterTokenRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Associates an FCM push token with the authenticated user for outside-the-app delivery."""
    token_val = payload.fcm_token.strip()
    if not token_val:
        raise HTTPException(status_code=400, detail="fcm_token cannot be empty.")

    current_user.fcm_token = token_val
    USER_FCM_TOKENS[str(current_user.id)] = token_val
    await db.commit()
    logger.info("Registered FCM token for user %s: ...%s", current_user.id, token_val[-8:])

    return {"status": "success", "message": "FCM device token registered successfully."}


class MarkReadRequest(BaseModel):
    notification_id: Optional[str] = None


@router.get("", status_code=status.HTTP_200_OK, summary="Get In-App Notifications")
@router.get("/", status_code=status.HTTP_200_OK, summary="Get In-App Notifications")
async def get_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Returns list of notifications and unread count for current user."""
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
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
