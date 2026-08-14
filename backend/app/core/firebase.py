import os
import json
import logging

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import credentials, auth as fb_auth
except (ImportError, ModuleNotFoundError):
    firebase_admin = None
    fb_auth = None

def initialize_firebase():
    """Initializes Firebase Admin SDK with env var, serviceAccountKey.json or fallback project options."""
    if firebase_admin is None:
        logger.warning("[Firebase] firebase_admin package not installed. Skipping initialization.")
        return

    if not firebase_admin._apps:
        service_account_env = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") or os.getenv("FIREBASE_CREDENTIALS_JSON") or os.getenv("FIREBASE_CREDENTIALS")
        if service_account_env:
            try:
                cert_dict = json.loads(service_account_env) if isinstance(service_account_env, str) else service_account_env
                cred = credentials.Certificate(cert_dict)
                firebase_admin.initialize_app(cred)
                print("[FCM_INIT] Firebase initialized successfully with Service Account JSON.")
                return
            except Exception as e:
                print(f"[FCM_INIT_ERROR] JSON parsing failed: {e}")
                try:
                    firebase_admin.initialize_app()
                    return
                except Exception:
                    pass

        # Try serviceAccountKey.json file in backend root
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        service_account_path = os.path.join(base_dir, "serviceAccountKey.json")

        if os.path.exists(service_account_path):
            try:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
                print(f"[FCM_INIT] Firebase initialized successfully with Service Account JSON from {service_account_path}")
                return
            except Exception as e:
                print(f"[FCM_INIT_ERROR] Error initializing Certificate from file: {e}")

        # Fallback if no credentials found
        try:
            project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "ur-heart")
            firebase_admin.initialize_app(options={"projectId": project_id})
        except Exception:
            pass

initialize_firebase()

