import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.auth import get_current_user
from app.deps.tenant import TenantContext, require_tenant_role
from app.models.catalog import Product
from app.models.order import Cart, CartItem, CartStatus, Order, OrderItem, OrderStatus
from app.models.system import Notification
from app.models.tenant import Tenant, TenantMember, TenantRole, TenantStatus, User
from app.schemas.order import CheckoutRequest, OrderOut, OrderStatusUpdateRequest
from app.services.audit import log_action

router = APIRouter(tags=["Orders"])


@router.post("/cart/{tenant_id}/checkout", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
async def checkout(
    tenant_id: uuid.UUID,
    payload: CheckoutRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """UC-05: create order from cart. BR-09: stock is validated and
    decremented inside one DB transaction to avoid race conditions
    (two customers buying the last unit at the same time)."""
    tenant = (await db.execute(select(Tenant).where(Tenant.id == tenant_id, Tenant.status == TenantStatus.ACTIVE))).scalar_one_or_none()
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المتجر غير متاح")

    cart = (
        await db.execute(select(Cart).where(Cart.customer_id == user.id, Cart.tenant_id == tenant_id, Cart.status == CartStatus.OPEN))
    ).scalar_one_or_none()
    if cart is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="السلة فارغة")

    items = (await db.execute(select(CartItem).where(CartItem.cart_id == cart.id))).scalars().all()
    if not items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="السلة فارغة")

    subtotal = 0.0
    order_items: list[OrderItem] = []

    # Lock + validate + decrement stock atomically.
    for item in items:
        product = (
            await db.execute(select(Product).where(Product.id == item.product_id, Product.tenant_id == tenant_id).with_for_update())
        ).scalar_one_or_none()
        if product is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="أحد المنتجات لم يعد متاحا")
        if item.quantity > product.stock:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"الكمية غير متوفرة للمنتج: {product.name}")

        product.stock -= item.quantity  # BR-01: order can never create negative stock
        line_total = item.unit_price * item.quantity
        subtotal += line_total
        order_items.append(
            OrderItem(
                product_id=product.id,
                product_name_snapshot=product.name,  # BR-08 snapshot
                unit_price=item.unit_price,
                quantity=item.quantity,
            )
        )

    total = subtotal + payload.delivery_fee
    order = Order(
        tenant_id=tenant_id,
        customer_id=user.id,
        status=OrderStatus.PENDING,
        subtotal=subtotal,
        delivery_fee=payload.delivery_fee,
        total=total,
        address_id=payload.address_id,
        items=order_items,
    )
    db.add(order)
    cart.status = CartStatus.CHECKED_OUT

    # Notify tenant owners/admins of the new order.
    tenant_admins = (await db.execute(select(TenantMember).where(TenantMember.tenant_id == tenant_id))).scalars().all()
    for member in tenant_admins:
        db.add(
            Notification(
                user_id=member.user_id,
                tenant_id=tenant_id,
                type="NEW_ORDER",
                title="طلب جديد",
                body=f"وصل طلب جديد بقيمة {total}",
            )
        )

    await log_action(db, action="ORDER_CREATED", entity_type="Order", user_id=user.id, tenant_id=tenant_id)
    await db.commit()
    await db.refresh(order)
    return order


@router.get("/orders/me", response_model=list[OrderOut])
async def my_orders(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Order).where(Order.customer_id == user.id).order_by(Order.created_at.desc()))
    return list(result.scalars().all())


_can_manage_orders = require_tenant_role(TenantRole.OWNER_TENANT, TenantRole.ADMIN_TENANT)


@router.get("/tenants/{tenant_id}/orders", response_model=list[OrderOut], tags=["Orders (Tenant Admin)"])
async def list_tenant_orders(ctx: TenantContext = Depends(_can_manage_orders), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Order).where(Order.tenant_id == ctx.tenant_id).order_by(Order.created_at.desc()))
    return list(result.scalars().all())


@router.patch("/tenants/{tenant_id}/orders/{order_id}/status", response_model=OrderOut, tags=["Orders (Tenant Admin)"])
async def update_order_status(
    order_id: uuid.UUID,
    payload: OrderStatusUpdateRequest,
    ctx: TenantContext = Depends(_can_manage_orders),
    db: AsyncSession = Depends(get_db),
):
    """UC-06: tenant admin updates order status; customer is notified."""
    order = (await db.execute(select(Order).where(Order.id == order_id, Order.tenant_id == ctx.tenant_id))).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")

    order.status = payload.status
    db.add(
        Notification(
            user_id=order.customer_id,
            tenant_id=ctx.tenant_id,
            type="ORDER_STATUS_CHANGED",
            title="تحديث حالة الطلب",
            body=f"أصبحت حالة طلبك: {payload.status.value}",
        )
    )
    await log_action(
        db, action="ORDER_STATUS_UPDATED", entity_type="Order", entity_id=str(order_id),
        user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id, metadata={"status": payload.status.value},
    )
    await db.commit()
    await db.refresh(order)
    return order
