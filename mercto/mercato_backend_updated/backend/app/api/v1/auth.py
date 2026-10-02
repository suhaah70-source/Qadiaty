import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from app.models.system import RefreshToken
from app.models.tenant import User, UserStatus
from app.schemas.auth import (
    FacebookLoginRequest,
    GoogleLoginRequest,
    LoginRequest,
    RefreshRequest,
    RegisterCustomerRequest,
    TokenResponse,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["Auth"])


def _ensure_aware(dt: datetime) -> datetime:
    """يضمن أن التاريخ يحمل منطقة زمنية (UTC) قبل أي مقارنة.
    بعض قواعد البيانات (خصوصًا SQLite المستخدم في الاختبارات) لا تحافظ
    على معلومة المنطقة الزمنية حتى لو كان العمود معرّفًا كـ
    DateTime(timezone=True)، فترجع تاريخًا "ساذجًا" (naive) يفجّر أي
    مقارنة مباشرة مع datetime.now(timezone.utc). PostgreSQL (الإنتاج)
    لا يعاني من هذه المشكلة، لكن هذا الحل يجعل الكود صحيحًا في الحالتين."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


async def _issue_tokens(db: AsyncSession, user: User) -> TokenResponse:
    access = create_access_token(user_id=str(user.id), role="SUPER_ADMIN" if user.is_super_admin else "USER")
    refresh = create_refresh_token(user_id=str(user.id))

    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=_hash_token(refresh),
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
    )
    await db.commit()
    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register_customer(payload: RegisterCustomerRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="البريد الإلكتروني مستخدم مسبقا")

    user = User(email=payload.email, name=payload.name, password_hash=hash_password(payload.password))
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Constant-shape error to avoid revealing whether the email exists.
    invalid = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="بيانات الدخول غير صحيحة")

    if user is None or not verify_password(payload.password, user.password_hash):
        raise invalid
    if user.status != UserStatus.ACTIVE:
        raise invalid

    return await _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    invalid = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="رمز التحديث غير صالح")
    try:
        claims = decode_token(payload.refresh_token)
        if claims.get("type") != "refresh":
            raise invalid
        user_id = uuid.UUID(claims["sub"])
    except (JWTError, ValueError, KeyError):
        raise invalid

    token_hash = _hash_token(payload.refresh_token)
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.user_id == user_id,
            RefreshToken.token_hash == token_hash,
            RefreshToken.revoked_at.is_(None),
        )
    )
    stored = result.scalar_one_or_none()
    if stored is None or _ensure_aware(stored.expires_at) < datetime.now(timezone.utc):
        raise invalid

    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if user is None or user.status != UserStatus.ACTIVE:
        raise invalid

    # rotate: revoke old, issue new
    stored.revoked_at = datetime.now(timezone.utc)
    return await _issue_tokens(db, user)


async def _find_or_create_social_user(db: AsyncSession, *, email: str, name: str) -> User:
    """يبحث عن مستخدم بنفس البريد (بغض النظر عن طريقة الدخول السابقة)،
    أو يُنشئ حسابًا جديدًا. حسابات الدخول الاجتماعي تُنشأ بكلمة مرور
    عشوائية غير قابلة للاستخدام (المستخدم لا يعرفها ولن يحتاجها طالما
    يدخل عبر نفس مزوّد الهوية) بدل تعديل مخطط قاعدة البيانات لجعل
    password_hash قابلاً لأن يكون فارغًا.
    """
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is not None:
        return user

    user = User(
        email=email,
        name=name or email.split("@")[0],
        password_hash=hash_password(secrets.token_urlsafe(32)),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/oauth/google", response_model=TokenResponse)
async def login_with_google(payload: GoogleLoginRequest, db: AsyncSession = Depends(get_db)):
    invalid = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="تعذّر التحقق من حساب Google")

    async with httpx.AsyncClient(timeout=10) as client:
        try:
            resp = await client.get(
                "https://oauth2.googleapis.com/tokeninfo",
                params={"id_token": payload.id_token},
            )
        except httpx.HTTPError:
            raise invalid

    if resp.status_code != 200:
        raise invalid

    data = resp.json()

    # لو تم ضبط GOOGLE_CLIENT_ID، نتأكد أن الرمز صادر فعلاً لتطبيقنا
    # (يمنع قبول رمز صالح لكن صادر لتطبيق Google آخر).
    if settings.GOOGLE_CLIENT_ID and data.get("aud") != settings.GOOGLE_CLIENT_ID:
        raise invalid

    email = data.get("email")
    if not email or data.get("email_verified") not in ("true", True):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="حساب Google بدون بريد إلكتروني موثّق")

    user = await _find_or_create_social_user(db, email=email, name=data.get("name", ""))
    if user.status != UserStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="هذا الحساب موقوف")

    return await _issue_tokens(db, user)


@router.post("/oauth/facebook", response_model=TokenResponse)
async def login_with_facebook(payload: FacebookLoginRequest, db: AsyncSession = Depends(get_db)):
    invalid = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="تعذّر التحقق من حساب Facebook")

    async with httpx.AsyncClient(timeout=10) as client:
        try:
            resp = await client.get(
                "https://graph.facebook.com/me",
                params={"fields": "id,name,email", "access_token": payload.access_token},
            )
        except httpx.HTTPError:
            raise invalid

    if resp.status_code != 200:
        raise invalid

    data = resp.json()
    if "error" in data:
        raise invalid

    # لو تم ضبط FACEBOOK_APP_ID/SECRET، نتحقق عبر debug_token أن هذا
    # الرمز صادر فعلاً لتطبيقنا — بدون هذا التحقق أي access_token صالح
    # (حتى الصادر لتطبيق فيسبوك آخر) كان يُقبل طالما ينجح النداء لـ /me.
    if settings.FACEBOOK_APP_ID and settings.FACEBOOK_APP_SECRET:
        async with httpx.AsyncClient(timeout=10) as client:
            try:
                debug_resp = await client.get(
                    "https://graph.facebook.com/debug_token",
                    params={
                        "input_token": payload.access_token,
                        "access_token": f"{settings.FACEBOOK_APP_ID}|{settings.FACEBOOK_APP_SECRET}",
                    },
                )
            except httpx.HTTPError:
                raise invalid
        debug_data = (debug_resp.json() or {}).get("data", {}) if debug_resp.status_code == 200 else {}
        if not debug_data.get("is_valid") or str(debug_data.get("app_id")) != settings.FACEBOOK_APP_ID:
            raise invalid

    email = data.get("email")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="حساب Facebook هذا لا يشارك بريدًا إلكترونيًا — فعّل صلاحية email عند الدخول",
        )

    user = await _find_or_create_social_user(db, email=email, name=data.get("name", ""))
    if user.status != UserStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="هذا الحساب موقوف")

    return await _issue_tokens(db, user)
