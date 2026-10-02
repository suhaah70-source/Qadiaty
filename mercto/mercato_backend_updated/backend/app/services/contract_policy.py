"""
Contract/Plan enforcement service.
Per SRS §18: "Backend rejects the operation with a clear message when a
limit is exceeded" -- limits must NEVER be enforced only by hiding a
button in the dashboard.
"""
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.catalog import Product
from app.models.tenant import Contract, ContractStatus, Plan, TenantMember


async def _get_active_contract(db: AsyncSession, tenant_id: uuid.UUID) -> Contract:
    result = await db.execute(
        select(Contract)
        .where(Contract.tenant_id == tenant_id, Contract.status == ContractStatus.ACTIVE)
        .order_by(Contract.version.desc())
    )
    contract = result.scalars().first()
    if contract is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="لا يوجد عقد نشط لهذا المتجر، لا يمكن تنفيذ هذه العملية",
        )
    return contract


async def assert_can_create_product(db: AsyncSession, tenant_id: uuid.UUID) -> None:
    contract = await _get_active_contract(db, tenant_id)
    plan_result = await db.execute(select(Plan).where(Plan.id == contract.plan_id))
    plan = plan_result.scalar_one()

    count_result = await db.execute(select(func.count(Product.id)).where(Product.tenant_id == tenant_id))
    current_count = count_result.scalar_one()

    if current_count >= plan.max_products:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"تم بلوغ الحد الأقصى لعدد المنتجات في باقتك ({plan.max_products}). يرجى ترقية الباقة.",
        )


async def assert_can_add_admin(db: AsyncSession, tenant_id: uuid.UUID) -> None:
    contract = await _get_active_contract(db, tenant_id)
    plan_result = await db.execute(select(Plan).where(Plan.id == contract.plan_id))
    plan = plan_result.scalar_one()

    count_result = await db.execute(select(func.count(TenantMember.id)).where(TenantMember.tenant_id == tenant_id))
    current_count = count_result.scalar_one()

    if current_count >= plan.max_admins:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"تم بلوغ الحد الأقصى لعدد المستخدمين في باقتك ({plan.max_admins}).",
        )
