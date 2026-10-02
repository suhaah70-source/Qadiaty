from pydantic import BaseModel, Field, field_validator
from decimal import Decimal


class OTPRequest(BaseModel):
    phone: str


class OTPVerify(BaseModel):
    phone: str
    code: str = Field(min_length=6, max_length=6)
    full_name: str | None = Field(default=None, max_length=120)
    city: str | None = Field(default=None, max_length=80)
    password: str | None = Field(default=None, min_length=8, max_length=128)
    terms_accepted: bool = False
    invite_code: str | None = Field(default=None, max_length=80)


class PasswordLogin(BaseModel):
    phone: str
    password: str = Field(min_length=8, max_length=128)


class PasswordReset(BaseModel):
    phone: str
    code: str = Field(min_length=6, max_length=6)
    new_password: str = Field(min_length=8, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str


class StoreApplicationInput(BaseModel):
    name: str = Field(min_length=2, max_length=140)
    slug: str | None = Field(default=None, min_length=2, max_length=100)
    description: str | None = None
    city: str = Field(min_length=2, max_length=80)
    store_category: str = Field(default="general", pattern=r"^(clothing|shoes|pharmacy|electronics|home|beauty|grocery|general)$")

    @field_validator("slug")
    @classmethod
    def validate_unicode_slug(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = "-".join(part for part in value.strip().lower().split() if part)
        if not value or any(not (char.isalnum() or char == "-") for char in value):
            raise ValueError("Store link may contain Arabic or Latin letters, numbers and hyphens")
        return value


class StoreUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=140)
    description: str | None = None
    logo_url: str | None = None
    banner_url: str | None = None
    primary_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    secondary_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    background_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    text_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    store_category: str | None = Field(default=None, pattern=r"^(clothing|shoes|pharmacy|electronics|home|beauty|grocery|general)$")
    product_image_shape: str | None = Field(default=None, pattern=r"^(rounded|square|circle|portrait|triangle|diamond)$")
    product_image_scale: float | None = Field(default=None, ge=0.5, le=1)
    show_product_card: bool | None = None
    background_image_url: str | None = None
    background_image_fit: str | None = Field(default=None, pattern=r"^(cover|contain)$")
    background_overlay_opacity: float | None = Field(default=None, ge=0, le=0.85)
    background_style: str | None = Field(default=None, pattern=r"^(solid|gradient|image|blend)$")
    background_gradient_start: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    background_gradient_end: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    accent_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    card_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    controls_x: float | None = Field(default=None, ge=0, le=1)
    controls_y: float | None = Field(default=None, ge=0, le=1)
    logo_position: str | None = Field(default=None, pattern=r"^(topLeft|topCenter|topRight|centerLeft|center|centerRight|bottomLeft|bottomCenter|bottomRight)$")


class ProductInput(BaseModel):
    name: str = Field(min_length=2, max_length=180)
    description: str | None = None
    sku: str = Field(min_length=1, max_length=80)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    stock: int = Field(ge=0)
    category_id: str | None = None
    image_url: str | None = None


class ReviewDecision(BaseModel):
    status: str = Field(pattern=r"^(APPROVED|REJECTED|SUSPENDED)$")
    note: str | None = None


class CategoryInput(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    slug: str = Field(min_length=2, max_length=120)
    sort_order: int = 0

    @field_validator("slug")
    @classmethod
    def validate_unicode_slug(cls, value: str) -> str:
        value = "-".join(part for part in value.strip().lower().split() if part)
        if not value or any(not (char.isalnum() or char == "-") for char in value):
            raise ValueError("Category link may contain Arabic or Latin letters, numbers and hyphens")
        return value


class BannerInput(BaseModel):
    title: str = Field(min_length=2, max_length=140)
    image_url: str = Field(min_length=5, max_length=500)
    target_url: str | None = None
    sort_order: int = 0
    is_active: bool = True


class AddressInput(BaseModel):
    city: str = Field(min_length=2, max_length=80)
    district: str = Field(min_length=2, max_length=120)
    address_text: str = Field(min_length=5)
    phone: str = Field(min_length=8, max_length=20)
    is_default: bool = False
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class CartItemInput(BaseModel):
    product_id: str
    quantity: int = Field(ge=1, le=100)


class CheckoutInput(BaseModel):
    address_id: str
    payment_method: str = Field(default="CASH_ON_DELIVERY", pattern=r"^CASH_ON_DELIVERY$")
    store_notes: dict[str, str] = Field(default_factory=dict)


class OrderStatusInput(BaseModel):
    status: str = Field(pattern=r"^(CONFIRMED|PREPARING|READY|OUT_FOR_DELIVERY|DELIVERED|CANCELLED)$")
    note: str | None = None
