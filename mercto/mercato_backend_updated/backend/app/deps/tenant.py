"""
Tenant Context resolution — the single most important security boundary
in this system (SRS §16 Multi-Tenancy & Data Isolation, BR-01..BR-03).

Rule enforced here: the active tenant for a request is derived from the
authenticated user's TenantMember row (their real membership), never
from a tenant_id the client puts in a header, query param, or body.
A path like `/tenants/{tenant_id}/products` still re-validates that the
caller is actually a member of `tenant_id` before returning anything.
"""
import uuid

from fastapi import Depends, HTTPException, Path, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.auth import get_current_user
from app.models.tenant import MemberStatus, Tenant, TenantMember, TenantRole, TenantStatus, User


class TenantContext:
    """Bundles the resolved tenant + the caller's role in it.
    Handlers depend on this instead of touching tenant_id directly,
    so isolation logic lives in exactly one place."""

    def __init__(self, tenant: Tenant, membership: TenantMember):
        self.tenant = tenant
        self.membership = membership

    @property
    def tenant_id(self) -> uuid.UUID:
        return self.tenant.id

    @property
    def role(self) -> TenantRole:
        return self.membership.role


async def get_tenant_context(
    tenant_id: uuid.UUID = Path(..., description="معرف المتجر المستهدف"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TenantContext:
    # Super admins can inspect any tenant (for moderation/support) but
    # every OTHER role must have an explicit, active membership row.
    tenant_result = await db.execute(select(Tenant).where(Tenant.id == tenant_id))
    tenant = tenant_result.scalar_one_or_none()
    if tenant is None:
        # Same 404 regardless of whether the tenant exists but the user
        # lacks access, or truly doesn't exist -- avoids leaking existence.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")

    if user.is_super_admin:
        # Synthesize a pseudo-membership so downstream code has a uniform shape.
        pseudo = TenantMember(tenant_id=tenant.id, user_id=user.id, role=TenantRole.OWNER_TENANT, status=MemberStatus.ACTIVE)
        return TenantContext(tenant=tenant, membership=pseudo)

    member_result = await db.execute(
        select(TenantMember).where(
            TenantMember.tenant_id == tenant_id,
            TenantMember.user_id == user.id,
            TenantMember.status == MemberStatus.ACTIVE,
        )
    )
    membership = member_result.scalar_one_or_none()
    if membership is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")

    if tenant.status not in (TenantStatus.ACTIVE, TenantStatus.PENDING):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="المتجر غير نشط حاليا")

    return TenantContext(tenant=tenant, membership=membership)


def require_tenant_role(*allowed_roles: TenantRole):
    """RBAC guard factory for tenant-scoped endpoints."""

    async def _checker(ctx: TenantContext = Depends(get_tenant_context)) -> TenantContext:
        if ctx.role not in allowed_roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="صلاحيات غير كافية")
        return ctx

    return _checker
