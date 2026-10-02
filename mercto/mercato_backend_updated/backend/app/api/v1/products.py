import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.tenant import TenantContext, require_tenant_role
from app.models.catalog import Product
from app.models.tenant import TenantRole
from app.schemas.catalog import ProductCreateRequest, ProductOut, ProductUpdateRequest
from app.services.audit import log_action
from app.services.contract_policy import assert_can_create_product

router = APIRouter(prefix="/tenants/{tenant_id}/products", tags=["Products"])

_can_manage = require_tenant_role(TenantRole.OWNER_TENANT, TenantRole.ADMIN_TENANT)


@router.get("", response_model=list[ProductOut])
async def list_products(ctx: TenantContext = Depends(_can_manage), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Product).where(Product.tenant_id == ctx.tenant_id))
    return list(result.scalars().all())


@router.post("", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
async def create_product(
    payload: ProductCreateRequest,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    # UC-07 / BR-04: enforce plan limit in the backend before insert.
    await assert_can_create_product(db, ctx.tenant_id)

    sku_exists = await db.execute(select(Product).where(Product.tenant_id == ctx.tenant_id, Product.sku == payload.sku))
    if sku_exists.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="رمز المنتج (SKU) مستخدم مسبقا في هذا المتجر")

    product = Product(tenant_id=ctx.tenant_id, **payload.model_dump())
    db.add(product)
    await log_action(db, action="PRODUCT_CREATED", entity_type="Product", user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id)
    await db.commit()
    await db.refresh(product)
    return product


@router.patch("/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: uuid.UUID,
    payload: ProductUpdateRequest,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    product = (
        await db.execute(select(Product).where(Product.id == product_id, Product.tenant_id == ctx.tenant_id))
    ).scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(product, field, value)

    await log_action(db, action="PRODUCT_UPDATED", entity_type="Product", entity_id=str(product_id), user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id)
    await db.commit()
    await db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    product_id: uuid.UUID,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    product = (
        await db.execute(select(Product).where(Product.id == product_id, Product.tenant_id == ctx.tenant_id))
    ).scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")
    await db.delete(product)
    await log_action(db, action="PRODUCT_DELETED", entity_type="Product", entity_id=str(product_id), user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id)
    await db.commit()
