import os
import json
import logging
import firebase_admin
from firebase_admin import credentials, auth as fb_auth

logger = logging.getLogger(__name__)

def initialize_firebase():
    """Initializes Firebase Admin SDK with env var, serviceAccountKey.json or fallback project options."""
    if not firebase_admin._apps:
        # 1. Try environment variable FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_CREDENTIALS
        env_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON") or os.environ.get("FIREBASE_CREDENTIALS")
        if env_json:
            try:
                cred_dict = json.loads(env_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                logger.info("[Firebase] Initialized Admin SDK from environment variable credentials.")
                return
            except Exception as e:
                logger.error(f"[Firebase] Error parsing environment JSON credentials: {e}")

        # 2. Try serviceAccountKey.json file in backend root
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        service_account_path = os.path.join(base_dir, "serviceAccountKey.json")

        if os.path.exists(service_account_path):
            try:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
                logger.info(f"[Firebase] Initialized Admin SDK with credentials from {service_account_path}")
                return
            except Exception as e:
                logger.error(f"[Firebase] Error initializing Certificate: {e}")

        # 3. Fallback project options
        logger.warning("[Firebase] serviceAccountKey.json or env var not found; initializing with fallback options.")
        try:
            firebase_admin.initialize_app(options={'projectId': 'ur-heart'})
        except Exception:
            pass

initialize_firebase()

