from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps.auth import get_current_super_admin
from app.models.tenant import Plan, User
from app.schemas.tenant import PlanCreateRequest, PlanOut

router = APIRouter(prefix="/plans", tags=["Plans (Super Admin)"])


@router.post("", response_model=PlanOut, status_code=status.HTTP_201_CREATED)
async def create_plan(
    payload: PlanCreateRequest,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    plan = Plan(**payload.model_dump())
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.get("", response_model=list[PlanOut])
async def list_plans(db: AsyncSession = Depends(get_db), admin: User = Depends(get_current_super_admin)):
    result = await db.execute(select(Plan))
    return list(result.scalars().all())
