from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.subscription_plan import SubscriptionPlan
from app.schemas.subscription_plan import SubscriptionPlan as PlanSchema, SubscriptionPlanCreate, SubscriptionPlanUpdate
from uuid import UUID

router = APIRouter()

# ─── Public: any logged-in trainer can list active plans ──────────────────────

@router.get("/public", response_model=List[PlanSchema])
async def list_public_plans(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Returns all active plans. Available to any authenticated user (TRAINER self-service)."""
    result = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.is_active == True)
    )
    return result.scalars().all()


# ─── Self-service: trainer requests a plan change ─────────────────────────────

@router.post("/request-change")
async def request_plan_change(
    plan_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Trainer self-service: applies plan change immediately.
    Can be adapted to a pending-approval workflow later.
    """
    if current_user.role not in (UserRole.TRAINER, UserRole.SUPER_ADMIN):
        raise HTTPException(status_code=403, detail="Only trainers can request a plan change")

    result = await db.execute(
        select(SubscriptionPlan).where(
            SubscriptionPlan.id == plan_id,
            SubscriptionPlan.is_active == True,
        )
    )
    plan = result.scalars().first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found or inactive")

    current_user.plan_id = plan.id
    await db.commit()
    await db.refresh(current_user)

    return {
        "message": f"Plan changed to '{plan.name}' successfully",
        "plan_id": str(plan.id),
    }


# ─── Admin only ───────────────────────────────────────────────────────────────

@router.get("/", response_model=List[PlanSchema])
async def read_plans(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    result = await db.execute(select(SubscriptionPlan).offset(skip).limit(limit))
    return result.scalars().all()


@router.post("/", response_model=PlanSchema)
async def create_plan(
    plan_in: SubscriptionPlanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    plan = SubscriptionPlan(**plan_in.dict())
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.put("/{plan_id}", response_model=PlanSchema)
async def update_plan(
    plan_id: UUID,
    plan_in: SubscriptionPlanUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    result = await db.execute(select(SubscriptionPlan).filter(SubscriptionPlan.id == plan_id))
    plan = result.scalars().first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    update_data = plan_in.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(plan, field, value)

    await db.commit()
    await db.refresh(plan)
    return plan
