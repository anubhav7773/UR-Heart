import os
import logging
from typing import Optional, Tuple, Dict, Any
import firebase_admin
from firebase_admin import credentials, auth
from app.core.config import get_settings

logger = logging.getLogger(__name__)

class FirebaseAuthService:
    """
    100% Production-Grade Firebase Authentication Service.
    Directly connects to Firebase Console (Project: ur-heart-44b46)
    using serviceAccountKey.json to manage, verify, and authenticate users.
    """

    @classmethod
    def get_app(cls) -> firebase_admin.App:
        if not firebase_admin._apps:
            settings = get_settings()
            cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
            if not os.path.exists(cred_path):
                # Search in backend root
                backend_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
                alt_path = os.path.join(backend_root, "serviceAccountKey.json")
                if os.path.exists(alt_path):
                    cred_path = alt_path

            if os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                return firebase_admin.initialize_app(cred, {
                    "projectId": getattr(settings, "FIREBASE_PROJECT_ID", "ur-heart-44b46"),
                    "storageBucket": getattr(settings, "FIREBASE_STORAGE_BUCKET", "ur-heart-44b46.firebasestorage.app"),
                })
            else:
                return firebase_admin.initialize_app()
        return firebase_admin.get_app()

    @classmethod
    def generate_firebase_email_link(cls, email: str) -> Optional[str]:
        """
        Generates genuine Firebase Authentication Passwordless Email Sign-In Link.
        Visible and validated directly against Firebase Console.
        """
        cls.get_app()
        clean_email = email.strip().lower()
        settings = get_settings()
        project_id = getattr(settings, "FIREBASE_PROJECT_ID", "ur-heart-44b46")

        try:
            action_code_settings = auth.ActionCodeSettings(
                url=f"https://{project_id}.firebaseapp.com",
                handle_code_in_app=True,
                android_package_name="com.urheart.app",
                android_install_app=True,
                android_minimum_version="21",
            )
            link = auth.generate_sign_in_with_email_link(clean_email, action_code_settings)
            logger.info("Generated Firebase email sign-in link for %s", clean_email)
            return link
        except Exception as e:
            logger.error("Failed to generate Firebase email sign-in link: %s", e)
            return None

    @classmethod
    def verify_or_create_firebase_user(cls, email: str) -> Tuple[auth.UserRecord, str]:
        """
        Finds or creates the user in Firebase Auth Console,
        marks email_verified=True, and generates a Firebase Custom Token
        for atomic mobile client authentication.
        """
        cls.get_app()
        clean_email = email.strip().lower()

        try:
            user_record = auth.get_user_by_email(clean_email)
            if not user_record.email_verified:
                user_record = auth.update_user(user_record.uid, email_verified=True)
            logger.info("Found existing user in Firebase Console: %s (verified)", user_record.uid)
        except auth.UserNotFoundError:
            user_record = auth.create_user(
                email=clean_email,
                email_verified=True,
                display_name="Sanctuary Seeker"
            )
            logger.info("Created new verified user in Firebase Console: %s", user_record.uid)

        # Generate Firebase Custom Auth Token for client login
        custom_token_bytes = auth.create_custom_token(user_record.uid)
        custom_token = custom_token_bytes.decode("utf-8") if isinstance(custom_token_bytes, bytes) else str(custom_token_bytes)
        return user_record, custom_token
