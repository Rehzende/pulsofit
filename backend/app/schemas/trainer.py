from typing import Optional
from datetime import datetime
from pydantic import BaseModel
from uuid import UUID

class LiveSessionResponse(BaseModel):
    session_id: UUID
    student_id: UUID
    student_name: str
    student_avatar: Optional[str] = None
    student_phone: Optional[str] = None
    workout_name: str
    start_time: datetime
    current_heart_rate: Optional[int] = None
    
    class Config:
        from_attributes = True
