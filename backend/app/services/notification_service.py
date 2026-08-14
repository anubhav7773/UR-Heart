import json
import logging
from typing import Optional, Dict, Any
from app.core.config import settings

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import credentials, messaging

    def get_firebase_app():
        if not firebase_admin._apps:
            # Check if JSON string is provided in settings
            raw_creds = getattr(settings, "FIREBASE_SERVICE_ACCOUNT_JSON", None)
            if raw_creds:
                try:
                    # Handle both string and already parsed dict
                    if isinstance(raw_creds, str):
                        raw_creds = raw_creds.strip("'\"")
                        cred_dict = json.loads(raw_creds)
                    else:
                        cred_dict = raw_creds
                    
                    cred = credentials.Certificate(cred_dict)
                    return firebase_admin.initialize_app(cred)
                except Exception as e:
                    print(f"[Firebase Init Error] Failed loading credentials from JSON: {e}")
            
            # Fallback to default credentials
            try:
                return firebase_admin.initialize_app()
            except Exception as e:
                print(f"[Firebase Init Error] Fallback failed: {e}")
        return firebase_admin.get_app()

    # Initialize on module load
    try:
        get_firebase_app()
    except Exception:
        pass
except (ImportError, ModuleNotFoundError):
    print("firebase_admin package not installed. Notification engine running in mock mode.")
    messaging = None
    get_firebase_app = lambda: None


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

    try:
        app = get_firebase_app()
    except Exception:
        app = None

    if app is None or messaging is None:
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
        response = messaging.send(message, app=app)
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
