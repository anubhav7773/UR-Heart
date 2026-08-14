import json
import logging
import os
from typing import Optional, Dict, Any
from app.core.config import settings

logger = logging.getLogger(__name__)

_firebase_app_initialized = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging

    if not firebase_admin._apps:
        service_account_env = (
            os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
            or os.getenv("FIREBASE_CREDENTIALS_JSON")
            or os.getenv("FIREBASE_CREDENTIALS")
            or getattr(settings, "FIREBASE_SERVICE_ACCOUNT_JSON", None)
            or getattr(settings, "FIREBASE_CREDENTIALS_JSON", None)
            or getattr(settings, "FIREBASE_CREDENTIALS", None)
        )
        if service_account_env:
            try:
                cert_dict = json.loads(service_account_env)
                cred = credentials.Certificate(cert_dict)
                firebase_admin.initialize_app(cred)
                _firebase_app_initialized = True
                print("[FCM_INIT] Firebase initialized successfully with Service Account JSON.")
            except Exception as e:
                print(f"[FCM_INIT_ERROR] Failed initializing with Service Account JSON: {e}")
                try:
                    project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "ur-heart")
                    firebase_admin.initialize_app(options={"projectId": project_id})
                    _firebase_app_initialized = True
                except Exception as fallback_err:
                    print(f"[FCM_INIT_ERROR] Fallback initialization notice: {fallback_err}")
                    _firebase_app_initialized = False
        else:
            try:
                project_id = os.getenv("GOOGLE_CLOUD_PROJECT") or getattr(settings, "FIREBASE_PROJECT_ID", "ur-heart") or "ur-heart"
                firebase_admin.initialize_app(options={"projectId": project_id})
                _firebase_app_initialized = True
                print(f"[FCM_INIT] Initialized with fallback projectId: {project_id}")
            except Exception as init_err:
                print(f"[FCM_INIT_ERROR] Initialization notice: {init_err}")
                _firebase_app_initialized = False
    else:
        _firebase_app_initialized = True
except (ImportError, ModuleNotFoundError):
    print("firebase_admin package not installed. Notification engine running in mock mode.")
    messaging = None


async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> Optional[str]:
    """
    Sends a Firebase Cloud Messaging push notification with high priority.
    """
    if not fcm_token or not str(fcm_token).strip():
        print("[FCM] Skipped: No fcm_token for recipient")
        return None

    msg_data = {str(k): str(v) for k, v in (data or {}).items()}

    if not _firebase_app_initialized or messaging is None:
        print(f"[MOCK FCM PUSH] Token: {fcm_token[:12]}... | Title: '{title}' | Body: '{body}' | Data: {msg_data}")
        return "mock-notification-id"

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=msg_data,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="high_importance_channel",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            ),
        )
        response = messaging.send(message)
        print(f"[FCM SUCCESS] Sent notification ID: {response}")
        return response
    except Exception as err:
        print(f"[FCM ERROR] Failed sending notification: {err}")
        return None


async def send_match_notification(
    target_fcm_token: str,
    matched_user_name: str,
    match_id: str
) -> Optional[str]:
    """
    Convenience helper for match notifications.
    """
    return await send_push_notification(
        fcm_token=target_fcm_token,
        title="It's a Match! \U0001F389",
        body=f"You and {matched_user_name} liked each other!",
        data={
            "type": "match",
            "match_id": str(match_id),
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
    )


async def send_chat_notification(
    target_fcm_token: str,
    sender_name: str,
    message_preview: str,
    match_id: str
) -> Optional[str]:
    """
    Convenience helper for chat message notifications.
    """
    return await send_push_notification(
        fcm_token=target_fcm_token,
        title=sender_name,
        body=message_preview or "Sent you a message",
        data={
            "type": "chat",
            "match_id": str(match_id),
            "conversation_id": str(match_id),
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
    )
