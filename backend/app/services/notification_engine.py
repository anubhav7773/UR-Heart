import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

_firebase_app_initialized = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    if not firebase_admin._apps:
        # Default initialization; if service account JSON is omitted, uses environment default
        try:
            firebase_admin.initialize_app()
            _firebase_app_initialized = True
        except Exception as init_err:
            logger.warning(f"Firebase Admin SDK initialization notice: {init_err}")
    else:
        _firebase_app_initialized = True
except ModuleNotFoundError:
    logger.warning("firebase_admin package not installed. Notification engine will run in mock mode.")


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

        if not _firebase_app_initialized:
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
            response = messaging.send(msg)
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
