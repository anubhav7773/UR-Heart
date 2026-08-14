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
        # 1. Try environment variable FIREBASE_CREDENTIALS_JSON, FIREBASE_SERVICE_ACCOUNT_JSON, or FIREBASE_CREDENTIALS
        service_account_raw = (
            os.getenv("FIREBASE_CREDENTIALS_JSON")
            or os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
            or os.getenv("FIREBASE_CREDENTIALS")
        )
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "ur-heart")

        if service_account_raw:
            try:
                cert_dict = json.loads(service_account_raw)
                cred = credentials.Certificate(cert_dict)
                firebase_admin.initialize_app(cred)
                print("[FIREBASE_INIT] Successfully initialized with Service Account Credentials!")
                return
            except Exception as e:
                print(f"[FIREBASE_INIT] Failed to load JSON creds: {e}")
                try:
                    firebase_admin.initialize_app(options={"projectId": project_id})
                    return
                except Exception:
                    pass

        # 2. Try serviceAccountKey.json file in backend root
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        service_account_path = os.path.join(base_dir, "serviceAccountKey.json")

        if os.path.exists(service_account_path):
            try:
                cred = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(cred)
                print(f"[FIREBASE_INIT] Initialized with credentials from {service_account_path}")
                return
            except Exception as e:
                logger.error(f"[Firebase] Error initializing Certificate: {e}")

        # 3. Fallback project options
        try:
            firebase_admin.initialize_app(options={"projectId": project_id})
            print(f"[FIREBASE_INIT] Initialized with fallback options: {project_id}")
        except Exception:
            pass

initialize_firebase()

