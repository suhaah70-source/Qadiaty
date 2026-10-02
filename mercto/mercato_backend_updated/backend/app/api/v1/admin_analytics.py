from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.auth import get_current_super_admin
from app.models.catalog import Product
from app.models.order import Order, OrderStatus
from app.models.tenant import Contract, ContractStatus, Tenant, TenantStatus, User

router = APIRouter(prefix="/admin", tags=["Super Admin Analytics"])


@router.get("/analytics")
async def platform_analytics(db: AsyncSession = Depends(get_db), admin: User = Depends(get_current_super_admin)):
    total_tenants = (await db.execute(select(func.count(Tenant.id)))).scalar_one()
    active_tenants = (
        await db.execute(select(func.count(Tenant.id)).where(Tenant.status == TenantStatus.ACTIVE))
    ).scalar_one()
    suspended_tenants = (
        await db.execute(select(func.count(Tenant.id)).where(Tenant.status == TenantStatus.SUSPENDED))
    ).scalar_one()
    active_contracts = (
        await db.execute(select(func.count(Contract.id)).where(Contract.status == ContractStatus.ACTIVE))
    ).scalar_one()
    total_products = (await db.execute(select(func.count(Product.id)))).scalar_one()
    total_orders = (await db.execute(select(func.count(Order.id)))).scalar_one()
    pending_orders = (
        await db.execute(select(func.count(Order.id)).where(Order.status == OrderStatus.PENDING))
    ).scalar_one()
    gross_merchandise_value = (
        await db.execute(select(func.coalesce(func.sum(Order.total), 0)).where(Order.status != OrderStatus.CANCELLED))
    ).scalar_one()

    return {
        "tenants": {"total": total_tenants, "active": active_tenants, "suspended": suspended_tenants},
        "contracts": {"active": active_contracts},
        "catalog": {"total_products": total_products},
        "orders": {"total": total_orders, "pending": pending_orders, "gross_merchandise_value": float(gross_merchandise_value)},
    }
