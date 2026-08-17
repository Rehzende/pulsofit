from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, func
from app.api import deps
from app.db.session import get_db
from app.models.exercise import ExerciseLibrary, TrainerFavoriteExercise, ExerciseStatus
from app.models.user import User, UserRole
from app.schemas.exercise import ExerciseCreate, ExerciseUpdate, Exercise as ExerciseSchema, ExerciseFavoriteResponse
from uuid import UUID
from pydantic import BaseModel

router = APIRouter()

@router.get("/", response_model=List[ExerciseSchema])
async def read_exercises(
    skip: int = 0,
    limit: int = 1000,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    query = select(ExerciseLibrary).where(
        or_(
            ExerciseLibrary.status == ExerciseStatus.APPROVED,
            ExerciseLibrary.created_by_id == current_user.id
        )
    ).order_by(ExerciseLibrary.name).offset(skip).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()

@router.post("/", response_model=ExerciseSchema)
async def create_exercise(
    exercise_in: ExerciseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    # Anyone can create, but it defaults to PENDING_REVIEW
    exercise = ExerciseLibrary(
        name=exercise_in.name,
        category=exercise_in.category,
        is_iot_compatible=exercise_in.is_iot_compatible,
        muscle_group=exercise_in.muscle_group,
        met_value=exercise_in.met_value,
        video_url=exercise_in.video_url,
        equipment_photo_url=exercise_in.equipment_photo_url,
        description=exercise_in.description,
        instructions=exercise_in.instructions,
        equipment=exercise_in.equipment,
        status=ExerciseStatus.PENDING_REVIEW,
        created_by_id=current_user.id,
    )
    db.add(exercise)
    await db.commit()
    await db.refresh(exercise)
    return exercise

class SuggestionResponse(BaseModel):
    id: UUID
    name: str

@router.get("/suggest-similar", response_model=List[SuggestionResponse])
async def suggest_similar_exercises(
    q: str,
    limit: int = 5,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    # Quick fallback semantic search
    query = select(ExerciseLibrary.id, ExerciseLibrary.name).where(
        ExerciseLibrary.status == ExerciseStatus.APPROVED,
        ExerciseLibrary.name.ilike(f"%{q}%")
    ).limit(limit)
    result = await db.execute(query)
    rows = result.all()
    return [{"id": r[0], "name": r[1]} for r in rows]

class AliasCreate(BaseModel):
    alias: str

@router.patch("/{exercise_id}/alias")
async def add_exercise_alias(
    exercise_id: UUID,
    alias_in: AliasCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    result = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == exercise_id))
    exercise = result.scalars().first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")
        
    current_aliases = list(exercise.aliases) if exercise.aliases else []
    if alias_in.alias.lower() not in [a.lower() for a in current_aliases]:
        current_aliases.append(alias_in.alias)
        exercise.aliases = current_aliases
        await db.commit()
    
    return {"status": "success", "aliases": exercise.aliases}

@router.put("/{exercise_id}", response_model=ExerciseSchema)
async def update_exercise(
    exercise_id: UUID,
    exercise_in: ExerciseUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Update exercise media (video, equipment photo). Trainers only."""
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    result = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == exercise_id))
    exercise = result.scalars().first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    if exercise_in.name is not None:
        exercise.name = exercise_in.name
    if exercise_in.category is not None:
        exercise.category = exercise_in.category
    if exercise_in.muscle_group is not None:
        exercise.muscle_group = exercise_in.muscle_group
    if exercise_in.video_url is not None:
        exercise.video_url = exercise_in.video_url
    if exercise_in.equipment_photo_url is not None:
        exercise.equipment_photo_url = exercise_in.equipment_photo_url
    if exercise_in.description is not None:
        exercise.description = exercise_in.description
    if exercise_in.is_iot_compatible is not None:
        exercise.is_iot_compatible = exercise_in.is_iot_compatible

    await db.commit()
    await db.refresh(exercise)
    return exercise

# --- Favorites ---

@router.get("/favorites", response_model=List[ExerciseSchema])
async def get_favorite_exercises(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """List exercises favorited by the current trainer."""
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    result = await db.execute(
        select(ExerciseLibrary)
        .join(TrainerFavoriteExercise, TrainerFavoriteExercise.exercise_id == ExerciseLibrary.id)
        .where(TrainerFavoriteExercise.trainer_id == current_user.id)
        .order_by(ExerciseLibrary.name)
    )
    return result.scalars().all()

@router.post("/{exercise_id}/favorite", response_model=ExerciseFavoriteResponse)
async def toggle_favorite_exercise(
    exercise_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Toggle favorite status of an exercise. Trainers only."""
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    exercise_result = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == exercise_id))
    if not exercise_result.scalars().first():
        raise HTTPException(status_code=404, detail="Exercise not found")

    fav_result = await db.execute(
        select(TrainerFavoriteExercise).where(
            TrainerFavoriteExercise.trainer_id == current_user.id,
            TrainerFavoriteExercise.exercise_id == exercise_id,
        )
    )
    existing = fav_result.scalars().first()

    if existing:
        await db.delete(existing)
        await db.commit()
        return {"exercise_id": exercise_id, "is_favorite": False}
    else:
        fav = TrainerFavoriteExercise(trainer_id=current_user.id, exercise_id=exercise_id)
        db.add(fav)
        await db.commit()
        return {"exercise_id": exercise_id, "is_favorite": True}

@router.get("/favorites/ids", response_model=List[str])
async def get_favorite_exercise_ids(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Returns list of favorited exercise IDs for the current trainer."""
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    result = await db.execute(
        select(TrainerFavoriteExercise.exercise_id).where(
            TrainerFavoriteExercise.trainer_id == current_user.id
        )
    )
    return [str(row) for row in result.scalars().all()]
