from pydantic import BaseModel, UUID4, model_validator
from typing import List, Optional, Any
from datetime import datetime
from app.models.workout import MethodologyType


class WorkoutTemplateItemBase(BaseModel):
    exercise_id: UUID4
    exercise_name: Optional[str] = None
    sets: int
    reps_min: Optional[int] = None
    reps_max: Optional[int] = None
    duration_seconds: Optional[int] = None
    rest_seconds: int = 60
    notes: Optional[str] = None
    methodology_type: MethodologyType = MethodologyType.NORMAL
    superset_id: Optional[UUID4] = None
    order_index: int = 0
    methodology_params: Optional[dict] = None


class WorkoutTemplateItemCreate(WorkoutTemplateItemBase):
    pass


class WorkoutTemplateItem(WorkoutTemplateItemBase):
    id: UUID4
    template_id: UUID4

    @model_validator(mode='before')
    @classmethod
    def fallback_exercise_name(cls, data: Any) -> Any:
        # data is the SQLAlchemy ORM object
        exercise_name = getattr(data, 'exercise_name', None)

        # If exercise_name is missing or empty, try to get it from the exercise relationship
        if not exercise_name and getattr(data, 'exercise', None):
            data.exercise_name = data.exercise.name

        return data

    class Config:
        from_attributes = True


class WorkoutTemplateBase(BaseModel):
    name: str
    description: Optional[str] = None
    goal: Optional[str] = None
    level: Optional[str] = None


class WorkoutTemplateCreate(WorkoutTemplateBase):
    items: List[WorkoutTemplateItemCreate] = []


class WorkoutTemplateUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    goal: Optional[str] = None
    level: Optional[str] = None
    items: Optional[List[WorkoutTemplateItemCreate]] = None


class WorkoutTemplate(WorkoutTemplateBase):
    id: UUID4
    trainer_id: UUID4
    created_at: datetime
    items: List[WorkoutTemplateItem] = []

    class Config:
        from_attributes = True


class ApplyTemplateRequest(BaseModel):
    student_id: UUID4
    scheduled_for: Optional[datetime] = None
