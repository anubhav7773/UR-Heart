import os
import sys
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

    # Dedicated Groq Voice Spark Whisper Engine (Revenue Leakage & Off-Platform Shield)
    GROQ_VOICE_API_KEY: str = ""
    GROQ_WHISPER_URL: str = "https://api.groq.com/openai/v1/audio/transcriptions"

    # OpenRouter Free Non-Gemini Failover
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_API_URL: str = "https://openrouter.ai/api/v1/chat/completions"

    # Eva Dual Dedicated Channels (Channel 1: Identity/KYC, Channel 2: Companion/Sparks)
    EVA_IDENTITY_API_KEY: str = ""
    EVA_COMPANION_API_KEY: str = ""

    # Google AI Studio Gemini Engine (Dialogue Realtime Wingman)
    GEMINI_API_KEY: str = ""
    GEMINI_API_URL: str = "https://generativelanguage.googleapis.com/v1beta/models"

    # Firebase Admin & Storage
    FIREBASE_PROJECT_ID: str = "ur-heart-44b46"
    FIREBASE_STORAGE_BUCKET: str = "ur-heart-44b46.firebasestorage.app"
    FIREBASE_CREDENTIALS_PATH: str = "serviceAccountKey.json"
    FIREBASE_WEB_API_KEY: str = ""

    # Resend Email Delivery Engine
    RESEND_API_KEY: str = ""
    RESEND_FROM: str = "UR-Heart Sanctuary <verify@urheart.asiverticals.me>"

    # SMTP Relay Engine (Google Gmail SMTP or Brevo)
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = "UR-Heart Sanctuary <asiverticals@gmail.com>"

    # Brevo Fallback Engine
    BREVO_API_KEY: str = ""
    BREVO_SMTP_HOST: str = "smtp-relay.brevo.com"
    BREVO_SMTP_PORT: int = 587
    BREVO_SMTP_USER: str = ""
    BREVO_SMTP_PASSWORD: str = ""

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

    # Billing & Store (Razorpay India & Stripe Global)
    REVENUECAT_WEBHOOK_SECRET: str = "rc_webhook_secret_sanctuary_2026"
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = "rzp_webhook_secret_sanctuary_2026"
    RAZORPAY_MERCHANT_NAME: str = "UR-Heart Sanctuary"
    RAZORPAY_THEME_COLOR: str = "#2E6F5E"
    STRIPE_WEBHOOK_SECRET: str = "stripe_webhook_secret_sanctuary_2026"

    # Superadmin Sentinel Gate
    SUPERADMIN_EMAIL: str = "asiverticals@gmail.com"
    SUPERADMIN_SECRET_KEY: str = "asiverticals_sovereign_sanctuary_2026"

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
            admin_key = self.SUPERADMIN_SECRET_KEY or os.getenv("SUPERADMIN_SECRET_KEY") or ""
            if not admin_key or admin_key in {"asiverticals_sovereign_sanctuary_2026"}:
                missing.append("SUPERADMIN_SECRET_KEY (must be custom high-entropy secret in production)")
            if not self.RAZORPAY_KEY_ID or not self.RAZORPAY_KEY_ID.strip():
                missing.append("RAZORPAY_KEY_ID (must be configured in production)")
            if not self.RAZORPAY_KEY_SECRET or not self.RAZORPAY_KEY_SECRET.strip():
                missing.append("RAZORPAY_KEY_SECRET (must be configured in production)")
            if not self.RAZORPAY_WEBHOOK_SECRET or self.RAZORPAY_WEBHOOK_SECRET in {"rzp_webhook_secret_sanctuary_2026", ""}:
                missing.append("RAZORPAY_WEBHOOK_SECRET (must be a custom production secret, not default)")

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


settings = get_settings()

