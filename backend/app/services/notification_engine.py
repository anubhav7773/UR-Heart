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
    logger.warning("firebase_admin package not installed. Notification engine will run in mock mode.")
    messaging = None
    get_firebase_app = lambda: None


class NotificationEngineService:
    @staticmethod
    def send_push_notification(
        target_fcm_token: str,
        title: str,
        body: str,
        data_payload: Optional[Dict[str, str]] = None
    ) -> bool:
        """
        Sends an instant Firebase Cloud Messaging (FCM) push notification payload to a target user device.
        """
        if not target_fcm_token:
            logger.info("No FCM token available for target user. Skipping push notification.")
            return False

        try:
            app = get_firebase_app()
        except Exception:
            app = None

        if app is None or messaging is None:
            logger.info(f"[MOCK FCM NOTIFICATION] To: {target_fcm_token[:10]}... | Title: '{title}' | Body: '{body}'")
            return True

        try:
            msg = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data_payload or {},
                token=target_fcm_token,
            )
            response = messaging.send(msg, app=app)
            logger.info(f"FCM Push Notification sent successfully. Message ID: {response}")
            return True
        except Exception as e:
            logger.error(f"Failed to send FCM push notification: {e}")
            return False

    @classmethod
    def send_match_notification(cls, target_fcm_token: str, matched_user_name: str) -> bool:
        """
        Triggers push notification when a mutual match occurs ("You matched with X! 💖").
        """
        return cls.send_push_notification(
            target_fcm_token=target_fcm_token,
            title="It's a Match! 💖",
            body=f"You and {matched_user_name} liked each other! Tap to start chatting.",
            data_payload={"type": "match", "matched_name": matched_user_name}
        )

    @classmethod
    def send_chat_message_notification(
        cls, target_fcm_token: str, sender_name: str, message_preview: str
    ) -> bool:
        """
        Triggers push notification when a new direct message is received ("X sent you a message 💬").
        """
        preview = message_preview if len(message_preview) <= 50 else f"{message_preview[:47]}..."
        return cls.send_push_notification(
            target_fcm_token=target_fcm_token,
            title=f"Message from {sender_name} 💬",
            body=preview or "Sent you a message.",
            data_payload={"type": "chat_message", "sender_name": sender_name}
        )

    @classmethod
    def send_chai_invite_notification(cls, target_fcm_token: str, sender_name: str) -> bool:
        """
        Triggers push notification when a Chai Invite is received ("X invited you for Chai ☕").
        """
        return cls.send_push_notification(
            target_fcm_token=target_fcm_token,
            title="Chai Invitation! ☕",
            body=f"{sender_name} invited you for a virtual Chai date! Accept to unlock chat.",
            data_payload={"type": "chai_invite", "sender_name": sender_name}
        )
