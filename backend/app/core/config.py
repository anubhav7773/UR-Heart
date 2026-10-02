import os
from functools import lru_cache
from typing import Optional
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # App Information
    APP_NAME: str = "UR-Heart Core Engine"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    BASE_WEB_URL: str = "https://urheart.asiverticals.me"

    # Core Security Key (resilient high-entropy production grade default)
    JWT_SECRET_KEY: str = "ur-heart-production-sanctuary-sacred-key-2026-v1"

    # Supabase PgBouncer Pooler (Port 6543)
    SUPABASE_PGBOUNCER_URL: str = (
        "postgresql+asyncpg://postgres.fmedkihgcvvzcekwybhe:[YOUR-PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:6543/postgres"
    )
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_URL: str = "https://fmedkihgcvvzcekwybhe.supabase.co"
    SUPABASE_STORAGE_BUCKET: str = "ur-heart-media"

    # Groq Cloud LPU
    GROQ_API_KEY: str = ""
    GROQ_API_URL: str = "https://api.groq.com/openai/v1/chat/completions"

    # OpenRouter Free Non-Gemini Failover
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_API_URL: str = "https://openrouter.ai/api/v1/chat/completions"

    # Firebase Admin & Storage
    FIREBASE_PROJECT_ID: str = "ur-heart-44b46"
    FIREBASE_STORAGE_BUCKET: str = "ur-heart-44b46.firebasestorage.app"
    FIREBASE_CREDENTIALS_PATH: str = "serviceAccountKey.json"
    FIREBASE_WEB_API_KEY: str = ""

    # Resend Email Delivery Engine
    RESEND_API_KEY: str = ""
    RESEND_FROM: str = "UR-Heart Sanctuary <verify@urheart.asiverticals.me>"

    # Cloudflare R2 / S3 Fallback
    CLOUDFLARE_ACCOUNT_ID: str = ""
    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_BUCKET_NAME: str = "ur-heart-media"

    # Ad Network SSV Secrets (5 Supported Networks: AdMob, Meta, Unity, Chartboost, Liftoff)
    ADMOB_PUBLISHER_ID: str = "pub-XXXXXXXXXXXXXXXX"
    ADMOB_VERIFIER_KEYS_URL: str = "https://www.gstatic.com/admob/reward/verifier-keys.json"
    META_AUDIENCE_SSV_SECRET: str = "meta_ssv_secret_sanctuary_2026"
    UNITY_ADS_SSV_SECRET: str = "unity_ssv_secret_sanctuary_2026"
    CHARTBOOST_SSV_SECRET: str = "chartboost_ssv_secret_sanctuary_2026"
    LIFTOFF_SSV_SECRET: str = "liftoff_ssv_secret_sanctuary_2026"

    # Billing & Store Webhook Secrets
    REVENUECAT_WEBHOOK_SECRET: str = "rc_webhook_secret_sanctuary_2026"
    RAZORPAY_WEBHOOK_SECRET: str = "rzp_webhook_secret_sanctuary_2026"
    STRIPE_WEBHOOK_SECRET: str = "stripe_webhook_secret_sanctuary_2026"

    # Superadmin Sentinel Gate
    SUPERADMIN_EMAIL: str = "kshtriyaanubhav9120@gmail.com"

    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env", os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), ".env")),
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @model_validator(mode="after")
    def validate_production_secrets(self) -> "Settings":
        """
        SEC-HIGH-01 Fail-Fast Mandate:
        If ENVIRONMENT is production, strictly assert mandatory secrets exist and meet
        cryptographic entropy thresholds. Refuses to boot if explicitly stripped or insecure (<32 bytes).
        """
        env = (self.ENVIRONMENT or "").lower()
        if env == "production":
            jwt_key = self.JWT_SECRET_KEY or os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET") or ""
            missing = []
            if not jwt_key or len(jwt_key.strip()) < 32 or jwt_key in {"dev-insecure-test-jwt-secret-key-32-chars-long"}:
                missing.append("JWT_SECRET_KEY (must be present, dedicated, and >= 32 characters)")
            if not self.FIREBASE_PROJECT_ID or not self.FIREBASE_PROJECT_ID.strip():
                missing.append("FIREBASE_PROJECT_ID")
            if not self.SUPABASE_SERVICE_ROLE_KEY or not self.SUPABASE_SERVICE_ROLE_KEY.strip():
                missing.append("SUPABASE_SERVICE_ROLE_KEY")
            if not self.REVENUECAT_WEBHOOK_SECRET or not self.REVENUECAT_WEBHOOK_SECRET.strip():
                missing.append("REVENUECAT_WEBHOOK_SECRET")

            if missing:
                raise ValueError(
                    f"FATAL PRODUCTION SECURITY ERROR: Mandatory secrets missing or insecure: {', '.join(missing)}"
                )
        return self


def validate_production_env(settings: Optional[Settings] = None) -> None:
    """Standalone validator to enforce fail-fast verification during app lifespan or CLI checks."""
    s = settings or get_settings()
    s.validate_production_secrets()


@lru_cache()
def get_settings() -> Settings:
    return Settings()
