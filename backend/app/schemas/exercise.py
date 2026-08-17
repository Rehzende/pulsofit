from typing import Optional, List
from pydantic import BaseModel, UUID4

class ExerciseBase(BaseModel):
    name: str
    category: str
    is_iot_compatible: bool = False

class ExerciseCreate(ExerciseBase):
    muscle_group: Optional[str] = None
    met_value: Optional[float] = None
    video_url: Optional[str] = None
    gif_url: Optional[str] = None
    equipment_photo_url: Optional[str] = None
    description: Optional[str] = None
    instructions: Optional[List[str]] = None
    equipment: Optional[List[str]] = None

class ExerciseUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    muscle_group: Optional[str] = None
    video_url: Optional[str] = None
    gif_url: Optional[str] = None
    equipment_photo_url: Optional[str] = None
    description: Optional[str] = None
    is_iot_compatible: Optional[bool] = None

class ExerciseInDBBase(ExerciseBase):
    id: UUID4

    class Config:
        from_attributes = True

from app.models.exercise import ExerciseStatus

class Exercise(ExerciseInDBBase):
    id: UUID4
    name: str
    category: str
    muscle_group: Optional[str] = None
    description: Optional[str] = None
    instructions: Optional[List[str]] = None
    equipment: Optional[List[str]] = None
    is_iot_compatible: bool = False
    met_value: Optional[float] = None
    video_url: Optional[str] = None
    gif_url: Optional[str] = None
    equipment_photo_url: Optional[str] = None

    status: ExerciseStatus = ExerciseStatus.APPROVED
    created_by_id: Optional[UUID4] = None
    aliases: List[str] = []

    class Config:
        from_attributes = True

# --- Favorites ---

class ExerciseFavoriteResponse(BaseModel):
    exercise_id: UUID4
    is_favorite: bool

# --- Exercise Groups ---

class ExerciseGroupItemCreate(BaseModel):
    exercise_id: UUID4
    order_index: int = 0
    sets: int = 3
    reps_min: Optional[int] = None
    reps_max: Optional[int] = None
    duration_seconds: Optional[int] = None
    rest_seconds: int = 60

class ExerciseGroupItemUpdate(BaseModel):
    order_index: Optional[int] = None
    sets: Optional[int] = None
    reps_min: Optional[int] = None
    reps_max: Optional[int] = None
    duration_seconds: Optional[int] = None
    rest_seconds: Optional[int] = None

class ExerciseGroupItemOut(BaseModel):
    id: UUID4
    exercise_id: UUID4
    order_index: int
    sets: int
    reps_min: Optional[int] = None
    reps_max: Optional[int] = None
    duration_seconds: Optional[int] = None
    rest_seconds: int
    exercise: Optional[Exercise] = None

    class Config:
        from_attributes = True

class ExerciseGroupCreate(BaseModel):
    name: str
    description: Optional[str] = None

class ExerciseGroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None

class ExerciseGroupOut(BaseModel):
    id: UUID4
    name: str
    description: Optional[str] = None
    items: List[ExerciseGroupItemOut] = []

    class Config:
        from_attributes = True
