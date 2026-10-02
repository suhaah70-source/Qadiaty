import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.auth import get_current_user
from app.models.catalog import Product, ProductStatus
from app.models.order import Cart, CartItem, CartStatus
from app.models.tenant import Tenant, TenantStatus, User
from app.schemas.order import AddToCartRequest, CartOut

router = APIRouter(prefix="/cart", tags=["Cart"])


async def _get_or_create_open_cart(db: AsyncSession, customer_id: uuid.UUID, tenant_id: uuid.UUID) -> Cart:
    result = await db.execute(
        select(Cart).where(Cart.customer_id == customer_id, Cart.tenant_id == tenant_id, Cart.status == CartStatus.OPEN)
    )
    cart = result.scalar_one_or_none()
    if cart is None:
        cart = Cart(customer_id=customer_id, tenant_id=tenant_id, status=CartStatus.OPEN)
        db.add(cart)
        await db.flush()
    return cart


@router.post("/{tenant_id}/items", response_model=CartOut)
async def add_item(
    tenant_id: uuid.UUID,
    payload: AddToCartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """MVP rule (SRS §35): cart is single-tenant. Adding a product from a
    different tenant means adding it to a different cart (tenant_id in path)."""
    tenant = (await db.execute(select(Tenant).where(Tenant.id == tenant_id, Tenant.status == TenantStatus.ACTIVE))).scalar_one_or_none()
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المتجر غير متاح")

    product = (
        await db.execute(
            select(Product).where(Product.id == payload.product_id, Product.tenant_id == tenant_id, Product.status == ProductStatus.ACTIVE)
        )
    ).scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المنتج غير متاح")
    if payload.quantity > product.stock:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="الكمية المطلوبة أكبر من المتوفر في المخزون")

    cart = await _get_or_create_open_cart(db, user.id, tenant_id)

    existing_item = next((i for i in (await db.execute(select(CartItem).where(CartItem.cart_id == cart.id))).scalars() if i.product_id == product.id), None)
    if existing_item:
        existing_item.quantity += payload.quantity
    else:
        db.add(CartItem(cart_id=cart.id, product_id=product.id, quantity=payload.quantity, unit_price=product.price))

    await db.commit()
    result = await db.execute(select(Cart).where(Cart.id == cart.id))
    return result.scalar_one()


@router.get("/{tenant_id}", response_model=CartOut)
async def get_cart(tenant_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    cart = await _get_or_create_open_cart(db, user.id, tenant_id)
    await db.commit()
    return cart


@router.delete("/{tenant_id}/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_item(
    tenant_id: uuid.UUID,
    item_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cart = await _get_or_create_open_cart(db, user.id, tenant_id)
    item = (await db.execute(select(CartItem).where(CartItem.id == item_id, CartItem.cart_id == cart.id))).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")
    await db.delete(item)
    await db.commit()
