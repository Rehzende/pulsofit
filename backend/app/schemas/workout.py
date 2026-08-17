from pydantic import BaseModel, UUID4
from typing import List, Optional
from datetime import datetime
from app.schemas.workout_session import WorkoutSession
from app.models.workout import MethodologyType

# Workout Item Schemas
class WorkoutItemBase(BaseModel):
    sets: int
    reps_min: Optional[int] = None
    reps_max: Optional[int] = None
    reps_per_set: Optional[List[int]] = None  # e.g. [12, 10, 8] — overrides the range
    duration_seconds: Optional[int] = None  # For cardio/time-based exercises
    weight_kg: Optional[float] = None
    rest_seconds: int
    notes: Optional[str] = None
    target_zone_min_bpm: Optional[int] = None
    target_zone_max_bpm: Optional[int] = None
    target_rpe: Optional[int] = None
    superset_id: Optional[UUID4] = None
    methodology_type: MethodologyType = MethodologyType.NORMAL
    methodology_params: Optional[dict] = None

class WorkoutItemCreate(WorkoutItemBase):
    exercise_name: Optional[str] = None
    exercise_id: Optional[UUID4] = None

class WorkoutItem(WorkoutItemBase):
    id: UUID4
    workout_id: UUID4
    exercise_id: UUID4
    exercise_name: Optional[str] = None
    instructions: Optional[List[str]] = None
    video_url: Optional[str] = None
    gif_url: Optional[str] = None
    equipment_photo_url: Optional[str] = None

    class Config:
        from_attributes = True

# Workout Schemas
class WorkoutBase(BaseModel):
    name: str
    scheduled_for: Optional[datetime] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None

class WorkoutCreate(WorkoutBase):
    student_id: UUID4
    items: List[WorkoutItemCreate]
    group_id: Optional[UUID4] = None

class WorkoutUpdate(BaseModel):
    name: Optional[str] = None
    scheduled_for: Optional[datetime] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    items: Optional[List[WorkoutItemCreate]] = None
    group_id: Optional[UUID4] = None

class Workout(WorkoutBase):
    id: UUID4
    user_id: UUID4
    group_id: Optional[UUID4] = None
    is_favorite: bool = False
    items: List[WorkoutItem] = []
    sessions: List[WorkoutSession] = []

    class Config:
        from_attributes = True

class WeeklyStatusResponse(BaseModel):
    completed_days: List[int]
    today_completed: bool
    next_workout: Optional[Workout] = None

class SmartWarning(BaseModel):
    exercise_name: str
    muscle_group: str
    recovery_pct: int
    methodology_type: str