import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    environment: str = os.getenv("APP_ENV", "development")
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./mercato.db")
    jwt_secret: str = os.getenv("JWT_SECRET", "dev-only-change-this-secret")
    jwt_access_minutes: int = int(os.getenv("JWT_ACCESS_MINUTES", "30"))
    jwt_refresh_days: int = int(os.getenv("JWT_REFRESH_DAYS", "30"))
    otp_secret: str = os.getenv("OTP_SECRET", "dev-only-change-this-otp-secret")
    otp_ttl_minutes: int = int(os.getenv("OTP_TTL_MINUTES", "5"))
    otp_dev_code: str = os.getenv("OTP_DEV_CODE", "123456")
    admin_phone: str = os.getenv("ADMIN_PHONE", "+218915750694")
    delivery_fee_lyd: float = float(os.getenv("DELIVERY_FEE_LYD", "0"))
    cors_origins: tuple[str, ...] = tuple(
        value.strip()
        for value in os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173").split(",")
        if value.strip()
    )
    cors_origin_regex: str | None = os.getenv(
        "CORS_ORIGIN_REGEX",
        r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    ) if os.getenv("APP_ENV", "development") == "development" else None


settings = Settings()
