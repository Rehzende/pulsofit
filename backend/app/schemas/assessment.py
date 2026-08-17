from pydantic import BaseModel, UUID4
from typing import Optional
from app.models.assessment import AssessmentStatus

class BodyAssessmentBase(BaseModel):
    photo_front_url: Optional[str] = None
    photo_side_url: Optional[str] = None
    photo_back_url: Optional[str] = None
    body_fat_percent: Optional[float] = None
    muscle_mass_percent: Optional[float] = None
    status: AssessmentStatus = AssessmentStatus.PENDING

class BodyAssessmentCreate(BodyAssessmentBase):
    user_id: UUID4

class BodyAssessmentUpdate(BodyAssessmentBase):
    pass

class BodyAssessmentInDBBase(BodyAssessmentBase):
    id: UUID4
    user_id: UUID4

    class Config:
        from_attributes = True

class BodyAssessment(BodyAssessmentInDBBase):
    pass
