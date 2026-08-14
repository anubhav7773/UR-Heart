import json
import logging
from typing import Optional, Dict, Any
from app.core.config import settings

logger = logging.getLogger(__name__)

_firebase_app_initialized = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging

    if not firebase_admin._apps:
        try:
            if settings.FIREBASE_CREDENTIALS_JSON:
                cred_dict = json.loads(settings.FIREBASE_CREDENTIALS_JSON)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                _firebase_app_initialized = True
            elif settings.FIREBASE_PROJECT_ID:
                firebase_admin.initialize_app(options={"projectId": settings.FIREBASE_PROJECT_ID})
                _firebase_app_initialized = True
            else:
                # Default initialization (uses GOOGLE_APPLICATION_CREDENTIALS if available)
                firebase_admin.initialize_app()
                _firebase_app_initialized = True
        except Exception as init_err:
            logger.warning(f"FCM Service initialization notice (running in mock mode): {init_err}")
            _firebase_app_initialized = False
    else:
        _firebase_app_initialized = True
except (ImportError, ModuleNotFoundError):
    logger.warning("firebase_admin package not installed. FCM Service running in mock/fallback mode.")
    messaging = None


async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    Safely dispatches an FCM push notification payload to a target device token.
    Prevents throwing unhandled exceptions or blocking API response pipelines.
    """
    if not fcm_token or not str(fcm_token).strip():
        logger.debug("FCM token is empty or missing. Skipping push notification.")
        return False

    data_payload = {str(k): str(v) for k, v in (data or {}).items() if v is not None}

    if not _firebase_app_initialized or messaging is None:
        logger.info(f"[MOCK FCM PUSH] Token: {fcm_token[:12]}... | Title: '{title}' | Body: '{body}' | Data: {data_payload}")
        return True

    try:
        msg = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data_payload,
            token=fcm_token,
        )
        response = messaging.send(msg)
        logger.info(f"FCM Push Notification sent successfully to {fcm_token[:12]}... Message ID: {response}")
        return True
    except Exception as exc:
        logger.error(f"Failed to send FCM push notification: {exc}")
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
