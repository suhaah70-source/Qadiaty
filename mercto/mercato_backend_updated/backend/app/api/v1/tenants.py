import secrets
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import hash_password
from app.deps.auth import get_current_super_admin
from app.models.tenant import (
    Contract,
    ContractStatus,
    MemberStatus,
    Plan,
    Tenant,
    TenantMember,
    TenantRole,
    TenantStatus,
    Theme,
    User,
)
from app.schemas.tenant import TenantCreateRequest, TenantOut, TenantStatusUpdate
from app.services.audit import log_action

router = APIRouter(prefix="/tenants", tags=["Tenants (Super Admin)"])


def _generate_code() -> str:
    return f"TEN-{secrets.token_hex(4).upper()}"


@router.post("", response_model=TenantOut, status_code=status.HTTP_201_CREATED)
async def create_tenant(
    payload: TenantCreateRequest,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    """UC-01: Super Admin creates a Tenant + owner + initial contract."""
    slug_exists = await db.execute(select(Tenant).where(Tenant.slug == payload.slug))
    if slug_exists.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="الرابط (slug) مستخدم مسبقا")

    plan = (await db.execute(select(Plan).where(Plan.id == payload.plan_id))).scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="الباقة غير موجودة")

    owner_exists = (await db.execute(select(User).where(User.email == payload.owner_email))).scalar_one_or_none()
    if owner_exists:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="بريد المالك مستخدم مسبقا")

    tenant = Tenant(code=_generate_code(), slug=payload.slug, name=payload.name, status=TenantStatus.PENDING)
    db.add(tenant)
    await db.flush()  # get tenant.id

    owner = User(email=payload.owner_email, name=payload.owner_name, password_hash=hash_password(payload.owner_password))
    db.add(owner)
    await db.flush()

    db.add(TenantMember(tenant_id=tenant.id, user_id=owner.id, role=TenantRole.OWNER_TENANT, status=MemberStatus.ACTIVE))
    db.add(
        Contract(
            tenant_id=tenant.id,
            plan_id=plan.id,
            start_at=datetime.now(timezone.utc).isoformat(),
            status=ContractStatus.ACTIVE,
            version=1,
        )
    )
    db.add(Theme(tenant_id=tenant.id))
    tenant.status = TenantStatus.ACTIVE

    await log_action(
        db, action="TENANT_CREATED", entity_type="Tenant", entity_id=str(tenant.id),
        user_id=admin.id, tenant_id=tenant.id, metadata={"slug": tenant.slug, "plan": plan.name},
    )

    await db.commit()
    await db.refresh(tenant)
    return tenant


@router.get("", response_model=list[TenantOut])
async def list_tenants(db: AsyncSession = Depends(get_db), admin: User = Depends(get_current_super_admin)):
    result = await db.execute(select(Tenant).order_by(Tenant.created_at.desc()))
    return list(result.scalars().all())


@router.patch("/{tenant_id}/status", response_model=TenantOut)
async def update_tenant_status(
    tenant_id: uuid.UUID,
    payload: TenantStatusUpdate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    """BR-06: only Super Admin can suspend/reactivate a tenant."""
    tenant = (await db.execute(select(Tenant).where(Tenant.id == tenant_id))).scalar_one_or_none()
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")

    old_status = tenant.status
    tenant.status = payload.status
    await log_action(
        db, action="TENANT_STATUS_CHANGED", entity_type="Tenant", entity_id=str(tenant.id),
        user_id=admin.id, tenant_id=tenant.id,
        metadata={"from": old_status.value, "to": payload.status.value},
    )
    await db.commit()
    await db.refresh(tenant)
    return tenant
