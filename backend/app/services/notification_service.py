import firebase_admin
from firebase_admin import messaging

async def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=data or {},
            token=fcm_token
        )
        messaging.send(message)
    except Exception as e:
        print(f"FCM Notification dispatch error: {e}")
