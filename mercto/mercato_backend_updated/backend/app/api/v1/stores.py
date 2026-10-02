from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.catalog import Category, CategoryStatus, Product, ProductStatus
from app.models.tenant import Tenant, TenantStatus, Theme
from app.schemas.catalog import ProductOut
from app.schemas.order import PublicStoreOut
from app.schemas.tenant import TenantOut

router = APIRouter(prefix="/stores", tags=["Public Stores"])


@router.get("", response_model=list[TenantOut])
async def list_active_stores(
    q: Optional[str] = Query(default=None, description="بحث باسم المتجر"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Public store discovery for the customer app Home screen (§32)."""
    query = select(Tenant).where(Tenant.status == TenantStatus.ACTIVE)
    if q:
        query = query.where(Tenant.name.ilike(f"%{q}%"))
    query = query.order_by(Tenant.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return list(result.scalars().all())


@router.get("/{slug}", response_model=PublicStoreOut)
async def get_store(slug: str, db: AsyncSession = Depends(get_db)):
    """Public, unauthenticated endpoint the customer app calls when a
    shopper opens a store: returns the ACTIVE tenant's theme + published
    categories/products only (BR-07: unpublished products never appear)."""
    tenant = (
        await db.execute(select(Tenant).where(Tenant.slug == slug, Tenant.status == TenantStatus.ACTIVE))
    ).scalar_one_or_none()
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المتجر غير موجود أو غير نشط")

    theme = (await db.execute(select(Theme).where(Theme.tenant_id == tenant.id))).scalar_one()
    categories = (
        await db.execute(select(Category).where(Category.tenant_id == tenant.id, Category.status == CategoryStatus.ACTIVE))
    ).scalars().all()
    products = (
        await db.execute(select(Product).where(Product.tenant_id == tenant.id, Product.status == ProductStatus.ACTIVE))
    ).scalars().all()

    return PublicStoreOut(
        tenant_id=tenant.id,
        slug=tenant.slug,
        name=tenant.name,
        theme=theme,
        categories=list(categories),
        products=list(products),
    )


@router.get("/{slug}/products/search", response_model=list[ProductOut])
async def search_store_products(
    slug: str,
    q: Optional[str] = Query(default=None, description="نص البحث في اسم المنتج"),
    category_id: Optional[str] = Query(default=None),
    min_price: Optional[float] = Query(default=None, ge=0),
    max_price: Optional[float] = Query(default=None, ge=0),
    in_stock_only: bool = Query(default=False),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """FR-15 / §36: search + filters (name, category, price range,
    availability) with pagination -- always required per NFR-02."""
    tenant = (
        await db.execute(select(Tenant).where(Tenant.slug == slug, Tenant.status == TenantStatus.ACTIVE))
    ).scalar_one_or_none()
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المتجر غير موجود أو غير نشط")

    query = select(Product).where(Product.tenant_id == tenant.id, Product.status == ProductStatus.ACTIVE)
    if q:
        query = query.where(Product.name.ilike(f"%{q}%"))
    if category_id:
        query = query.where(Product.category_id == category_id)
    if min_price is not None:
        query = query.where(Product.price >= min_price)
    if max_price is not None:
        query = query.where(Product.price <= max_price)
    if in_stock_only:
        query = query.where(Product.stock > 0)

    query = query.order_by(Product.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return list(result.scalars().all())
