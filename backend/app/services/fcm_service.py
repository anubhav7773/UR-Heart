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

    def initialize_firebase():
        global _firebase_app_initialized
        if not firebase_admin._apps:
            raw_json = (
                os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
                or os.getenv("FIREBASE_CREDENTIALS_JSON")
                or os.getenv("FIREBASE_CREDENTIALS")
                or getattr(settings, "FIREBASE_SERVICE_ACCOUNT_JSON", None)
                or getattr(settings, "FIREBASE_CREDENTIALS_JSON", None)
                or getattr(settings, "FIREBASE_CREDENTIALS", None)
            )

            if raw_json:
                try:
                    cert_info = json.loads(raw_json) if isinstance(raw_json, str) else raw_json
                    cred = credentials.Certificate(cert_info)
                    firebase_admin.initialize_app(cred)
                    _firebase_app_initialized = True
                    print("[FCM_INIT] Successfully initialized Firebase with Service Account JSON.")
                    return
                except Exception as e:
                    print(f"[FCM_INIT_ERROR] Failed parsing credentials JSON: {e}")

            # Fallback if no credentials found
            try:
                project_id = os.getenv("GOOGLE_CLOUD_PROJECT") or getattr(settings, "FIREBASE_PROJECT_ID", "ur-heart") or "ur-heart"
                firebase_admin.initialize_app(options={"projectId": project_id})
                _firebase_app_initialized = True
                print(f"[FCM_INIT] Initialized Firebase with fallback project_id: {project_id}")
            except Exception as e:
                print(f"[FCM_INIT_ERROR] Fallback initialization notice: {e}")
                _firebase_app_initialized = False
        else:
            _firebase_app_initialized = True

    initialize_firebase()
except (ImportError, ModuleNotFoundError):
    print("firebase_admin package not installed. Notification engine running in mock mode.")
    messaging = None


async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    Safely dispatches high-priority Android/FCM push notifications.
    Logs explicit status for recipient token, successful delivery IDs, or error tracebacks.
    """
    if not fcm_token or not str(fcm_token).strip():
        print("[FCM] Skipped: No fcm_token for recipient")
        return False

    msg_data = {str(k): str(v) for k, v in (data or {}).items() if v is not None}

    if not _firebase_app_initialized or messaging is None:
        print(f"[MOCK FCM PUSH] Token: {fcm_token[:12]}... | Title: '{title}' | Body: '{body}' | Data: {msg_data}")
        return True

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=msg_data,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='high_importance_channel',
                    sound='default',
                ),
            ),
        )
        response = messaging.send(message)
        print(f"[FCM SUCCESS] Sent notification ID: {response}")
        return True
    except Exception as err:
        print(f"[FCM ERROR] Failed sending notification: {err}")
        return False


async def send_match_notification(
    target_fcm_token: str,
    matched_user_name: str,
    match_id: str = ""
) -> bool:
    """
    Triggers an instant push notification when a mutual match occurs ("It's a Match! 🎉").
    """
    return await send_push_notification(
        fcm_token=target_fcm_token,
        title="It's a Match! 🎉",
        body=f"You and {matched_user_name} liked each other!",
        data={
            "type": "match",
            "match_id": match_id,
            "matched_user_name": matched_user_name,
        }
    )


async def send_chat_notification(
    target_fcm_token: str,
    sender_name: str,
    message_text: str,
    sender_id: str = "",
    match_id: str = ""
) -> bool:
    """
    Triggers an instant push notification when a direct chat message is received.
    """
    preview = message_text if len(message_text) <= 60 else f"{message_text[:57]}..."
    return await send_push_notification(
        fcm_token=target_fcm_token,
        title=sender_name,
        body=preview or "Sent you a message.",
        data={
            "type": "chat",
            "sender_id": sender_id,
            "match_id": match_id,
            "conversation_id": match_id,
        }
    )
