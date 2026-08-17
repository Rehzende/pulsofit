from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import joinedload
from app.api import deps
from app.db.session import get_db
from app.models.workout_group import WorkoutGroup
from app.models.user import User, UserRole
from app.schemas.workout_group import WorkoutGroupCreate, WorkoutGroupUpdate, WorkoutGroup as WorkoutGroupSchema
from uuid import UUID

router = APIRouter()


@router.get("/", response_model=List[WorkoutGroupSchema])
async def list_workout_groups(
    student_id: Optional[UUID] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    List workout groups.
    - Trainers: See all their groups, optionally filtered by student_id
    - Students: See groups that contain their workouts
    """
    if current_user.role == UserRole.TRAINER:
        # Trainers see all their groups (optionally filtered by student_id)
        query = (
            select(WorkoutGroup)
            .options(joinedload(WorkoutGroup.trainer).joinedload(User.trainer_profile))
            .filter(WorkoutGroup.trainer_id == current_user.id)
        )
        if student_id:
            query = query.filter(WorkoutGroup.student_id == student_id)

        query = query.order_by(WorkoutGroup.name)
        result = await db.execute(query)
    else:
        # Students see groups that:
        # 1. They created (trainer_id == student.id - unlikely but possible)
        # 2. Contain their workouts (Workout.user_id == student.id)
        # 3. Are explicitly assigned to them (student_id == student.id)
        from app.models.workout import Workout
        from sqlalchemy import or_

        result = await db.execute(
            select(WorkoutGroup)
            .options(joinedload(WorkoutGroup.trainer).joinedload(User.trainer_profile))
            .outerjoin(Workout, WorkoutGroup.id == Workout.group_id)
            .filter(
                or_(
                    WorkoutGroup.trainer_id == current_user.id,
                    Workout.user_id == current_user.id,
                    WorkoutGroup.student_id == current_user.id,  # Trainer-created folders for this student
                )
            )
            .distinct()
            .order_by(WorkoutGroup.name)
        )

    groups = result.unique().scalars().all()

    # Populate trainer_name from trainer_profile
    for group in groups:
        if group.trainer and group.trainer.trainer_profile:
            group.trainer_name = group.trainer.trainer_profile.brand_name

    return groups


@router.post("/", response_model=WorkoutGroupSchema)
async def create_workout_group(
    group_in: WorkoutGroupCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Create a new workout group.
    """
    # Check if group with same name already exists for this trainer and student
    result = await db.execute(
        select(WorkoutGroup)
        .filter(WorkoutGroup.trainer_id == current_user.id)
        .filter(WorkoutGroup.student_id == group_in.student_id)
        .filter(WorkoutGroup.name == group_in.name)
    )
    existing_group = result.scalars().first()
    if existing_group:
        raise HTTPException(status_code=400, detail="A group with this name already exists for this student")

    db_group = WorkoutGroup(
        name=group_in.name,
        student_id=group_in.student_id,
        start_date=group_in.start_date,
        end_date=group_in.end_date,
        trainer_id=current_user.id,
        is_active=True
    )
    db.add(db_group)
    await db.commit()
    await db.refresh(db_group, ["trainer"])
    # Load trainer_profile
    await db.refresh(db_group.trainer, ["trainer_profile"])
    if db_group.trainer and db_group.trainer.trainer_profile:
        db_group.trainer_name = db_group.trainer.trainer_profile.brand_name
    return db_group


@router.put("/{group_id}", response_model=WorkoutGroupSchema)
async def update_workout_group(
    group_id: UUID,
    group_in: WorkoutGroupUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Update a workout group.
    """
    result = await db.execute(
        select(WorkoutGroup)
        .options(joinedload(WorkoutGroup.trainer).joinedload(User.trainer_profile))
        .filter(WorkoutGroup.id == group_id)
        .filter(WorkoutGroup.trainer_id == current_user.id)
    )
    db_group = result.scalars().first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Workout group not found")

    if group_in.name is not None:
        # Check if new name conflicts with existing group
        result = await db.execute(
            select(WorkoutGroup)
            .filter(WorkoutGroup.trainer_id == current_user.id)
            .filter(WorkoutGroup.student_id == db_group.student_id)
            .filter(WorkoutGroup.name == group_in.name)
            .filter(WorkoutGroup.id != group_id)
        )
        existing_group = result.scalars().first()
        if existing_group:
            raise HTTPException(status_code=400, detail="A group with this name already exists for this student")

        db_group.name = group_in.name

    if group_in.student_id is not None:
        db_group.student_id = group_in.student_id

    if group_in.start_date is not None:
        db_group.start_date = group_in.start_date
    if group_in.end_date is not None:
        db_group.end_date = group_in.end_date

    await db.commit()
    await db.refresh(db_group)

    # Populate trainer_name from trainer_profile
    if db_group.trainer and db_group.trainer.trainer_profile:
        db_group.trainer_name = db_group.trainer.trainer_profile.brand_name

    return db_group


@router.patch("/{group_id}/archive", response_model=WorkoutGroupSchema)
async def archive_workout_group(
    group_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Archive a workout group (move to inactive).
    """
    result = await db.execute(
        select(WorkoutGroup)
        .options(joinedload(WorkoutGroup.trainer).joinedload(User.trainer_profile))
        .filter(WorkoutGroup.id == group_id)
        .filter(WorkoutGroup.trainer_id == current_user.id)
    )
    db_group = result.scalars().first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Workout group not found")

    db_group.is_active = False
    await db.commit()
    await db.refresh(db_group)

    # Populate trainer_name from trainer_profile
    if db_group.trainer and db_group.trainer.trainer_profile:
        db_group.trainer_name = db_group.trainer.trainer_profile.brand_name

    return db_group


@router.patch("/{group_id}/unarchive", response_model=WorkoutGroupSchema)
async def unarchive_workout_group(
    group_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Unarchive a workout group (move back to active).
    """
    result = await db.execute(
        select(WorkoutGroup)
        .options(joinedload(WorkoutGroup.trainer).joinedload(User.trainer_profile))
        .filter(WorkoutGroup.id == group_id)
        .filter(WorkoutGroup.trainer_id == current_user.id)
    )
    db_group = result.scalars().first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Workout group not found")

    db_group.is_active = True
    await db.commit()
    await db.refresh(db_group)

    # Populate trainer_name from trainer_profile
    if db_group.trainer and db_group.trainer.trainer_profile:
        db_group.trainer_name = db_group.trainer.trainer_profile.brand_name

    return db_group


@router.delete("/{group_id}")
async def delete_workout_group(
    group_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Delete a workout group. Workouts in this group will have their group_id set to NULL.
    """
    result = await db.execute(
        select(WorkoutGroup)
        .filter(WorkoutGroup.id == group_id)
        .filter(WorkoutGroup.trainer_id == current_user.id)
    )
    db_group = result.scalars().first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Workout group not found")

    await db.delete(db_group)
    await db.commit()
    return {"message": "Workout group deleted successfully"}
