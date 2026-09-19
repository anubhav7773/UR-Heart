import firebase_admin
from firebase_admin import messaging
from typing import Optional, Dict

async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None
) -> bool:
    """
    Dispatches a high-priority FCM notification to Android & iOS.
    Forces heads-up popdown banner even if device is battery-optimized or asleep.
    """
    if not fcm_token or fcm_token.strip() == "":
        return False

    # Stringify all data payload values to avoid serialization issues
    sanitized_data = {str(k): str(v) for k, v in (data or {}).items()}

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=sanitized_data,
            token=fcm_token.strip(),
            android=messaging.AndroidConfig(
                priority="high",
                ttl=86400,  # 24 hours
                notification=messaging.AndroidNotification(
                    channel_id="ur_heart_high_importance",
                    priority="max",
                    default_sound=True,
                    default_vibrate_timings=True,
                    click_action="FLUTTER_NOTIFICATION_CLICK"
                ),
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        badge=1,
                        sound="default",
                        content_available=True,
                    )
                ),
            ),
        )

        response = messaging.send(message)
        return True
    except messaging.UnregisteredError:
        # Token is invalid or uninstalled
        return False
    except Exception as e:
        print(f"⚠️ [FCM Dispatch Error] failed to send notification: {e}")
        return False
