import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.tenant import TenantContext, require_tenant_role
from app.models.tenant import TenantRole, Theme
from app.schemas.tenant import ThemeOut, ThemeUpdateRequest
from app.services.audit import log_action

router = APIRouter(prefix="/tenants/{tenant_id}/theme", tags=["Theme"])

_can_manage = require_tenant_role(TenantRole.OWNER_TENANT, TenantRole.ADMIN_TENANT)


@router.get("", response_model=ThemeOut)
async def get_theme(ctx: TenantContext = Depends(_can_manage), db: AsyncSession = Depends(get_db)):
    theme = (await db.execute(select(Theme).where(Theme.tenant_id == ctx.tenant_id))).scalar_one()
    return theme


@router.patch("", response_model=ThemeOut)
async def update_theme(
    payload: ThemeUpdateRequest,
    ctx: TenantContext = Depends(_can_manage),
    db: AsyncSession = Depends(get_db),
):
    theme = (await db.execute(select(Theme).where(Theme.tenant_id == ctx.tenant_id))).scalar_one()
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(theme, field, value)

    await log_action(
        db, action="THEME_UPDATED", entity_type="Theme", entity_id=str(theme.id),
        user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id,
    )
    await db.commit()
    await db.refresh(theme)
    return theme
