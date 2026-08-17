from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class WorkoutGroupBase(BaseModel):
    name: str
    student_id: Optional[UUID] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class WorkoutGroupCreate(WorkoutGroupBase):
    pass


class WorkoutGroupUpdate(BaseModel):
    name: Optional[str] = None
    student_id: Optional[UUID] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class WorkoutGroup(WorkoutGroupBase):
    id: UUID
    trainer_id: UUID
    is_active: bool
    created_at: datetime
    trainer_name: Optional[str] = None

    class Config:
        from_attributes = True
