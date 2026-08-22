import logging
from typing import List, Optional
from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    # Server & Core Security
    PROJECT_NAME: str = "Project RuralHeart API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "production"
    DEBUG: bool = False
    SECRET_KEY: str = Field(
        default="ruralheart_super_secret_jwt_key_2026_change_in_prod",
        validation_alias=AliasChoices("SECRET_KEY", "JWT_SECRET"),
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 21600  # 15 days in minutes
    ADMIN_EMAIL: Optional[str] = "kshtriyaanubhav9120@gmail.com"

    # Database & Supabase Integration
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/ruralheart",
        validation_alias=AliasChoices("DATABASE_URL", "SUPABASE_DB_URL", "POSTGRES_URL"),
    )
    SUPABASE_DB_URL: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("SUPABASE_DB_URL", "DATABASE_URL"),
    )
    SUPABASE_URL: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("SUPABASE_URL", "SUPABASE_STORAGE_URL"),
    )
    SUPABASE_STORAGE_URL: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("SUPABASE_STORAGE_URL", "SUPABASE_URL"),
    )
    SUPABASE_KEY: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("SUPABASE_KEY", "SUPABASE_ANON_KEY"),
    )
    SUPABASE_SERVICE_ROLE_KEY: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SERVICE_KEY"),
    )

    # Firebase Authentication & Cloud Messaging (FCM)
    GOOGLE_CLOUD_PROJECT: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("GOOGLE_CLOUD_PROJECT", "FIREBASE_PROJECT_ID"),
    )
    FIREBASE_PROJECT_ID: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("FIREBASE_PROJECT_ID", "GOOGLE_CLOUD_PROJECT"),
    )
    FIREBASE_SERVICE_ACCOUNT_JSON: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("FIREBASE_SERVICE_ACCOUNT_JSON", "FIREBASE_CREDENTIALS_JSON", "FIREBASE_CREDENTIALS"),
    )
    FIREBASE_CREDENTIALS_JSON: Optional[str] = None
    FIREBASE_CREDENTIALS: Optional[str] = None

    # Cloudflare R2 Media Storage
    R2_ACCOUNT_ID: Optional[str] = None
    R2_ACCESS_KEY_ID: Optional[str] = None
    R2_SECRET_ACCESS_KEY: Optional[str] = None
    R2_BUCKET_NAME: str = "ruralheart-media"
    R2_PUBLIC_DOMAIN: str = "https://r2.ruralheart.com"

    # Razorpay Payments & Subscriptions
    RAZORPAY_KEY_ID: str = "rzp_test_sample"
    RAZORPAY_KEY_SECRET: str = "sample_secret"
    RAZORPAY_WEBHOOK_SECRET: str = "sample_webhook_secret"

    # Ad Monetization & Business Thresholds
    IN_FEED_AD_INTERVAL: int = 5
    SKIP_INTERSTITIAL_THRESHOLD: int = 20
    APP_OPEN_AD_CAP_MINUTES: int = 30
    IN_CHAT_AD_INTERVAL_SECONDS: int = 300
    IN_CHAT_AD_DURATION_SECONDS: int = 10
    FREE_DAILY_DM_LIMIT: int = 1
    SUBSCRIPTION_PRICE_INR: float = 99.00

    # Cross-Origin Resource Sharing
    BACKEND_CORS_ORIGINS: List[str] = ["*"]

    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env"),
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    def log_sanity_check(self):
        """Validates critical production secrets and logs a sanitized status."""
        db_status = "CONFIGURED" if (self.SUPABASE_DB_URL or ("postgresql" in self.DATABASE_URL and "localhost" not in self.DATABASE_URL)) else ("LOCAL/DEFAULT" if self.DATABASE_URL else "MISSING")
        storage_status = "CONFIGURED" if (self.SUPABASE_STORAGE_URL or self.SUPABASE_URL) else "UNSET"
        service_key_status = "SET" if self.SUPABASE_SERVICE_ROLE_KEY else "UNSET"
        firebase_status = "CONFIGURED" if (self.FIREBASE_SERVICE_ACCOUNT_JSON or self.FIREBASE_PROJECT_ID or self.GOOGLE_CLOUD_PROJECT) else "DEVELOPMENT_MODE"

        summary = (
            "\n" + "=" * 60 + "\n"
            f"🚀 [Startup Sanity] Project: {self.PROJECT_NAME} v{self.VERSION}\n"
            f"🌍 [Startup Sanity] Environment: {self.ENVIRONMENT} (Debug: {self.DEBUG})\n"
            f"🗄️  [Startup Sanity] SUPABASE_DB_URL: {db_status}\n"
            f"☁️  [Startup Sanity] SUPABASE_STORAGE_URL: {storage_status}\n"
            f"🔑 [Startup Sanity] SUPABASE_SERVICE_ROLE_KEY: {service_key_status}\n"
            f"🔥 [Startup Sanity] FIREBASE_AUTH_FCM: {firebase_status}\n"
            + "=" * 60
        )
        print(summary)
        logger.info(summary)


settings = Settings()
