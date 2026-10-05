import asyncio
import inspect
from datetime import datetime
import logging
from typing import Dict, List, Optional, Any
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db, async_session_factory
from app.core.security import get_current_user
from app.models.domain.user import User
from app.models.domain.device_fcm_token import DeviceFcmToken
from app.services.chat_manager import manager

logger = logging.getLogger("urheart.notifications")
router = APIRouter(prefix="/notifications", tags=["In-App Notifications"])

# Memory notification queue keyed by user_id string
NOTIFICATION_STORE: Dict[str, List[Dict[str, Any]]] = {}

# Active device FCM token registry (cached in memory for high-throughput push)
USER_FCM_TOKENS: Dict[str, set[str]] = {}

# Main server event loop (captured in FastAPI lifespan). Allows push_notification()
# to be called safely from worker threads without touching the DB pool from a foreign loop.
_MAIN_LOOP: Optional[asyncio.AbstractEventLoop] = None

# Android notification channels (must match Flutter SanctuaryNotificationService)
DIALOGUE_CHANNEL_ID = "ur_heart_sacred_dialogue"
PRESENCE_CHANNEL_ID = "ur_heart_presence_channel"
ANDROID_NOTIFICATION_ICON = "ic_stat_urheart"
FCM_TTL_SECONDS = 24 * 60 * 60
ALLOWED_NOTIFICATION_ROUTES = {
    "/",
    "/main",
    "/chat-dialogue",
    "/resonances",
    "/growth-hub",
    "/streaks",
}

# Strong references to in-flight delivery tasks (prevents premature GC of create_task results)
_BG_TASKS: set = set()


def _log(line: str) -> None:
    """Render only surfaces stdout reliably; print with flush and ASCII-safe fallback."""
    try:
        print(line, flush=True)
    except Exception:
        print(line.encode("ascii", "replace").decode("ascii"), flush=True)


def set_main_loop(loop: Optional[asyncio.AbstractEventLoop]) -> None:
    global _MAIN_LOOP
    _MAIN_LOOP = loop


def channel_for_type(notif_type: str) -> str:
    return PRESENCE_CHANNEL_ID if "streak" in (notif_type or "").lower() else DIALOGUE_CHANNEL_ID


def build_fcm_message(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    notif_type: str = "system",
    notif_id: Optional[str] = None,
):
    """Builds a high-priority FCM v1 message delivered by the OS even when the app is killed."""
    from firebase_admin import messaging

    # FCM data values must be strings
    clean_data: Dict[str, str] = {}
    for k, v in (data or {}).items():
        if v is None:
            continue
        clean_data[str(k)] = str(v)
    clean_data.setdefault("type", notif_type)
    clean_data.setdefault("title", title)
    clean_data.setdefault("body", body)
    if notif_id:
        clean_data["notif_id"] = notif_id

    requested_route = clean_data.get("target_route", "/")
    click_link = (
        requested_route if requested_route in ALLOWED_NOTIFICATION_ROUTES else "/main"
    )
    clean_data["target_route"] = click_link

    return messaging.Message(
        token=fcm_token,
        notification=messaging.Notification(title=title, body=body),
        data=clean_data,
        android=messaging.AndroidConfig(
            priority="high",
            ttl=FCM_TTL_SECONDS,
            notification=messaging.AndroidNotification(
                channel_id=channel_for_type(notif_type),
                sound="default",
                click_action="FLUTTER_NOTIFICATION_CLICK",
                icon=ANDROID_NOTIFICATION_ICON,
                color="#1B4332",
                tag=notif_id,
                default_vibrate_timings=True,
                priority="max",
                visibility="private",
            ),
        ),
        webpush=messaging.WebpushConfig(
            headers={"Urgency": "high"},
            notification=messaging.WebpushNotification(
                title=title,
                body=body,
                icon="/icons/Icon-192.png",
                badge="/favicon.png",
            ),
            fcm_options=messaging.WebpushFCMOptions(link=click_link),
        ),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(title=title, body=body),
                    sound="default",
                    badge=1,
                )
            ),
        ),
    )


def _dispatch_fcm_push(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    notif_type: str = "system",
    notif_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Synchronously sends one FCM push. Returns a result dict:
      {"ok": True, "message_id": ...} or {"ok": False, "error": ..., "token_invalid": bool}
    Run via asyncio.to_thread from async code so the event loop is never blocked.
    """
    try:
        from app.services.firebase_auth_service import FirebaseAuthService
        app = FirebaseAuthService.get_app()
        if not app or not FirebaseAuthService._has_credentials:
            _log("[FCM PUSH FAILED] Firebase Admin credentials unavailable; outside-app push skipped.")
            return {"ok": False, "error": "firebase_credentials_unavailable", "token_invalid": False}

        from firebase_admin import messaging

        msg = build_fcm_message(fcm_token, title, body, data, notif_type, notif_id)
        message_id = messaging.send(msg, app=app)
        _log(f"[FCM PUSH SENT] type={notif_type} token=...{fcm_token[-8:]} title='{title}' id={message_id}")
        return {"ok": True, "message_id": message_id}
    except Exception as e:
        token_invalid = False
        try:
            from firebase_admin import messaging
            token_invalid = isinstance(e, (messaging.UnregisteredError, messaging.SenderIdMismatchError))
        except Exception:
            pass
        _log(f"[FCM PUSH FAILED] type={notif_type} token=...{fcm_token[-8:]} {type(e).__name__}: {e}")
        return {"ok": False, "error": f"{type(e).__name__}: {e}", "token_invalid": token_invalid}


async def _purge_invalid_token(user_key: str, token: str) -> None:
    cached = USER_FCM_TOKENS.get(user_key, set())
    if isinstance(cached, str):
        cached = {cached}
        USER_FCM_TOKENS[user_key] = cached
    cached.discard(token)
    if not cached:
        USER_FCM_TOKENS.pop(user_key, None)
    try:
        async with async_session_factory() as session:
            await session.execute(
                update(DeviceFcmToken)
                .where(DeviceFcmToken.user_id == UUID(user_key), DeviceFcmToken.token == token)
                .values(active=False)
            )
            await session.execute(
                update(User).where(User.id == UUID(user_key), User.fcm_token == token).values(fcm_token=None)
            )
            await session.commit()
        _log(f"[FCM TOKEN PURGED] user={user_key} stale token removed")
    except Exception as e:
        _log(f"[FCM TOKEN PURGE NOTICE] user={user_key} {e}")


async def _resolve_fcm_tokens(user_key: str) -> List[str]:
    cached = USER_FCM_TOKENS.get(user_key, set())
    tokens = {cached} if isinstance(cached, str) else set(cached)
    if tokens:
        return list(tokens)
    try:
        from app.core.security import resolve_auth_uuid
        target_uuid = resolve_auth_uuid(user_key)
        async with async_session_factory() as session:
            # 1. Direct match on DeviceFcmToken by user_id
            res = await session.execute(
                select(DeviceFcmToken.token).where(
                    DeviceFcmToken.user_id == target_uuid,
                    DeviceFcmToken.active.is_(True),
                )
            )
            tokens.update(res.scalars().all())

            # 2. Match on User primary key (id == target_uuid)
            legacy = await session.execute(
                select(User.fcm_token).where(User.id == target_uuid)
            )
            legacy_token = legacy.scalar_one_or_none()
            if legacy_token:
                tokens.add(legacy_token)

            # 3. Match on User auth_id (auth_id == target_uuid)
            if not tokens:
                user_res = await session.execute(
                    select(User.id, User.fcm_token).where(User.auth_id == target_uuid)
                )
                user_match = user_res.first()
                if user_match:
                    matched_user_id, matched_fcm_token = user_match
                    if matched_fcm_token:
                        tokens.add(matched_fcm_token)
                    dev_res = await session.execute(
                        select(DeviceFcmToken.token).where(
                            DeviceFcmToken.user_id == matched_user_id,
                            DeviceFcmToken.active.is_(True),
                        )
                    )
                    tokens.update(dev_res.scalars().all())

            USER_FCM_TOKENS[user_key] = tokens
            return list(tokens)
    except Exception as e:
        _log(f"[FCM DB CHECK ERROR] user={user_key} {e}")
        return list(tokens)


async def _deliver(user_key: str, entry: Dict[str, Any]) -> None:
    """Runs on the main event loop: WebSocket (UI sync) + FCM (system notification)."""
    try:
        await manager.send_direct_message(user_key, {
            "type": "sanctuary_notification",
            "notification": entry,
        })
    except Exception:
        pass

    tokens = await _resolve_fcm_tokens(user_key)
    if not tokens:
        _log(f"[FCM NO TOKEN] user={user_key} type={entry['type']} (device not registered)")
        return

    for token in tokens:
        result = await asyncio.to_thread(
            _dispatch_fcm_push,
            token,
            entry["title"],
            entry["body"],
            entry.get("data") or {},
            entry["type"],
            entry["id"],
        )
        if not result.get("ok") and result.get("token_invalid"):
            await _purge_invalid_token(user_key, token)


def push_notification(
    user_id: str,
    notif_type: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> None:
    """
    Enqueues in-app notification, then delivers it in real time via WebSocket (UI sync)
    and FCM (OS-level push that arrives even when the app is closed).
    Safe to call from async handlers, background tasks, and worker threads.
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
    _log(f"[NOTIFICATION ENQUEUED] user={user_key} type={notif_type} title='{title}'")

    try:
        running = asyncio.get_running_loop()
    except RuntimeError:
        running = None

    if running is not None and running.is_running():
        task = running.create_task(_deliver(user_key, entry))
        _BG_TASKS.add(task)
        task.add_done_callback(_BG_TASKS.discard)
        return

    # Called from a worker thread: hand off to the main loop (DB pool is bound to it)
    if _MAIN_LOOP is not None and _MAIN_LOOP.is_running():
        asyncio.run_coroutine_threadsafe(_deliver(user_key, entry), _MAIN_LOOP)
        return

    # No server loop (scripts/tests): only a RAM-cached token can be used safely
    cached = USER_FCM_TOKENS.get(user_key, set())
    tokens = {cached} if isinstance(cached, str) else cached
    if tokens:
        for token in tokens:
            _dispatch_fcm_push(token, title, body, data, notif_type, entry["id"])
    else:
        _log(f"[FCM NO LOOP] user={user_key} type={notif_type} queued in-app only")


class RegisterTokenRequest(BaseModel):
    fcm_token: str
    platform: str = "unknown"
    installation_id: Optional[str] = None


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

    platform = payload.platform.strip().lower()[:20] or "unknown"
    installation_id = payload.installation_id.strip()[:128] if payload.installation_id else None

    # A token can only belong to one account; remove stale ownership atomically.
    for uid, tok in list(USER_FCM_TOKENS.items()):
        if isinstance(tok, set):
            if token_val in tok and uid != str(current_user.id):
                tok.discard(token_val)
                if not tok:
                    USER_FCM_TOKENS.pop(uid, None)
        elif tok == token_val and uid != str(current_user.id):
            USER_FCM_TOKENS.pop(uid, None)

    await db.execute(
        update(DeviceFcmToken)
        .where(DeviceFcmToken.token == token_val, DeviceFcmToken.user_id != current_user.id)
        .values(active=False)
    )

    existing = await db.execute(
        select(DeviceFcmToken).where(DeviceFcmToken.user_id == current_user.id,
                                      DeviceFcmToken.token == token_val)
    )
    device = existing.scalar_one_or_none()
    if inspect.isawaitable(device):
        device = await device
    if device:
        device.active = True
        device.platform = platform
        device.installation_id = installation_id
        device.last_seen_at = datetime.utcnow()
    else:
        db.add(DeviceFcmToken(
            user_id=current_user.id,
            token=token_val,
            platform=platform,
            installation_id=installation_id,
        ))
    current_user.fcm_token = token_val
    USER_FCM_TOKENS.setdefault(str(current_user.id), set()).add(token_val)
    await db.commit()
    logger.info("Registered FCM token for user %s: ...%s", current_user.id, token_val[-8:])

    return {"status": "success", "message": "FCM device token registered successfully."}


@router.post("/unregister-token", status_code=status.HTTP_200_OK, summary="Unregister FCM Push Token")
async def unregister_device_token(
    payload: Optional[RegisterTokenRequest] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Disassociates the FCM push token when user logs out."""
    user_key = str(current_user.id)
    token_val = payload.fcm_token.strip() if payload and payload.fcm_token else None
    if token_val:
        cached = USER_FCM_TOKENS.get(user_key, set())
        if isinstance(cached, str):
            cached = {cached}
            USER_FCM_TOKENS[user_key] = cached
        cached.discard(token_val)
        if not cached:
            USER_FCM_TOKENS.pop(user_key, None)
        await db.execute(
            update(DeviceFcmToken)
            .where(DeviceFcmToken.user_id == current_user.id, DeviceFcmToken.token == token_val)
            .values(active=False)
        )
    else:
        USER_FCM_TOKENS.pop(user_key, None)
        await db.execute(
            update(DeviceFcmToken)
            .where(DeviceFcmToken.user_id == current_user.id)
            .values(active=False)
        )
    if not token_val or token_val == current_user.fcm_token:
        current_user.fcm_token = None
    await db.commit()
    logger.info("Unregistered FCM token for user %s", current_user.id)
    return {"status": "success", "message": "FCM device token unregistered successfully."}


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


def probe_fcm_authorization() -> Dict[str, Any]:
    """
    Dry-run FCM send (nothing is delivered). Proves the service account is allowed
    to send pushes (cloudmessaging.messages.create) for this Firebase project.
    """
    try:
        from app.services.firebase_auth_service import FirebaseAuthService
        app = FirebaseAuthService.get_app()
        if not app or not FirebaseAuthService._has_credentials:
            return {"firebase_credentials": False, "fcm_authorized": False, "error": "firebase_credentials_unavailable"}
        from firebase_admin import messaging
        probe = messaging.Message(
            topic="urheart_push_health_probe",
            notification=messaging.Notification(title="probe", body="probe"),
        )
        messaging.send(probe, dry_run=True, app=app)
        return {"firebase_credentials": True, "fcm_authorized": True, "error": None}
    except Exception as e:
        return {
            "firebase_credentials": FirebaseAuthService._has_credentials,
            "fcm_authorized": False,
            "error": f"{type(e).__name__}: {e}",
        }


@router.get("/push-health", status_code=status.HTTP_200_OK, summary="Background Push Delivery Health")
async def push_health(current_user: User = Depends(get_current_user)):
    """Reports whether outside-the-app pushes can reach the calling user's device."""
    probe = await asyncio.to_thread(probe_fcm_authorization)
    tokens = await _resolve_fcm_tokens(str(current_user.id))
    return {
        "status": "success",
        **probe,
        "token_registered": bool(tokens),
        "token_count": len(tokens),
        "token_suffix": tokens[0][-8:] if tokens else None,
    }


@router.post("/test-push", status_code=status.HTTP_200_OK, summary="Send Test Push To My Device")
async def send_test_push(current_user: User = Depends(get_current_user)):
    """Sends a real FCM push to the caller's own registered device and returns the raw result."""
    user_key = str(current_user.id)
    tokens = await _resolve_fcm_tokens(user_key)
    if not tokens:
        raise HTTPException(status_code=404, detail="No FCM device token registered for this account.")
    token = tokens[0]
    import uuid as _uuid
    notif_id = f"test_{_uuid.uuid4().hex[:10]}"
    result = await asyncio.to_thread(
        _dispatch_fcm_push,
        token,
        "UR-Heart Test Notification 🔔",
        "Background push delivery is working on this device.",
        {"target_route": "/main"},
        "system_test",
        notif_id,
    )
    if not result.get("ok") and result.get("token_invalid"):
        await _purge_invalid_token(user_key, token)
    return {"status": "success" if result.get("ok") else "failed", **result}
