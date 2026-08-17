from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from app.api import deps
from app.db.session import get_db
from app.models.exercise import ExerciseGroup, ExerciseGroupItem, ExerciseLibrary
from app.models.user import User, UserRole
from app.schemas.exercise import (
    ExerciseGroupCreate, ExerciseGroupUpdate, ExerciseGroupOut,
    ExerciseGroupItemCreate, ExerciseGroupItemUpdate, ExerciseGroupItemOut,
)
from uuid import UUID

router = APIRouter()

def _require_trainer(current_user: User) -> None:
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Not enough permissions")

@router.get("/", response_model=List[ExerciseGroupOut])
async def list_exercise_groups(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)
    result = await db.execute(
        select(ExerciseGroup)
        .where(ExerciseGroup.trainer_id == current_user.id)
        .options(
            selectinload(ExerciseGroup.items).selectinload(ExerciseGroupItem.exercise)
        )
        .order_by(ExerciseGroup.name)
    )
    return result.scalars().all()

@router.post("/", response_model=ExerciseGroupOut)
async def create_exercise_group(
    group_in: ExerciseGroupCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)
    group = ExerciseGroup(
        trainer_id=current_user.id,
        name=group_in.name,
        description=group_in.description,
    )
    db.add(group)
    await db.commit()
    await db.refresh(group)
    # reload with items relationship
    result = await db.execute(
        select(ExerciseGroup)
        .where(ExerciseGroup.id == group.id)
        .options(selectinload(ExerciseGroup.items).selectinload(ExerciseGroupItem.exercise))
    )
    return result.scalars().first()

@router.get("/{group_id}", response_model=ExerciseGroupOut)
async def get_exercise_group(
    group_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)
    result = await db.execute(
        select(ExerciseGroup)
        .where(ExerciseGroup.id == group_id, ExerciseGroup.trainer_id == current_user.id)
        .options(selectinload(ExerciseGroup.items).selectinload(ExerciseGroupItem.exercise))
    )
    group = result.scalars().first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    return group

@router.put("/{group_id}", response_model=ExerciseGroupOut)
async def update_exercise_group(
    group_id: UUID,
    group_in: ExerciseGroupUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)
    result = await db.execute(
        select(ExerciseGroup).where(ExerciseGroup.id == group_id, ExerciseGroup.trainer_id == current_user.id)
    )
    group = result.scalars().first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    if group_in.name is not None:
        group.name = group_in.name
    if group_in.description is not None:
        group.description = group_in.description

    await db.commit()

    result = await db.execute(
        select(ExerciseGroup)
        .where(ExerciseGroup.id == group_id)
        .options(selectinload(ExerciseGroup.items).selectinload(ExerciseGroupItem.exercise))
    )
    return result.scalars().first()

@router.delete("/{group_id}")
async def delete_exercise_group(
    group_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)
    result = await db.execute(
        select(ExerciseGroup).where(ExerciseGroup.id == group_id, ExerciseGroup.trainer_id == current_user.id)
    )
    group = result.scalars().first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    await db.delete(group)
    await db.commit()
    return {"ok": True}

@router.post("/{group_id}/items", response_model=ExerciseGroupItemOut)
async def add_item_to_group(
    group_id: UUID,
    item_in: ExerciseGroupItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)

    group_result = await db.execute(
        select(ExerciseGroup).where(ExerciseGroup.id == group_id, ExerciseGroup.trainer_id == current_user.id)
    )
    if not group_result.scalars().first():
        raise HTTPException(status_code=404, detail="Group not found")

    exercise_result = await db.execute(
        select(ExerciseLibrary).where(ExerciseLibrary.id == item_in.exercise_id)
    )
    if not exercise_result.scalars().first():
        raise HTTPException(status_code=404, detail="Exercise not found")

    item = ExerciseGroupItem(
        group_id=group_id,
        exercise_id=item_in.exercise_id,
        order_index=item_in.order_index,
        sets=item_in.sets,
        reps_min=item_in.reps_min,
        reps_max=item_in.reps_max,
        duration_seconds=item_in.duration_seconds,
        rest_seconds=item_in.rest_seconds,
    )
    db.add(item)
    await db.commit()

    result = await db.execute(
        select(ExerciseGroupItem)
        .where(ExerciseGroupItem.id == item.id)
        .options(selectinload(ExerciseGroupItem.exercise))
    )
    return result.scalars().first()

@router.put("/{group_id}/items/{item_id}", response_model=ExerciseGroupItemOut)
async def update_group_item(
    group_id: UUID,
    item_id: UUID,
    item_in: ExerciseGroupItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)

    group_result = await db.execute(
        select(ExerciseGroup).where(ExerciseGroup.id == group_id, ExerciseGroup.trainer_id == current_user.id)
    )
    if not group_result.scalars().first():
        raise HTTPException(status_code=404, detail="Group not found")

    result = await db.execute(
        select(ExerciseGroupItem).where(ExerciseGroupItem.id == item_id, ExerciseGroupItem.group_id == group_id)
    )
    item = result.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    for field in ("order_index", "sets", "reps_min", "reps_max", "duration_seconds", "rest_seconds"):
        val = getattr(item_in, field)
        if val is not None:
            setattr(item, field, val)

    await db.commit()

    result = await db.execute(
        select(ExerciseGroupItem)
        .where(ExerciseGroupItem.id == item_id)
        .options(selectinload(ExerciseGroupItem.exercise))
    )
    return result.scalars().first()

@router.delete("/{group_id}/items/{item_id}")
async def remove_item_from_group(
    group_id: UUID,
    item_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    _require_trainer(current_user)

    group_result = await db.execute(
        select(ExerciseGroup).where(ExerciseGroup.id == group_id, ExerciseGroup.trainer_id == current_user.id)
    )
    if not group_result.scalars().first():
        raise HTTPException(status_code=404, detail="Group not found")

    result = await db.execute(
        select(ExerciseGroupItem).where(ExerciseGroupItem.id == item_id, ExerciseGroupItem.group_id == group_id)
    )
    item = result.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    await db.delete(item)
    await db.commit()
    return {"ok": True}
