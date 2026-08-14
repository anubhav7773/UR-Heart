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
        # Check all possible env variable names
        raw_json = (
            os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
            or os.getenv("FIREBASE_CREDENTIALS_JSON")
            or os.getenv("FIREBASE_CREDENTIALS")
        )
        if raw_json:
            try:
                cert_info = json.loads(raw_json) if isinstance(raw_json, str) else raw_json
                cred = credentials.Certificate(cert_info)
                firebase_admin.initialize_app(cred)
                print("[FCM_INIT] Successfully initialized Firebase with Service Account JSON.")
                return
            except Exception as e:
                print(f"[FCM_INIT_ERROR] Failed parsing credentials JSON: {e}")

        # Try serviceAccountKey.json file in backend root
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        service_account_path = os.path.join(base_dir, "serviceAccountKey.json")

        if os.path.exists(service_account_path):
            try:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
                print(f"[FCM_INIT] Successfully initialized Firebase with credentials from {service_account_path}")
                return
            except Exception as e:
                print(f"[FCM_INIT_ERROR] Error initializing Certificate from file: {e}")

        # Fallback if no credentials found
        try:
            project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "ur-heart")
            firebase_admin.initialize_app(options={"projectId": project_id})
            print(f"[FCM_INIT] Initialized Firebase with fallback project_id: {project_id}")
        except Exception as e:
            print(f"[FCM_INIT_ERROR] Fallback initialization notice: {e}")

initialize_firebase()

