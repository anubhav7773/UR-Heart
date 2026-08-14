from typing import List, Optional
from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Server & API Meta
    PROJECT_NAME: str = "UR Heart API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # Security & JWT
    SECRET_KEY: str = Field(
        default="ruralheart_super_secret_jwt_key_2026_change_in_prod",
        validation_alias=AliasChoices("SECRET_KEY", "JWT_SECRET"),
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 21600  # 15 days in minutes

    # Database & Supabase Integration
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/ruralheart",
        validation_alias=AliasChoices("DATABASE_URL"),
    )
    SUPABASE_URL: Optional[str] = None
    SUPABASE_KEY: Optional[str] = None
    SUPABASE_SERVICE_ROLE_KEY: Optional[str] = None

    # Firebase Cloud Messaging (FCM)
    FIREBASE_PROJECT_ID: Optional[str] = None
    FIREBASE_CREDENTIALS_JSON: Optional[str] = None

    # Cloudflare R2 Media Storage
    R2_ACCOUNT_ID: Optional[str] = None
    R2_ACCESS_KEY_ID: Optional[str] = None
    R2_SECRET_ACCESS_KEY: Optional[str] = None
    R2_BUCKET_NAME: str = "ruralheart-media"
    R2_PUBLIC_DOMAIN: str = "https://r2.ruralheart.com"

    # Payments & Subscriptions (Razorpay)
    RAZORPAY_KEY_ID: str = "rzp_test_sample"
    RAZORPAY_KEY_SECRET: str = "sample_secret"
    RAZORPAY_WEBHOOK_SECRET: str = "sample_webhook_secret"

    # Ad Monetization & Frequency Cap Controls
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
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
