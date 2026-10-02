import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.tenant import TenantContext, require_tenant_role
from app.models.catalog import Product, ProductImage
from app.models.tenant import TenantRole
from app.services.audit import log_action
from app.services.storage import get_public_url, upload_image

router = APIRouter(prefix="/tenants/{tenant_id}/products/{product_id}/images", tags=["Product Images"])

_can_manage = require_tenant_role(TenantRole.OWNER_TENANT, TenantRole.ADMIN_TENANT)


@router.post("", status_code=status.HTTP_201_CREATED)
async def upload_product_image(
    product_id: uuid.UUID,
    file: UploadFile = File(...),
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    product = (
        await db.execute(select(Product).where(Product.id == product_id, Product.tenant_id == ctx.tenant_id))
    ).scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")

    object_key = await upload_image(file, folder=f"tenants/{ctx.tenant_id}/products/{product_id}")

    max_order = (
        await db.execute(select(func.max(ProductImage.sort_order)).where(ProductImage.product_id == product_id))
    ).scalar_one() or 0

    image = ProductImage(tenant_id=ctx.tenant_id, product_id=product_id, object_key=object_key, sort_order=max_order + 1)
    db.add(image)
    await log_action(db, action="PRODUCT_IMAGE_UPLOADED", entity_type="Product", entity_id=str(product_id), user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id)
    await db.commit()
    await db.refresh(image)

    return {"id": image.id, "url": get_public_url(object_key), "sort_order": image.sort_order}


@router.delete("/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product_image(
    product_id: uuid.UUID,
    image_id: uuid.UUID,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    image = (
        await db.execute(
            select(ProductImage).where(
                ProductImage.id == image_id, ProductImage.product_id == product_id, ProductImage.tenant_id == ctx.tenant_id
            )
        )
    ).scalar_one_or_none()
    if image is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")
    await db.delete(image)
    await db.commit()
