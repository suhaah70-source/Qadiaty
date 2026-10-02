"""
Central application configuration.
Loaded once as a singleton `settings` object, read from environment
variables / .env file. Never hardcode secrets here.
"""
from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "قضيتي — منصة المتاجر الليبية"
    ENV: str = "development"
    DEBUG: bool = True

    # Security
    SECRET_KEY: str = "insecure-dev-key-change-me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://platform_user:platform_pass@localhost:5432/platform_db"
    SYNC_DATABASE_URL: str = "postgresql+psycopg2://platform_user:platform_pass@localhost:5432/platform_db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Object storage
    S3_ENDPOINT_URL: str = "http://localhost:9000"
    S3_ACCESS_KEY: str = "minioadmin"
    S3_SECRET_KEY: str = "minioadmin"
    S3_BUCKET_NAME: str = "platform-media"
    S3_REGION: str = "us-east-1"

    # CORS - comma separated origins
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:5173"

    # تسجيل الدخول الاجتماعي (Google / Facebook)
    # GOOGLE_CLIENT_ID: "Web client" أو "OAuth client" الموجود في Google Cloud
    # Console — نفس القيمة المستخدمة كـ serverClientId في تطبيق Flutter.
    # يُستخدم للتحقق من أن رمز id_token صادر فعلاً لتطبيقنا وليس لتطبيق آخر.
    GOOGLE_CLIENT_ID: str = ""
    # FACEBOOK_APP_ID: من Facebook Developer Console — يُستخدم للتحقق من أن
    # رمز access_token صادر لتطبيقنا تحديدًا (عبر debug_token).
    FACEBOOK_APP_ID: str = ""
    FACEBOOK_APP_SECRET: str = ""

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
