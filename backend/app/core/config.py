import os
from typing import List
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    # Core Environment
    ENVIRONMENT: str = "development"
    PORT: int = 8000
    CORS_ALLOWED_ORIGINS: str = "https://asiverticals.com,http://localhost:3000"

    # Database & Supabase (Backend service_role only)
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/postgres"
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_PUBLISHABLE_KEY: str = ""
    SUPABASE_PROJECT_ID: str = ""

    # Firebase Admin SDK
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CLIENT_EMAIL: str = ""
    FIREBASE_PRIVATE_KEY: str = ""

    # Groq AI KYC
    GROQ_API_KEY: str = ""

    # AdMob & AppLovin Monetization
    ADMOB_APP_ID: str = ""
    APPLOVIN_SDK_KEY: str = "UR_HEART_APPLOVIN_SECRET_KEY"
    GOOGLE_VERIFIER_KEYS_URL: str = "https://www.gstatic.com/admob/reward/verifier-keys.json"

    # Internal JWT
    INTERNAL_JWT_SECRET: str = "UR_HEART_INTERNAL_HMAC_SECRET_KEY_ASI_VERTICALS"

    # Data Encryption at Rest (AES-256 GCM)
    DATA_ENCRYPTION_KEY_BASE64: str = "MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE="

    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ALLOWED_ORIGINS.split(",") if origin.strip()]

    @model_validator(mode="after")
    def validate_production_secrets(self) -> "Settings":
        """
        Fails fast on startup if production environment lacks required secrets.
        """
        if self.ENVIRONMENT == "production":
            required_secrets = {
                "SUPABASE_URL": self.SUPABASE_URL,
                "SUPABASE_SERVICE_ROLE_KEY": self.SUPABASE_SERVICE_ROLE_KEY,
                "FIREBASE_PROJECT_ID": self.FIREBASE_PROJECT_ID,
                "FIREBASE_CLIENT_EMAIL": self.FIREBASE_CLIENT_EMAIL,
                "FIREBASE_PRIVATE_KEY": self.FIREBASE_PRIVATE_KEY,
                "GROQ_API_KEY": self.GROQ_API_KEY,
                "ADMOB_APP_ID": self.ADMOB_APP_ID,
                "APPLOVIN_SDK_KEY": self.APPLOVIN_SDK_KEY,
            }
            missing = [k for k, v in required_secrets.items() if not v or "your_" in v]
            if missing:
                raise ValueError(
                    f"FATAL: Missing required production secrets in environment: {', '.join(missing)}"
                )
        return self

settings = Settings()
