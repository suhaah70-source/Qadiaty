import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

from .config import settings

ALGORITHM = "HS256"


def normalize_phone(value: str) -> str:
    digits = "".join(ch for ch in value if ch.isdigit())
    if digits.startswith("00"):
        digits = digits[2:]
    if digits.startswith("218"):
        digits = digits[3:]
    if digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 9:
        raise ValueError("أدخل رقم هاتف ليبي صحيحًا مع مفتاح الدولة +218")
    return f"+218{digits}"


def make_otp() -> str:
    if settings.environment == "development" and settings.otp_dev_code:
        return settings.otp_dev_code
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_otp(phone: str, code: str) -> str:
    message = f"{phone}:{code}".encode()
    return hmac.new(settings.otp_secret.encode(), message, hashlib.sha256).hexdigest()


def verify_otp(phone: str, code: str, expected: str) -> bool:
    return hmac.compare_digest(hash_otp(phone, code), expected)


def create_token(user_id: str, token_type: str) -> str:
    now = datetime.now(timezone.utc)
    expires = now + (
        timedelta(minutes=settings.jwt_access_minutes)
        if token_type == "access"
        else timedelta(days=settings.jwt_refresh_days)
    )
    return jwt.encode(
        {"sub": user_id, "type": token_type, "iat": now, "exp": expires},
        settings.jwt_secret,
        algorithm=ALGORITHM,
    )


def decode_token(token: str, expected_type: str | None = None) -> dict:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise ValueError("رمز الدخول غير صالح أو انتهت صلاحيته") from exc
    if expected_type and payload.get("type") != expected_type:
        raise ValueError("نوع رمز الدخول غير صالح")
    return payload


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return f"scrypt${salt.hex()}${digest.hex()}"


def verify_password(password: str, encoded: str | None) -> bool:
    if not encoded:
        return False
    try:
        algorithm, salt_hex, digest_hex = encoded.split("$", 2)
        if algorithm != "scrypt":
            return False
        digest = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt_hex), n=2**14, r=8, p=1)
        return hmac.compare_digest(digest.hex(), digest_hex)
    except (ValueError, TypeError):
        return False
