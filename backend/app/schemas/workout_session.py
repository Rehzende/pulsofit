from pydantic import BaseModel, UUID4
from typing import Optional, Dict, List, Any, Union
from datetime import datetime
from app.models.workout import WorkoutSessionStatus

class ExerciseSetData(BaseModel):
    """Represents performance data for a single set"""
    set: int
    weight_kg: Optional[float] = None
    reps_done: Optional[int] = None

class ExerciseSessionData(BaseModel):
    """Exercise data for finish session: either per-set or single load"""
    exercise_id: UUID4
    # New format: per-set data
    sets: Optional[list[ExerciseSetData]] = None
    # Legacy format: single load
    load: Optional[float] = None

class WorkoutSessionBase(BaseModel):
    workout_id: UUID4

class WorkoutSessionCreate(WorkoutSessionBase):
    pass

class WorkoutSessionUpdate(BaseModel):
    end_time: Optional[datetime] = None
    status: Optional[WorkoutSessionStatus] = None
    shareable_image_url: Optional[str] = None
    progress_data: Optional[Dict] = None
    last_activity_time: Optional[datetime] = None
    calories_burned: Union[int, float, None] = None
    heart_rate_data: Optional[list[dict]] = None
    average_heart_rate: Optional[int] = None
    duration_seconds: Optional[int] = None
    exercises_data: Optional[list[ExerciseSessionData]] = None

class WorkoutSession(WorkoutSessionBase):
    id: UUID4
    user_id: UUID4
    start_time: datetime
    end_time: Optional[datetime] = None
    status: WorkoutSessionStatus
    shareable_image_url: Optional[str] = None
    duration_seconds: Optional[int] = None
    average_heart_rate: Optional[int] = None
    calories_burned: Union[int, float, None] = None
    xp_earned: Optional[int] = None
    heart_rate_data: Optional[list[dict]] = None
    progress_data: Optional[Dict] = None
    workout_snapshot: Optional[List[Dict[str, Any]]] = None

    class Config:
        from_attributes = True
