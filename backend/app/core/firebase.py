import os
import logging
import firebase_admin
from firebase_admin import credentials, auth as fb_auth

logger = logging.getLogger(__name__)

def initialize_firebase():
    """Initializes Firebase Admin SDK with serviceAccountKey.json or fallback project options."""
    if not firebase_admin._apps:
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        service_account_path = os.path.join(base_dir, "serviceAccountKey.json")

        if os.path.exists(service_account_path):
            try:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
                logger.info(f"[Firebase] Initialized Admin SDK with credentials from {service_account_path}")
            except Exception as e:
                logger.error(f"[Firebase] Error initializing Certificate: {e}")
                try:
                    firebase_admin.initialize_app(options={'projectId': 'ur-heart'})
                except Exception:
                    pass
        else:
            logger.warning("[Firebase] serviceAccountKey.json not found; initializing with fallback options.")
            try:
                firebase_admin.initialize_app(options={'projectId': 'ur-heart'})
            except Exception:
                pass

initialize_firebase()
