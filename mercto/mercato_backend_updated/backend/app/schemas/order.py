import uuid
from typing import Optional

from pydantic import BaseModel, Field

from app.models.order import OrderStatus
from app.schemas.catalog import CategoryOut, ProductOut
from app.schemas.tenant import ThemeOut


class AddToCartRequest(BaseModel):
    product_id: uuid.UUID
    quantity: int = Field(gt=0, default=1)


class CartItemOut(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    quantity: int
    unit_price: float

    class Config:
        from_attributes = True


class CartOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    items: list[CartItemOut]

    class Config:
        from_attributes = True


class CheckoutRequest(BaseModel):
    address_id: Optional[uuid.UUID] = None
    delivery_fee: float = Field(ge=0, default=0)


class OrderItemOut(BaseModel):
    product_id: uuid.UUID
    product_name_snapshot: str
    unit_price: float
    quantity: int

    class Config:
        from_attributes = True


class OrderOut(BaseModel):
    id: uuid.UUID
    status: OrderStatus
    subtotal: float
    delivery_fee: float
    total: float
    items: list[OrderItemOut]

    class Config:
        from_attributes = True


class OrderStatusUpdateRequest(BaseModel):
    status: OrderStatus


class PublicStoreOut(BaseModel):
    """Response for GET /stores/{slug} — what the customer app renders
    as the 'store world' (SRS §33 Dynamic Theme)."""
    tenant_id: uuid.UUID
    slug: str
    name: str
    theme: ThemeOut
    categories: list[CategoryOut]
    products: list[ProductOut]
