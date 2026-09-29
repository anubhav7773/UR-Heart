from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # App Information
    APP_NAME: str = "UR-Heart Core Engine"
    ENVIRONMENT: str = "production"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    BASE_WEB_URL: str = "https://urheart.asiverticals.me"

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

    # Cloudflare R2 / S3 Fallback
    CLOUDFLARE_ACCOUNT_ID: str = ""
    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_BUCKET_NAME: str = "ur-heart-media"

    # Ad Network SSV Secrets
    APPLOVIN_SDK_KEY: str = "demo_applovin_sdk_key_ur_heart"
    ADMOB_VERIFIER_KEYS_URL: str = "https://www.gstatic.com/admob/reward/verifier-keys.json"
    INMOBI_SSV_SECRET: str = "inmobi_ssv_secret_sanctuary_2026"
    META_AUDIENCE_SSV_SECRET: str = "meta_ssv_secret_sanctuary_2026"
    UNITY_ADS_SSV_SECRET: str = "unity_ssv_secret_sanctuary_2026"
    APPLOVIN_SSV_SECRET: str = "applovin_ssv_secret_sanctuary_2026"

    # Billing & Store Webhook Secrets
    REVENUECAT_WEBHOOK_SECRET: str = "rc_webhook_secret_sanctuary_2026"
    RAZORPAY_WEBHOOK_SECRET: str = "rzp_webhook_secret_sanctuary_2026"
    STRIPE_WEBHOOK_SECRET: str = "stripe_webhook_secret_sanctuary_2026"

    # Superadmin Sentinel Gate
    SUPERADMIN_EMAIL: str = "kshtriyaanubhav9120@gmail.com"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


@lru_cache()
def get_settings() -> Settings:
    return Settings()
