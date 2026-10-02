from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import hash_password
from app.deps.tenant import TenantContext, require_tenant_role
from app.models.tenant import MemberStatus, TenantMember, TenantRole, User
from app.schemas.system import TeamInviteRequest, TeamMemberOut
from app.services.audit import log_action
from app.services.contract_policy import assert_can_add_admin

router = APIRouter(prefix="/tenants/{tenant_id}/team", tags=["Team"])

# Only the OWNER can manage who else administers the store.
_owner_only = require_tenant_role(TenantRole.OWNER_TENANT)


@router.get("", response_model=list[TeamMemberOut])
async def list_team(ctx: TenantContext = Depends(_owner_only), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(TenantMember, User)
        .join(User, User.id == TenantMember.user_id)
        .where(TenantMember.tenant_id == ctx.tenant_id, TenantMember.status == MemberStatus.ACTIVE)
    )
    return [
        TeamMemberOut(id=member.id, user_id=user.id, role=member.role, email=user.email, name=user.name)
        for member, user in result.all()
    ]


@router.post("", response_model=TeamMemberOut, status_code=status.HTTP_201_CREATED)
async def invite_team_member(
    payload: TeamInviteRequest,
    ctx: TenantContext = Depends(_owner_only),
    db: AsyncSession = Depends(get_db),
):
    # FR-23 + BR-04-equivalent for admin seats: enforce plan's max_admins.
    await assert_can_add_admin(db, ctx.tenant_id)

    existing = (await db.execute(select(User).where(User.email == payload.email))).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="البريد الإلكتروني مستخدم مسبقا")

    if payload.role == TenantRole.OWNER_TENANT:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="لا يمكن دعوة مالك إضافي بهذه الطريقة")

    new_user = User(email=payload.email, name=payload.name, password_hash=hash_password(payload.password))
    db.add(new_user)
    await db.flush()

    member = TenantMember(tenant_id=ctx.tenant_id, user_id=new_user.id, role=payload.role, status=MemberStatus.ACTIVE)
    db.add(member)

    await log_action(
        db, action="TEAM_MEMBER_INVITED", entity_type="TenantMember",
        user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id, metadata={"invited_email": payload.email},
    )
    await db.commit()
    await db.refresh(member)
    return TeamMemberOut(id=member.id, user_id=new_user.id, role=member.role, email=new_user.email, name=new_user.name)


@router.delete("/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_team_member(
    member_id,
    ctx: TenantContext = Depends(_owner_only),
    db: AsyncSession = Depends(get_db),
):
    member = (
        await db.execute(select(TenantMember).where(TenantMember.id == member_id, TenantMember.tenant_id == ctx.tenant_id))
    ).scalar_one_or_none()
    if member is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="غير موجود")
    if member.role == TenantRole.OWNER_TENANT:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="لا يمكن إزالة مالك المتجر")

    member.status = MemberStatus.REMOVED
    await log_action(
        db, action="TEAM_MEMBER_REMOVED", entity_type="TenantMember", entity_id=str(member_id),
        user_id=ctx.membership.user_id, tenant_id=ctx.tenant_id,
    )
    await db.commit()
