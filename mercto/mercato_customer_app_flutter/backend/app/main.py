from collections import defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
import json
import logging
from pathlib import Path
import unicodedata
from uuid import uuid4

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import func, inspect, or_, select, text, update
from sqlalchemy.orm import Session, joinedload

from .config import settings
from .database import Base, engine, get_db
from .models import (
    Address, AuditLog, Banner, CartItem, Category, OTPChallenge, Order, OrderItem,
    OrderStatusHistory, Product, Store, StoreReview, User,
)
from .schemas import (
    AddressInput, BannerInput, CartItemInput, CategoryInput, CheckoutInput, OTPRequest,
    OTPVerify, OrderStatusInput, ProductInput, RefreshRequest,
    ReviewDecision, StoreApplicationInput, StoreUpdate, PasswordLogin, PasswordReset,
)
from .security import create_token, decode_token, hash_otp, hash_password, make_otp, normalize_phone, verify_otp, verify_password

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("digital_mall")
Base.metadata.create_all(bind=engine)
# Add the password column to existing development databases as well as fresh installs.
user_columns = {column["name"] for column in inspect(engine).get_columns("users")}
with engine.begin() as connection:
    if "password_hash" not in user_columns:
        connection.execute(text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(256)"))
    if "terms_accepted_at" not in user_columns:
        connection.execute(text("ALTER TABLE users ADD COLUMN terms_accepted_at TIMESTAMP NULL"))
    if "invite_code" not in user_columns:
        connection.execute(text("ALTER TABLE users ADD COLUMN invite_code VARCHAR(80) NULL"))
    if "loyalty_half_points" not in user_columns:
        connection.execute(text("ALTER TABLE users ADD COLUMN loyalty_half_points INTEGER NOT NULL DEFAULT 0"))
    if "wallet_balance" not in user_columns:
        connection.execute(text("ALTER TABLE users ADD COLUMN wallet_balance NUMERIC(10, 2) NOT NULL DEFAULT 0.00"))
    store_columns = {column["name"] for column in inspect(engine).get_columns("stores")}
    if "store_category" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN store_category VARCHAR(40) NOT NULL DEFAULT 'general'"))
    if "product_image_shape" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN product_image_shape VARCHAR(20) NOT NULL DEFAULT 'rounded'"))
    if "product_image_scale" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN product_image_scale FLOAT NOT NULL DEFAULT 0.85"))
    if "show_product_card" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN show_product_card BOOLEAN NOT NULL DEFAULT 1"))
    if "background_image_url" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN background_image_url VARCHAR(500) NULL"))
    if "background_image_fit" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN background_image_fit VARCHAR(12) NOT NULL DEFAULT 'contain'"))
    if "background_overlay_opacity" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN background_overlay_opacity FLOAT NOT NULL DEFAULT 0.12"))
    if "logo_position" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN logo_position VARCHAR(24) NOT NULL DEFAULT 'topRight'"))
    if "logo_shape" not in store_columns:
        connection.execute(text("ALTER TABLE stores ADD COLUMN logo_shape VARCHAR(20) NOT NULL DEFAULT 'circle'"))
    for column, declaration in {
        "background_style": "VARCHAR(20) NOT NULL DEFAULT 'solid'",
        "background_gradient_start": "VARCHAR(7) NOT NULL DEFAULT '#F3EBDD'",
        "background_gradient_end": "VARCHAR(7) NOT NULL DEFAULT '#E6D7C3'",
        "accent_color": "VARCHAR(7) NOT NULL DEFAULT '#B76E42'",
        "card_color": "VARCHAR(7) NOT NULL DEFAULT '#FFFFFF'",
        "controls_x": "FLOAT NOT NULL DEFAULT 0.5",
        "controls_y": "FLOAT NOT NULL DEFAULT 0.18",
        "design_json": "TEXT NOT NULL DEFAULT '[]'",
        "product_layout": "VARCHAR(20) NOT NULL DEFAULT 'grid'",
        "product_columns": "INTEGER NOT NULL DEFAULT 2",
        "category_style": "VARCHAR(20) NOT NULL DEFAULT 'chips'",
        "product_card_style": "VARCHAR(20) NOT NULL DEFAULT 'classic'",
        "show_product_descriptions": "BOOLEAN NOT NULL DEFAULT 0",
    }.items():
        if column not in store_columns:
            connection.execute(text(f"ALTER TABLE stores ADD COLUMN {column} {declaration}"))
    product_columns = {column["name"] for column in inspect(engine).get_columns("products")}
    if "sort_order" not in product_columns:
        connection.execute(text("ALTER TABLE products ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0"))
    address_columns = {column["name"] for column in inspect(engine).get_columns("addresses")}
    if "latitude" not in address_columns:
        connection.execute(text("ALTER TABLE addresses ADD COLUMN latitude FLOAT NULL"))
    if "longitude" not in address_columns:
        connection.execute(text("ALTER TABLE addresses ADD COLUMN longitude FLOAT NULL"))
    order_columns = {column["name"] for column in inspect(engine).get_columns("orders")}
    if "loyalty_awarded" not in order_columns:
        connection.execute(text("ALTER TABLE orders ADD COLUMN loyalty_awarded BOOLEAN NOT NULL DEFAULT 0"))
    if "customer_note" not in order_columns:
        connection.execute(text("ALTER TABLE orders ADD COLUMN customer_note TEXT NULL"))

app = FastAPI(
    title="Qadiyati API",
    version="1.0.0",
    description="واجهات منصة المول الرقمي متعددة المتاجر",
)
UPLOAD_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=UPLOAD_DIR), name="media")
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def fail(code: int, message: str):
    raise HTTPException(status_code=code, detail=message)


def user_payload(user: User) -> dict:
    return {
        "id": user.id,
        "phone": user.phone,
        "full_name": user.full_name,
        "city": user.city,
        "role": user.role,
        "is_active": user.is_active,
        "loyalty_points": float(Decimal(user.loyalty_half_points) / Decimal(2)),
        "wallet_balance": float(user.wallet_balance or Decimal("0.00")),
        "available_rewards": user.loyalty_half_points // 200,
    }


def token_payload(user: User) -> dict:
    return {
        "access_token": create_token(user.id, "access"),
        "refresh_token": create_token(user.id, "refresh"),
        "token_type": "bearer",
        "user": user_payload(user),
    }


def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        fail(status.HTTP_401_UNAUTHORIZED, "سجّل الدخول أولًا")
    try:
        claims = decode_token(authorization.split(" ", 1)[1], "access")
    except ValueError as exc:
        fail(status.HTTP_401_UNAUTHORIZED, str(exc))
    user = db.get(User, claims.get("sub"))
    if not user or not user.is_active:
        fail(status.HTTP_401_UNAUTHORIZED, "الحساب غير متاح")
    return user


def require_admin(user: User = Depends(current_user)) -> User:
    if user.role != "ADMIN":
        fail(status.HTTP_403_FORBIDDEN, "هذه العملية خاصة بمدير المنصة")
    return user


def owned_store(db: Session, user: User) -> Store:
    store = db.scalar(select(Store).where(Store.owner_id == user.id))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "لا يوجد متجر مرتبط بهذا الحساب")
    if store.status != "APPROVED":
        fail(status.HTTP_403_FORBIDDEN, "المتجر غير معتمد أو موقوف")
    return store


def store_json(store: Store) -> dict:
    return {
        "id": store.id,
        "tenant_id": store.id,
        "code": store.code,
        "slug": store.slug,
        "name": store.name,
        "description": store.description,
        "city": store.city,
        "store_category": store.store_category,
        "product_image_shape": store.product_image_shape,
        "product_image_scale": store.product_image_scale,
        "show_product_card": store.show_product_card,
        "product_layout": store.product_layout,
        "product_columns": store.product_columns,
        "category_style": store.category_style,
        "product_card_style": store.product_card_style,
        "show_product_descriptions": store.show_product_descriptions,
        "background_image_url": store.background_image_url,
        "background_image_fit": store.background_image_fit,
        "background_overlay_opacity": store.background_overlay_opacity,
        "logo_position": store.logo_position,
        "logo_shape": store.logo_shape,
        "status": store.status,
        "logo_url": store.logo_url,
        "banner_url": store.banner_url,
        "primary_color": store.primary_color,
        "secondary_color": store.secondary_color,
        "background_color": store.background_color,
        "text_color": store.text_color,
        "accent_color": store.accent_color,
        "card_color": store.card_color,
        "background_style": store.background_style,
        "background_gradient_start": store.background_gradient_start,
        "background_gradient_end": store.background_gradient_end,
        "controls_x": store.controls_x,
        "controls_y": store.controls_y,
        "design_elements": json.loads(store.design_json or "[]"),
    }


def product_json(product: Product) -> dict:
    return {
        "id": product.id,
        "store_id": product.store_id,
        "name": product.name,
        "description": product.description,
        "sku": product.sku,
        "price": float(product.price),
        "stock": product.stock,
        "sort_order": product.sort_order,
        "image_url": product.image_url,
        "status": product.status,
        "category_id": product.category_id,
    }


def order_json(order: Order) -> dict:
    return {
        "id": order.id,
        "store_id": order.store_id,
        "store_name": order.store.name if order.store else "",
        "status": order.status,
        "subtotal": float(order.subtotal),
        "delivery_fee": float(order.delivery_fee),
        "total": float(order.total),
        "payment_method": order.payment_method,
        "delivery_address": order.delivery_address_snapshot,
        "customer_note": order.customer_note,
        "created_at": order.created_at.isoformat(),
        "items": [
            {
                "product_id": item.product_id,
                "product_name_snapshot": item.product_name_snapshot,
                "image_url": item.product.image_url if item.product else None,
                "unit_price": float(item.unit_price),
                "quantity": item.quantity,
            }
            for item in order.items
        ],
    }


@app.get("/health")
def health():
    return {"status": "ok", "service": "digital-mall-api"}


@app.post("/api/v1/auth/request-otp")
def request_otp(payload: OTPRequest, db: Session = Depends(get_db)):
    if settings.environment != "development":
        fail(status.HTTP_503_SERVICE_UNAVAILABLE, "مزود رسائل SMS غير مربوط بعد")
    try:
        phone = normalize_phone(payload.phone)
    except ValueError as exc:
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))
    recent = db.scalar(
        select(OTPChallenge).where(OTPChallenge.phone == phone)
        .order_by(OTPChallenge.created_at.desc())
    )
    now = datetime.now(timezone.utc)
    if recent:
        created = recent.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        if created > now - timedelta(seconds=45):
            fail(status.HTTP_429_TOO_MANY_REQUESTS, "انتظر قليلًا قبل طلب رمز جديد")
    code = make_otp()
    db.add(OTPChallenge(
        phone=phone,
        code_hash=hash_otp(phone, code),
        expires_at=now + timedelta(minutes=settings.otp_ttl_minutes),
    ))
    db.commit()
    logger.info("Development OTP for %s: %s", phone, code)
    response = {"message": "تم تجهيز رمز التحقق", "expires_in_seconds": settings.otp_ttl_minutes * 60}
    if settings.environment == "development":
        response["debug_code"] = code
    return response


@app.post("/api/v1/auth/verify-otp")
def verify_otp_route(payload: OTPVerify, db: Session = Depends(get_db)):
    try:
        phone = normalize_phone(payload.phone)
    except ValueError as exc:
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))
    challenge = db.scalar(
        select(OTPChallenge).where(OTPChallenge.phone == phone)
        .order_by(OTPChallenge.created_at.desc())
    )
    if not challenge or challenge.attempts >= 5:
        fail(status.HTTP_400_BAD_REQUEST, "اطلب رمز تحقق جديدًا")
    now = datetime.now(timezone.utc)
    expires = challenge.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires < now:
        db.delete(challenge)
        db.commit()
        fail(status.HTTP_400_BAD_REQUEST, "انتهت صلاحية الرمز، اطلب رمزًا جديدًا")
    if not verify_otp(phone, payload.code, challenge.code_hash):
        challenge.attempts += 1
        db.commit()
        fail(status.HTTP_400_BAD_REQUEST, "رمز التحقق غير صحيح")
    db.delete(challenge)
    user = db.scalar(select(User).where(User.phone == phone))
    if not user:
        if not payload.full_name:
            fail(status.HTTP_400_BAD_REQUEST, "أدخل اسمك لإكمال إنشاء الحساب")
        if not payload.password:
            fail(status.HTTP_400_BAD_REQUEST, "Password is required for registration")
        if not payload.terms_accepted:
            fail(status.HTTP_400_BAD_REQUEST, "Terms acceptance is required")
        user = User(phone=phone, full_name=payload.full_name.strip(), city=payload.city,
                    password_hash=hash_password(payload.password),
                    terms_accepted_at=datetime.now(timezone.utc), invite_code=payload.invite_code)
        db.add(user)
    elif payload.password and not user.password_hash:
        if not payload.terms_accepted:
            fail(status.HTTP_400_BAD_REQUEST, "Terms acceptance is required")
        user.password_hash = hash_password(payload.password)
        user.terms_accepted_at = datetime.now(timezone.utc)
        user.invite_code = payload.invite_code
    if user and payload.full_name and not user.full_name:
        user.full_name = payload.full_name.strip()
        user.city = payload.city
    if phone == normalize_phone(settings.admin_phone):
        user.role = "ADMIN"
    db.commit()
    db.refresh(user)
    return token_payload(user)


@app.post("/api/v1/auth/login")
def password_login(payload: PasswordLogin, db: Session = Depends(get_db)):
    try:
        phone = normalize_phone(payload.phone)
    except ValueError as exc:
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))
    user = db.scalar(select(User).where(User.phone == phone))
    if not user or not user.is_active or not verify_password(payload.password, user.password_hash):
        fail(status.HTTP_401_UNAUTHORIZED, "Invalid phone number or password")
    if phone == normalize_phone(settings.admin_phone):
        user.role = "ADMIN"
        db.commit()
        db.refresh(user)
    return token_payload(user)


@app.post("/api/v1/auth/reset-password")
def reset_password(payload: PasswordReset, db: Session = Depends(get_db)):
    try:
        phone = normalize_phone(payload.phone)
    except ValueError as exc:
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))
    challenge = db.scalar(select(OTPChallenge).where(OTPChallenge.phone == phone).order_by(OTPChallenge.created_at.desc()))
    if not challenge or challenge.attempts >= 5:
        fail(status.HTTP_400_BAD_REQUEST, "Request a new verification code")
    expires = challenge.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires < datetime.now(timezone.utc):
        fail(status.HTTP_400_BAD_REQUEST, "Verification code expired")
    if not verify_otp(phone, payload.code, challenge.code_hash):
        challenge.attempts += 1
        db.commit()
        fail(status.HTTP_400_BAD_REQUEST, "Invalid verification code")
    user = db.scalar(select(User).where(User.phone == phone))
    if not user:
        fail(status.HTTP_404_NOT_FOUND, "Account not found")
    user.password_hash = hash_password(payload.new_password)
    db.delete(challenge)
    db.commit()
    return {"message": "Password updated"}


@app.post("/api/v1/auth/refresh")
def refresh_token(payload: RefreshRequest, db: Session = Depends(get_db)):
    try:
        claims = decode_token(payload.refresh_token, "refresh")
    except ValueError as exc:
        fail(status.HTTP_401_UNAUTHORIZED, str(exc))
    user = db.get(User, claims.get("sub"))
    if not user or not user.is_active:
        fail(status.HTTP_401_UNAUTHORIZED, "الحساب غير متاح")
    return token_payload(user)


@app.get("/api/v1/auth/me")
def me(user: User = Depends(current_user)):
    return user_payload(user)


@app.get("/api/v1/stores")
def list_stores(q: str | None = Query(default=None, max_length=100), city: str | None = Query(default=None, max_length=80), category: str | None = Query(default=None, max_length=40), db: Session = Depends(get_db)):
    query = select(Store).where(Store.status == "APPROVED")
    if city:
        query = query.where(Store.city.ilike(city.strip()))
    if category:
        query = query.where(Store.store_category == category.strip().lower())
    if q:
        pattern = f"%{q.strip()}%"
        query = query.where(or_(Store.name.ilike(pattern), Store.description.ilike(pattern)))
    return [store_json(row) for row in db.scalars(query.order_by(Store.name)).all()]


@app.get("/api/v1/stores/{slug}")
def get_store(slug: str, db: Session = Depends(get_db)):
    store = db.scalar(select(Store).where(Store.slug == slug, Store.status == "APPROVED"))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "المتجر غير موجود أو غير متاح")
    categories = db.scalars(
        select(Category).join(Product, Product.category_id == Category.id)
        .where(Product.store_id == store.id, Category.is_active.is_(True)).distinct()
    ).all()
    products = db.scalars(
        select(Product).where(Product.store_id == store.id, Product.status == "ACTIVE")
        .order_by(Product.sort_order, Product.created_at)
    ).all()
    return {
        **store_json(store),
        "theme": {
            "primary_color": store.primary_color,
            "secondary_color": store.secondary_color,
            "background_color": store.background_color,
            "text_color": store.text_color,
            "accent_color": store.accent_color,
            "card_color": store.card_color,
            "background_style": store.background_style,
            "background_gradient_start": store.background_gradient_start,
            "background_gradient_end": store.background_gradient_end,
            "controls_x": store.controls_x,
            "controls_y": store.controls_y,
            "design_elements": json.loads(store.design_json or "[]"),
            "product_image_shape": store.product_image_shape,
            "product_image_scale": store.product_image_scale,
            "show_product_card": store.show_product_card,
            "product_layout": store.product_layout,
            "product_columns": store.product_columns,
            "category_style": store.category_style,
            "product_card_style": store.product_card_style,
            "show_product_descriptions": store.show_product_descriptions,
            "background_image_url": store.background_image_url,
            "background_image_fit": store.background_image_fit,
            "background_overlay_opacity": store.background_overlay_opacity,
            "logo_position": store.logo_position,
            "logo_shape": store.logo_shape,
            "logo_url": store.logo_url,
            "banner_url": store.banner_url,
        },
        "categories": [{"id": row.id, "name": row.name, "slug": row.slug} for row in categories],
        "products": [product_json(row) for row in products],
    }


@app.get("/api/v1/stores/{slug}/reviews")
def list_store_reviews(
    slug: str,
    product_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    store = db.scalar(select(Store).where(Store.slug == slug, Store.status == "APPROVED"))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "المتجر غير موجود أو غير متاح")
    query = select(StoreReview, User.full_name).join(User, User.id == StoreReview.user_id).where(StoreReview.store_id == store.id)
    if product_id:
        query = query.where(StoreReview.product_id == product_id)
    else:
        query = query.where(StoreReview.product_id.is_(None))
    rows = db.execute(query.order_by(StoreReview.created_at.desc()).limit(100)).all()
    average = sum(review.rating for review, _ in rows) / len(rows) if rows else 0
    return {
        "average": round(average, 1),
        "count": len(rows),
        "reviews": [{
            "id": review.id,
            "rating": review.rating,
            "comment": review.comment,
            "author": name or "عميل",
            "created_at": review.created_at.isoformat(),
        } for review, name in rows],
    }


@app.post("/api/v1/stores/{slug}/reviews", status_code=201)
def create_store_review(
    slug: str,
    payload: dict,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    store = db.scalar(select(Store).where(Store.slug == slug, Store.status == "APPROVED"))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "المتجر غير موجود أو غير متاح")
    try:
        rating = int(payload.get("rating"))
    except (TypeError, ValueError):
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, "اختر تقييمًا من نجمة إلى خمس نجوم")
    comment = str(payload.get("comment") or "").strip()
    product_id = str(payload.get("product_id") or "").strip() or None
    if rating < 1 or rating > 5:
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, "التقييم يجب أن يكون بين نجمة وخمس نجوم")
    if len(comment) < 2 or len(comment) > 2000:
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, "اكتب تعليقًا من حرفين إلى 2000 حرف")
    if product_id and not db.scalar(select(Product.id).where(Product.id == product_id, Product.store_id == store.id, Product.status == "ACTIVE")):
        fail(status.HTTP_404_NOT_FOUND, "المنتج غير موجود في هذا المتجر")
    existing = db.scalar(select(StoreReview).where(
        StoreReview.store_id == store.id,
        StoreReview.product_id == product_id if product_id else StoreReview.product_id.is_(None),
        StoreReview.user_id == user.id,
    ))
    if existing:
        existing.rating = rating
        existing.comment = comment
        existing.created_at = datetime.now(timezone.utc)
        review = existing
    else:
        review = StoreReview(store_id=store.id, product_id=product_id, user_id=user.id, rating=rating, comment=comment)
        db.add(review)
    db.commit()
    db.refresh(review)
    return {"id": review.id, "rating": review.rating, "comment": review.comment, "author": user.full_name or "عميل", "created_at": review.created_at.isoformat()}


@app.get("/api/v1/categories")
def list_categories(db: Session = Depends(get_db)):
    return [
        {"id": row.id, "name": row.name, "slug": row.slug}
        for row in db.scalars(
            select(Category).where(Category.is_active.is_(True)).order_by(Category.sort_order, Category.name)
        ).all()
    ]


@app.get("/api/v1/banners")
def list_banners(db: Session = Depends(get_db)):
    return [
        {"id": row.id, "title": row.title, "image_url": row.image_url, "target_url": row.target_url}
        for row in db.scalars(
            select(Banner).where(Banner.is_active.is_(True)).order_by(Banner.sort_order)
        ).all()
    ]


def _arabic_slug(name: str, user_id: str) -> str:
    """Make a URL slug that preserves Arabic names and is unique per owner."""
    normalized = unicodedata.normalize("NFKC", name).strip().lower()
    pieces: list[str] = []
    for char in normalized:
        if char.isalnum():
            pieces.append(char)
        elif pieces and pieces[-1] != "-":
            pieces.append("-")
    base = "".join(pieces).strip("-") or "store"
    return f"{base}-{user_id.replace('-', '')[:6]}"[:100]


@app.post("/api/v1/stores/applications", status_code=201)
def apply_for_store(payload: StoreApplicationInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if user.role == "ADMIN":
        fail(status.HTTP_400_BAD_REQUEST, "حساب الإدارة لا يحتاج إلى طلب متجر")
    if db.scalar(select(Store).where(Store.owner_id == user.id)):
        fail(status.HTTP_409_CONFLICT, "لهذا الحساب طلب متجر أو متجر مسجل بالفعل")
    slug = payload.slug or _arabic_slug(payload.name, user.id)
    if db.scalar(select(Store).where(Store.slug == slug)):
        fail(status.HTTP_409_CONFLICT, "اسم رابط المتجر مستخدم")
    store = Store(
        owner_id=user.id,
        code=f"SHOP-{user.id[:8].upper()}",
        slug=slug,
        name=payload.name,
        description=payload.description,
        city=payload.city,
        store_category=payload.store_category,
    )
    user.role = "VENDOR"
    db.add(store)
    db.commit()
    db.refresh(store)
    return store_json(store)


@app.get("/api/v1/vendor/store")
def vendor_store(db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = db.scalar(select(Store).where(Store.owner_id == user.id))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "لم ترسل طلب فتح متجر بعد")
    return {
        **store_json(store),
        "review_note": store.review_note,
        "theme": {
            "primary_color": store.primary_color,
            "secondary_color": store.secondary_color,
            "background_color": store.background_color,
            "text_color": store.text_color,
            "product_image_shape": store.product_image_shape,
            "product_image_scale": store.product_image_scale,
            "show_product_card": store.show_product_card,
            "background_image_url": store.background_image_url,
            "background_image_fit": store.background_image_fit,
            "background_overlay_opacity": store.background_overlay_opacity,
            "logo_position": store.logo_position,
        },
    }


@app.patch("/api/v1/vendor/store")
def update_vendor_store(payload: StoreUpdate, db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = db.scalar(select(Store).where(Store.owner_id == user.id))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "No store is linked to this account")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(store, key, value)
    db.commit()
    db.refresh(store)
    return store_json(store)


@app.post("/api/v1/vendor/media", status_code=201)
async def upload_vendor_media(
    file: UploadFile = File(...),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    store = db.scalar(select(Store).where(Store.owner_id == user.id))
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "No store is linked to this account")
    allowed = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
    extension = allowed.get(file.content_type or "")
    if not extension:
        fail(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Upload a PNG, JPEG, or WebP image")
    contents = await file.read(5 * 1024 * 1024 + 1)
    if not contents or len(contents) > 5 * 1024 * 1024:
        fail(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Image must be smaller than 5 MB")
    signatures = {
        ".jpg": contents.startswith(bytes([255, 216, 255])),
        ".png": contents.startswith(bytes([137, 80, 78, 71, 13, 10, 26, 10])),
        ".webp": contents.startswith(b"RIFF") and contents[8:12] == b"WEBP",
    }
    if not signatures[extension]:
        fail(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "The file contents do not match its image type")
    filename = f"{uuid4().hex}{extension}"
    (UPLOAD_DIR / filename).write_bytes(contents)
    return {"url": f"/media/{filename}"}


@app.get("/api/v1/admin/overview")
def admin_overview(db: Session = Depends(get_db), _admin: User = Depends(require_admin)):
    return {
        "stores": db.scalar(select(func.count()).select_from(Store)) or 0,
        "pending_stores": db.scalar(select(func.count()).select_from(Store).where(Store.status == "PENDING")) or 0,
        "approved_stores": db.scalar(select(func.count()).select_from(Store).where(Store.status == "APPROVED")) or 0,
        "products": db.scalar(select(func.count()).select_from(Product)) or 0,
        "orders": db.scalar(select(func.count()).select_from(Order)) or 0,
        "users": db.scalar(select(func.count()).select_from(User)) or 0,
    }


@app.get("/api/v1/vendor/products")
def vendor_products(db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = owned_store(db, user)
    rows = db.scalars(select(Product).where(Product.store_id == store.id).order_by(Product.sort_order, Product.created_at)).all()
    return [product_json(row) for row in rows]


@app.post("/api/v1/vendor/products", status_code=201)
def create_product(payload: ProductInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = owned_store(db, user)
    if payload.category_id and not db.get(Category, payload.category_id):
        fail(status.HTTP_404_NOT_FOUND, "التصنيف غير موجود")
    product = Product(store_id=store.id, **payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product_json(product)


@app.patch("/api/v1/vendor/products/{product_id}")
def update_product(product_id: str, payload: ProductInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = owned_store(db, user)
    product = db.scalar(select(Product).where(Product.id == product_id, Product.store_id == store.id))
    if not product:
        fail(status.HTTP_404_NOT_FOUND, "المنتج غير موجود في متجرك")
    for key, value in payload.model_dump().items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product_json(product)


@app.delete("/api/v1/vendor/products/{product_id}")
def delete_product(product_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = owned_store(db, user)
    product = db.scalar(select(Product).where(Product.id == product_id, Product.store_id == store.id))
    if not product:
        fail(status.HTTP_404_NOT_FOUND, "المنتج غير موجود في متجرك")
    product.status = "HIDDEN"
    db.commit()
    return {"message": "تم إخفاء المنتج"}


def address_json(address: Address) -> dict:
    return {
        "id": address.id,
        "city": address.city,
        "district": address.district,
        "address_text": address.address_text,
        "phone": address.phone,
        "is_default": address.is_default,
        "latitude": address.latitude,
        "longitude": address.longitude,
    }


@app.post("/api/v1/addresses", status_code=201)
def create_address(payload: AddressInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if payload.is_default:
        for old in db.scalars(select(Address).where(Address.user_id == user.id)).all():
            old.is_default = False
    address = Address(user_id=user.id, **payload.model_dump())
    db.add(address)
    db.commit()
    db.refresh(address)
    return address_json(address)


@app.get("/api/v1/addresses")
def list_addresses(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return [address_json(row) for row in db.scalars(select(Address).where(Address.user_id == user.id)).all()]


@app.delete("/api/v1/addresses/{address_id}", status_code=204)
def delete_address(address_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    address = db.scalar(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    if not address:
        fail(status.HTTP_404_NOT_FOUND, "Address not found")
    db.delete(address)
    db.commit()


def cart_json(db: Session, user: User) -> dict:
    rows = db.scalars(
        select(CartItem).options(joinedload(CartItem.product).joinedload(Product.store))
        .where(CartItem.user_id == user.id)
    ).all()
    return {
        "id": user.id,
        "tenant_id": None,
        "items": [
            {
                "id": row.id,
                "product_id": row.product_id,
                "product_name": row.product.name,
                "store_id": row.product.store_id,
                "store_name": row.product.store.name,
                "store_slug": row.product.store.slug,
                "store_logo_url": row.product.store.logo_url,
                "quantity": row.quantity,
                "stock": row.product.stock,
                "unit_price": float(row.product.price),
                "image_url": row.product.image_url,
            }
            for row in rows
        ],
    }


@app.get("/api/v1/cart")
def get_cart(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return cart_json(db, user)


@app.post("/api/v1/cart/items")
def add_cart_item(payload: CartItemInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    product = db.get(Product, payload.product_id)
    if not product or product.status != "ACTIVE" or product.store.status != "APPROVED":
        fail(status.HTTP_404_NOT_FOUND, "المنتج غير متاح")
    item = db.scalar(select(CartItem).where(CartItem.user_id == user.id, CartItem.product_id == product.id))
    new_quantity = payload.quantity + (item.quantity if item else 0)
    if new_quantity > product.stock:
        fail(status.HTTP_409_CONFLICT, "الكمية المطلوبة أكبر من المخزون")
    if item:
        item.quantity = new_quantity
    else:
        db.add(CartItem(user_id=user.id, product_id=product.id, quantity=payload.quantity))
    db.commit()
    return cart_json(db, user)


@app.patch("/api/v1/cart/items/{item_id}")
def update_cart_item(item_id: str, payload: CartItemInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    item = db.scalar(select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id))
    if not item:
        fail(status.HTTP_404_NOT_FOUND, "عنصر السلة غير موجود")
    if payload.quantity > item.product.stock:
        fail(status.HTTP_409_CONFLICT, "الكمية المطلوبة أكبر من المخزون")
    item.quantity = payload.quantity
    db.commit()
    return cart_json(db, user)


@app.delete("/api/v1/cart/items/{item_id}")
def remove_cart_item(item_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    item = db.scalar(select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id))
    if not item:
        fail(status.HTTP_404_NOT_FOUND, "عنصر السلة غير موجود")
    db.delete(item)
    db.commit()
    return cart_json(db, user)


@app.post("/api/v1/cart/checkout", status_code=201)
def checkout(payload: CheckoutInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    address = db.scalar(select(Address).where(Address.id == payload.address_id, Address.user_id == user.id))
    if not address:
        fail(status.HTTP_404_NOT_FOUND, "عنوان التوصيل غير موجود")
    rows = db.scalars(
        select(CartItem).options(joinedload(CartItem.product).joinedload(Product.store))
        .where(CartItem.user_id == user.id)
    ).all()
    if not rows:
        fail(status.HTTP_400_BAD_REQUEST, "السلة فارغة")
    if len(payload.store_notes) > 100 or any(len(note) > 1000 for note in payload.store_notes.values()):
        fail(status.HTTP_422_UNPROCESSABLE_ENTITY, "ملاحظة المتجر طويلة جدًا")
    product_ids = {row.product_id for row in rows}
    reserved_rows = db.execute(
        select(OrderItem.product_id, func.sum(OrderItem.quantity))
        .join(Order, Order.id == OrderItem.order_id)
        .where(Order.status == "PENDING", OrderItem.product_id.in_(product_ids))
        .group_by(OrderItem.product_id)
    ).all()
    reserved = {product_id: int(quantity) for product_id, quantity in reserved_rows}
    by_store: dict[str, list[CartItem]] = defaultdict(list)
    for row in rows:
        product = row.product
        if product.status != "ACTIVE" or product.store.status != "APPROVED":
            fail(status.HTTP_409_CONFLICT, f"المنتج {product.name} لم يعد متاحًا")
        available = product.stock - reserved.get(product.id, 0)
        if row.quantity > available:
            fail(status.HTTP_409_CONFLICT, f"المخزون غير كافٍ للمنتج {product.name}")
        by_store[product.store_id].append(row)
    coordinates = (
        f" ({address.latitude:.6f}, {address.longitude:.6f})"
        if address.latitude is not None and address.longitude is not None
        else ""
    )
    address_snapshot = f"{address.city}, {address.district}, {address.address_text}{coordinates} ? {address.phone}"
    orders: list[Order] = []
    try:
        for store_id, store_rows in by_store.items():
            subtotal = sum(
                (row.product.price * row.quantity for row in store_rows),
                start=Decimal("0.00"),
            ).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            fee = Decimal(str(settings.delivery_fee_lyd)).quantize(
                Decimal("0.01"), rounding=ROUND_HALF_UP
            )
            order = Order(
                user_id=user.id,
                store_id=store_id,
                address_id=address.id,
                delivery_address_snapshot=address_snapshot,
                customer_note=payload.store_notes.get(store_id, "").strip() or None,
                payment_method=payload.payment_method,
                status="PENDING",
                subtotal=subtotal,
                delivery_fee=fee,
                total=(subtotal + fee).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP),
            )
            db.add(order)
            db.flush()
            db.add(OrderStatusHistory(
                order_id=order.id, actor_id=user.id,
                old_status="", new_status="PENDING", note="تم إنشاء الطلب",
            ))
            for row in store_rows:
                product = row.product
                db.add(OrderItem(
                    order_id=order.id,
                    product_id=product.id,
                    product_name_snapshot=product.name,
                    unit_price=product.price,
                    quantity=row.quantity,
                ))
            orders.append(order)
        for row in rows:
            db.delete(row)
        db.commit()
    except Exception:
        db.rollback()
        raise
    for order in orders:
        db.refresh(order)
    return {"orders": [order_json(order) for order in orders]}


@app.get("/api/v1/orders/me")
def my_orders(db: Session = Depends(get_db), user: User = Depends(current_user)):
    orders = db.scalars(
        select(Order).options(joinedload(Order.items).joinedload(OrderItem.product), joinedload(Order.store))
        .where(Order.user_id == user.id).order_by(Order.created_at.desc())
    ).unique().all()
    return [order_json(order) for order in orders]


@app.post("/api/v1/orders/{order_id}/cancel")
def cancel_order(order_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    order = db.scalar(select(Order).where(Order.id == order_id, Order.user_id == user.id))
    if not order:
        fail(status.HTTP_404_NOT_FOUND, "الطلب غير موجود")
    if order.status != "PENDING":
        fail(status.HTTP_409_CONFLICT, "يمكن طلب الإلغاء قبل قبول المتجر فقط")
    old = order.status
    order.status = "CANCELLED"
    db.add(OrderStatusHistory(order_id=order.id, actor_id=user.id, old_status=old, new_status="CANCELLED"))
    db.commit()
    return order_json(order)


@app.get("/api/v1/vendor/orders")
def vendor_orders(db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = owned_store(db, user)
    orders = db.scalars(
        select(Order).options(joinedload(Order.items), joinedload(Order.store))
        .where(Order.store_id == store.id).order_by(Order.created_at.desc())
    ).unique().all()
    return [order_json(order) for order in orders]


@app.patch("/api/v1/vendor/orders/{order_id}/status")
def vendor_update_order(order_id: str, payload: OrderStatusInput, db: Session = Depends(get_db), user: User = Depends(current_user)):
    store = owned_store(db, user)
    order = db.scalar(select(Order).where(Order.id == order_id, Order.store_id == store.id))
    if not order:
        fail(status.HTTP_404_NOT_FOUND, "الطلب غير موجود في متجرك")
    allowed = {
        "PENDING": {"CONFIRMED", "CANCELLED"},
        "CONFIRMED": {"PREPARING", "CANCELLED"},
        "PREPARING": {"READY", "CANCELLED"},
        "READY": {"OUT_FOR_DELIVERY", "DELIVERED"},
        "OUT_FOR_DELIVERY": {"DELIVERED"},
    }
    if payload.status not in allowed.get(order.status, set()):
        fail(status.HTTP_409_CONFLICT, "تغيير حالة الطلب غير مسموح من الحالة الحالية")
    old_status = order.status
    if payload.status == "CONFIRMED":
        for item in order.items:
            product = db.get(Product, item.product_id)
            if not product or product.stock < item.quantity:
                fail(status.HTTP_409_CONFLICT, "لم تعد كمية أحد المنتجات متاحة")
        for item in order.items:
            product = db.get(Product, item.product_id)
            product.stock -= item.quantity
    order.status = payload.status
    if payload.status == "DELIVERED" and order.subtotal >= Decimal("20.00"):
        # Claim an eligible order exactly once in the same transaction as its point credit.
        claimed = db.execute(
            update(Order)
            .where(Order.id == order.id, Order.loyalty_awarded.is_(False))
            .values(loyalty_awarded=True)
        )
        if claimed.rowcount == 1:
            customer = db.get(User, order.user_id)
            if customer:
                customer.loyalty_half_points += 1  # 0.5 points, represented as one integer unit
    if payload.status == "CANCELLED" and old_status in {"CONFIRMED", "PREPARING"}:
        for item in order.items:
            product = db.get(Product, item.product_id)
            if product:
                product.stock += item.quantity
    db.add(OrderStatusHistory(
        order_id=order.id,
        actor_id=user.id,
        old_status=old_status,
        new_status=payload.status,
        note=payload.note,
    ))
    db.commit()
    db.refresh(order)
    return order_json(order)


@app.post("/api/v1/loyalty/redeem")
def redeem_loyalty_reward(db: Session = Depends(get_db), user: User = Depends(current_user)):
    # 200 integer half-point units equal exactly 100 points.
    result = db.execute(
        update(User)
        .where(User.id == user.id, User.loyalty_half_points >= 200)
        .values(
            loyalty_half_points=User.loyalty_half_points - 200,
            wallet_balance=User.wallet_balance + Decimal("5.00"),
        )
    )
    if result.rowcount != 1:
        db.rollback()
        fail(status.HTTP_409_CONFLICT, "Not enough points to redeem a reward")
    db.commit()
    db.refresh(user)
    return user_payload(user)


@app.get("/api/v1/admin/store-applications")
def admin_store_applications(
    status_filter: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    query = select(Store).order_by(Store.created_at.desc())
    if status_filter:
        query = query.where(Store.status == status_filter.upper())
    return [{**store_json(row), "review_note": row.review_note} for row in db.scalars(query).all()]


@app.patch("/api/v1/admin/stores/{store_id}/review")
def review_store(
    store_id: str,
    payload: ReviewDecision,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    store = db.get(Store, store_id)
    if not store:
        fail(status.HTTP_404_NOT_FOUND, "طلب المتجر غير موجود")
    store.status = payload.status
    store.review_note = payload.note
    db.add(AuditLog(
        actor_id=admin.id,
        action=f"STORE_{payload.status}",
        resource_type="store",
        resource_id=store.id,
        details=payload.note,
    ))
    db.commit()
    db.refresh(store)
    return {**store_json(store), "review_note": store.review_note, "reviewed_by": admin.id}


@app.post("/api/v1/admin/categories", status_code=201)
def admin_create_category(
    payload: CategoryInput,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    category = Category(**payload.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return {"id": category.id, "name": category.name, "slug": category.slug, "sort_order": category.sort_order}


@app.patch("/api/v1/admin/categories/{category_id}")
def admin_update_category(
    category_id: str,
    payload: CategoryInput,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    category = db.get(Category, category_id)
    if not category:
        fail(status.HTTP_404_NOT_FOUND, "التصنيف غير موجود")
    for key, value in payload.model_dump().items():
        setattr(category, key, value)
    db.commit()
    db.refresh(category)
    return {"id": category.id, "name": category.name, "slug": category.slug, "sort_order": category.sort_order}


@app.delete("/api/v1/admin/categories/{category_id}")
def admin_delete_category(
    category_id: str,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    category = db.get(Category, category_id)
    if not category:
        fail(status.HTTP_404_NOT_FOUND, "التصنيف غير موجود")
    category.is_active = False
    db.commit()
    return {"message": "تم إيقاف التصنيف"}


@app.post("/api/v1/admin/banners", status_code=201)
def admin_create_banner(
    payload: BannerInput,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    banner = Banner(**payload.model_dump())
    db.add(banner)
    db.commit()
    db.refresh(banner)
    return {"id": banner.id, **payload.model_dump()}


@app.patch("/api/v1/admin/banners/{banner_id}")
def admin_update_banner(
    banner_id: str,
    payload: BannerInput,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    banner = db.get(Banner, banner_id)
    if not banner:
        fail(status.HTTP_404_NOT_FOUND, "البانر غير موجود")
    for key, value in payload.model_dump().items():
        setattr(banner, key, value)
    db.commit()
    db.refresh(banner)
    return {"id": banner.id, **payload.model_dump()}


@app.delete("/api/v1/admin/banners/{banner_id}")
def admin_delete_banner(
    banner_id: str,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    banner = db.get(Banner, banner_id)
    if not banner:
        fail(status.HTTP_404_NOT_FOUND, "Banner not found")
    banner.is_active = False
    db.commit()
    return {"message": "Banner hidden"}


@app.get("/api/v1/admin/orders")
def admin_orders(db: Session = Depends(get_db), _admin: User = Depends(require_admin)):
    orders = db.scalars(
        select(Order).options(joinedload(Order.items), joinedload(Order.store))
        .order_by(Order.created_at.desc())
    ).unique().all()
    return [order_json(order) for order in orders]
