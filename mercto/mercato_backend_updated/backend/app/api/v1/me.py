from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.auth import get_current_user
from app.models.tenant import MemberStatus, Tenant, TenantMember, User
from app.schemas.tenant import TenantOut

router = APIRouter(prefix="/me", tags=["Me"])


@router.get("/tenants", response_model=list[TenantOut])
async def my_tenants(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Used by the Tenant Admin Dashboard right after login to let the
    user pick which store to manage (a user can be a member of more
    than one tenant)."""
    result = await db.execute(
        select(Tenant)
        .join(TenantMember, TenantMember.tenant_id == Tenant.id)
        .where(TenantMember.user_id == user.id, TenantMember.status == MemberStatus.ACTIVE)
    )
    return list(result.scalars().all())
