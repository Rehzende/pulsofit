from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from app.api import deps
from app.db.session import get_db
from app.models.user import User
from app.models.workout import Workout, WorkoutItem
from app.models.exercise import ExerciseLibrary
from app.models.workout_template import WorkoutTemplate, WorkoutTemplateItem
from app.data.workout_templates import get_all_templates, get_template_by_id, get_templates_by_program
from app.schemas.workout_template import (
    WorkoutTemplateCreate,
    WorkoutTemplateUpdate,
    WorkoutTemplate as WorkoutTemplateSchema,
    ApplyTemplateRequest,
)
from app.schemas.workout import Workout as WorkoutSchema
import uuid

router = APIRouter()


@router.get("/")
async def list_templates(
    goal: str | None = None,
    level: str | None = None,
    equipment: str | None = None,
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    List all available workout templates.
    Optionally filter by goal, level or equipment.
    """
    templates = get_all_templates()

    if goal:
        templates = [t for t in templates if goal.lower() in t["goal"].lower()]
    if level:
        templates = [t for t in templates if level.lower() in t["level"].lower()]
    if equipment:
        templates = [t for t in templates if equipment.lower() in t["equipment"].lower()]

    return templates


@router.get("/by-program")
async def list_templates_by_program(
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """List templates grouped by program name."""
    return get_templates_by_program()


# ============================================================================
# DB-BACKED TRAINER TEMPLATES (WT-2)
# ============================================================================

@router.get("/my")
async def list_my_templates(
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> List[WorkoutTemplateSchema]:
    """List workout templates created by the current trainer (paginated)."""
    result = await db.execute(
        select(WorkoutTemplate)
        .options(selectinload(WorkoutTemplate.items).selectinload(WorkoutTemplateItem.exercise))
        .filter(WorkoutTemplate.trainer_id == current_user.id)
        .order_by(WorkoutTemplate.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


# NOTE: Removed duplicate GET /{template_id} route - use get_my_template() below instead


@router.post("/{template_id}/import")
async def import_template(
    template_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Import a workout template as real workouts for the current user.
    Creates one Workout per exercise day in the template.
    Matches exercises by name (case-insensitive) from the exercise library.
    Returns list of created workout IDs.
    """
    # Check AI terms accepted
    if not current_user.accepted_ai_terms_at:
        raise HTTPException(
            status_code=403,
            detail="Você precisa aceitar os Termos de Uso antes de importar treinos.",
        )

    template = get_template_by_id(template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Create one workout from this template day
    workout = Workout(
        name=template["name"],
        user_id=current_user.id,
    )
    db.add(workout)
    await db.flush()  # get workout.id

    # Match exercises by name
    exercise_names = [ex["name"] for ex in template["exercises"]]

    # Fetch all matching exercises in one query
    result = await db.execute(
        select(ExerciseLibrary).where(
            ExerciseLibrary.name.in_(exercise_names)
        )
    )
    library_exercises = {ex.name: ex for ex in result.scalars().all()}

    created_items = 0
    skipped = []

    for ex_data in template["exercises"]:
        ex_name = ex_data["name"]
        library_ex = library_exercises.get(ex_name)

        if not library_ex:
            # Try case-insensitive match
            for lib_name, lib_ex in library_exercises.items():
                if lib_name.lower() == ex_name.lower():
                    library_ex = lib_ex
                    break

        if not library_ex:
            skipped.append(ex_name)
            continue  # Skip exercises not in the library

        item = WorkoutItem(
            workout_id=workout.id,
            exercise_id=library_ex.id,
            sets=ex_data.get("sets", 3),
            reps_min=ex_data.get("reps_min"),
            reps_max=ex_data.get("reps_max"),
            duration_seconds=ex_data.get("duration_seconds"),
            rest_seconds=ex_data.get("rest_seconds", 60),
            notes=ex_data.get("notes"),
        )
        db.add(item)
        created_items += 1

    await db.commit()

    # Reload with items
    result = await db.execute(
        select(Workout)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise))
        .where(Workout.id == workout.id)
    )
    created_workout = result.scalars().first()

    return {
        "message": f"Treino '{template['name']}' importado com sucesso!",
        "workout_id": str(workout.id),
        "exercises_imported": created_items,
        "exercises_skipped": skipped,
        "workout": {
            "id": str(created_workout.id),
            "name": created_workout.name,
            "exercises": [
                {
                    "name": item.exercise.name if item.exercise else "?",
                    "sets": item.sets,
                    "reps_min": item.reps_min,
                    "reps_max": item.reps_max,
                    "duration_seconds": item.duration_seconds,
                    "rest_seconds": item.rest_seconds,
                }
                for item in created_workout.items
            ],
        },
    }


# ============================================================================
# DB-BACKED TRAINER TEMPLATES (WT-2)
# ============================================================================

@router.post("/", response_model=WorkoutTemplateSchema)
async def create_template(
    data: WorkoutTemplateCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Create a new workout template."""
    # Validate all exercises exist before creating template and build exercise name map
    exercise_names_map = {}
    if data.items:
        exercise_ids = [item.exercise_id for item in data.items]
        result = await db.execute(
            select(ExerciseLibrary).filter(ExerciseLibrary.id.in_(exercise_ids))
        )
        existing_exercises = result.scalars().all()
        exercise_names_map = {ex.id: ex.name for ex in existing_exercises}

        missing_ids = set(exercise_ids) - set(exercise_names_map.keys())
        if missing_ids:
            raise HTTPException(
                status_code=400,
                detail=f"Exercises not found: {missing_ids}"
            )

    template = WorkoutTemplate(
        id=uuid.uuid4(),
        trainer_id=current_user.id,
        name=data.name,
        description=data.description,
        goal=data.goal,
        level=data.level,
    )
    db.add(template)
    await db.flush()

    # Add items
    for idx, item_data in enumerate(data.items):
        # Use provided exercise_name or fall back to the one from exercise library
        exercise_name = item_data.exercise_name or exercise_names_map.get(item_data.exercise_id)

        item = WorkoutTemplateItem(
            id=uuid.uuid4(),
            template_id=template.id,
            exercise_id=item_data.exercise_id,
            exercise_name=exercise_name,
            sets=item_data.sets,
            reps_min=item_data.reps_min,
            reps_max=item_data.reps_max,
            duration_seconds=item_data.duration_seconds,
            rest_seconds=item_data.rest_seconds,
            notes=item_data.notes,
            methodology_type=item_data.methodology_type,
            methodology_params=item_data.methodology_params,
            superset_id=item_data.superset_id,
            order_index=item_data.order_index if item_data.order_index is not None else idx,
        )
        db.add(item)

    await db.commit()

    # Reload with items
    result = await db.execute(
        select(WorkoutTemplate)
        .options(selectinload(WorkoutTemplate.items).selectinload(WorkoutTemplateItem.exercise))
        .filter(WorkoutTemplate.id == template.id)
    )
    workout_obj = result.scalars().first()
    return WorkoutSchema.model_validate(workout_obj)


@router.get("/{template_id}", response_model=WorkoutTemplateSchema)
async def get_my_template(
    template_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Get a specific template (owner only)."""
    result = await db.execute(
        select(WorkoutTemplate)
        .options(selectinload(WorkoutTemplate.items).selectinload(WorkoutTemplateItem.exercise))
        .filter(
            WorkoutTemplate.id == uuid.UUID(template_id),
            WorkoutTemplate.trainer_id == current_user.id,
        )
    )
    template = result.scalars().first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    return template


@router.put("/{template_id}", response_model=WorkoutTemplateSchema)
async def update_template(
    template_id: str,
    data: WorkoutTemplateUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Update a template (owner only)."""
    result = await db.execute(
        select(WorkoutTemplate)
        .options(selectinload(WorkoutTemplate.items))
        .filter(
            WorkoutTemplate.id == uuid.UUID(template_id),
            WorkoutTemplate.trainer_id == current_user.id,
        )
    )
    template = result.scalars().first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    if data.name is not None:
        template.name = data.name
    if data.description is not None:
        template.description = data.description
    if data.goal is not None:
        template.goal = data.goal
    if data.level is not None:
        template.level = data.level

    # Update items if provided
    if data.items is not None:
        # Validate all exercises exist before updating and build exercise name map
        exercise_names_map = {}
        exercise_ids = [item.exercise_id for item in data.items]
        if exercise_ids:
            ex_result = await db.execute(
                select(ExerciseLibrary).filter(ExerciseLibrary.id.in_(exercise_ids))
            )
            existing_exercises = ex_result.scalars().all()
            exercise_names_map = {ex.id: ex.name for ex in existing_exercises}

            missing_ids = set(exercise_ids) - set(exercise_names_map.keys())
            if missing_ids:
                raise HTTPException(
                    status_code=400,
                    detail=f"Exercises not found: {missing_ids}"
                )

        # Delete existing items
        for item in template.items:
            await db.delete(item)
        await db.flush()

        # Add new items
        for idx, item_data in enumerate(data.items):
            # Use provided exercise_name or fall back to the one from exercise library
            exercise_name = item_data.exercise_name or exercise_names_map.get(item_data.exercise_id)

            item = WorkoutTemplateItem(
                id=uuid.uuid4(),
                template_id=template.id,
                exercise_id=item_data.exercise_id,
                exercise_name=exercise_name,
                sets=item_data.sets,
                reps_min=item_data.reps_min,
                reps_max=item_data.reps_max,
                duration_seconds=item_data.duration_seconds,
                rest_seconds=item_data.rest_seconds,
                notes=item_data.notes,
                methodology_type=item_data.methodology_type,
                methodology_params=item_data.methodology_params,
                superset_id=item_data.superset_id,
                order_index=item_data.order_index if item_data.order_index is not None else idx,
            )
            db.add(item)

    await db.commit()

    # Reload with items
    result = await db.execute(
        select(WorkoutTemplate)
        .options(selectinload(WorkoutTemplate.items).selectinload(WorkoutTemplateItem.exercise))
        .filter(WorkoutTemplate.id == template.id)
    )
    workout_obj = result.scalars().first()
    return WorkoutSchema.model_validate(workout_obj)


@router.delete("/{template_id}")
async def delete_template(
    template_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Delete a template (owner only)."""
    result = await db.execute(
        select(WorkoutTemplate).filter(
            WorkoutTemplate.id == uuid.UUID(template_id),
            WorkoutTemplate.trainer_id == current_user.id,
        )
    )
    template = result.scalars().first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    await db.delete(template)
    await db.commit()

    return {"message": "Template deleted successfully"}


@router.post("/{template_id}/apply", response_model=WorkoutSchema)
async def apply_template(
    template_id: str,
    data: ApplyTemplateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Apply a template to a student (creates a Workout from the template)."""
    # Verify template exists and belongs to current trainer
    template_result = await db.execute(
        select(WorkoutTemplate)
        .options(selectinload(WorkoutTemplate.items))
        .filter(
            WorkoutTemplate.id == uuid.UUID(template_id),
            WorkoutTemplate.trainer_id == current_user.id,
        )
    )
    template = template_result.scalars().first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Verify student exists and is linked to this trainer
    student_result = await db.execute(
        select(User).filter(User.id == data.student_id)
    )
    student = student_result.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Verify trainer-student relationship
    trainer_students_result = await db.execute(
        select(User)
        .options(selectinload(User.trainers))
        .filter(User.id == student.id)
    )
    student_with_trainers = trainer_students_result.scalars().first()
    if not any(t.id == current_user.id for t in student_with_trainers.trainers):
        raise HTTPException(status_code=403, detail="Student not linked to this trainer")

    # Create workout from template
    workout = Workout(
        id=uuid.uuid4(),
        name=template.name,
        user_id=student.id,
        scheduled_for=data.scheduled_for,
    )
    db.add(workout)
    await db.flush()

    # Create workout items from template items
    for template_item in template.items:
        item = WorkoutItem(
            id=uuid.uuid4(),
            workout_id=workout.id,
            exercise_id=template_item.exercise_id,
            sets=template_item.sets,
            reps_min=template_item.reps_min,
            reps_max=template_item.reps_max,
            duration_seconds=template_item.duration_seconds,
            rest_seconds=template_item.rest_seconds,
            notes=template_item.notes,
            methodology_type=template_item.methodology_type,
            methodology_params=template_item.methodology_params,
            superset_id=template_item.superset_id,
        )
        db.add(item)

    await db.commit()

    # Reload with items and sessions
    result = await db.execute(
        select(Workout)
        .options(
            selectinload(Workout.items).selectinload(WorkoutItem.exercise),
            selectinload(Workout.sessions)
        )
        .filter(Workout.id == workout.id)
    )
    workout_obj = result.scalars().first()
    return WorkoutSchema.model_validate(workout_obj)
