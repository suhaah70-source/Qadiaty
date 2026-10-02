import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.tenant import TenantContext, require_tenant_role
from app.models.catalog import Category
from app.models.tenant import TenantRole
from app.schemas.catalog import CategoryCreateRequest, CategoryOut
from app.services.audit import log_action

router = APIRouter(prefix="/tenants/{tenant_id}/categories", tags=["Categories"])

_can_manage = require_tenant_role(TenantRole.OWNER_TENANT, TenantRole.ADMIN_TENANT)


@router.get("", response_model=list[CategoryOut])
async def list_categories(ctx: TenantContext = Depends(_can_manage), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Category).where(Category.tenant_id == ctx.tenant_id))
    return list(result.scalars().all())


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreateRequest,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    exists = await db.execute(
        select(Category).where(Category.tenant_id == ctx.tenant_id, Category.slug == payload.slug)
    )
    if exists.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="الرابط مستخدم مسبقا داخل هذا المتجر")

    category = Category(tenant_id=ctx.tenant_id, name=payload.name, slug=payload.slug)
    db.add(category)
    await log_action(db, action="CATEGORY_CREATED", entity_type="Category", user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id)
    await db.commit()
    await db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: uuid.UUID,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    category = (
        await db.execute(select(Category).where(Category.id == category_id, Category.tenant_id == ctx.tenant_id))
    ).scalar_one_or_none()
    if category is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")
    await db.delete(category)
    await log_action(db, action="CATEGORY_DELETED", entity_type="Category", entity_id=str(category_id), user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id)
    await db.commit()
