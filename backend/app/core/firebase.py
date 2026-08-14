import json
import logging
from typing import Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import credentials, auth as fb_auth, messaging

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

    def initialize_firebase():
        """Alias for backwards compatibility."""
        return get_firebase_app()

    # Initialize on module load
    try:
        get_firebase_app()
    except Exception as e:
        logger.warning(f"[Firebase Init Notice] {e}")

except (ImportError, ModuleNotFoundError):
    logger.warning("[Firebase] firebase_admin package not installed. Skipping initialization.")
    firebase_admin = None
    fb_auth = None
    messaging = None
    
    def get_firebase_app():
        return None

    def initialize_firebase():
        return None
