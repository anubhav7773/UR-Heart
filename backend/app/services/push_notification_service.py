import logging
from typing import Optional, Dict, Any
from uuid import UUID

logger = logging.getLogger(__name__)

class PushNotificationService:
    """
    WhatsApp-Style Push Notification Service.
    Dispatches high-priority Firebase Cloud Messaging (FCM) notifications
    when users exchange chat messages.
    """

    @staticmethod
    async def send_chat_notification(
        recipient_fcm_token: Optional[str],
        sender_name: str,
        message_preview: str,
        match_id: UUID,
        sender_id: UUID,
    ) -> bool:
        """
        Dispatches an instant WhatsApp-style notification to the recipient's device.
        """
        if not recipient_fcm_token:
            logger.info(f"Skipping push notification: Recipient {recipient_fcm_token} has no registered FCM token.")
            return False

        payload_data: Dict[str, str] = {
            "type": "chat_message",
            "match_id": str(match_id),
            "sender_id": str(sender_id),
            "sender_name": sender_name,
        }

        # Truncate preview for lock screen privacy (WhatsApp pattern)
        display_body = message_preview if len(message_preview) <= 120 else f"{message_preview[:117]}..."

        try:
            from firebase_admin import messaging
            message = messaging.Message(
                notification=messaging.Notification(
                    title=sender_name,
                    body=display_body,
                ),
                data=payload_data,
                token=recipient_fcm_token,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="urheart_chat_channel",
                        sound="default",
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                        tag=f"chat_{match_id}",
                    ),
                ),
            )
            response = messaging.send(message)
            logger.info(f"Push notification sent successfully: {response}")
            return True
        except Exception as e:
            # Resilient fallback: log without interrupting real-time chat flow
            logger.info(f"FCM delivery handled (sandbox/offline mode): {e}")
            return False

push_service = PushNotificationService()
