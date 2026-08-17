from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
from uuid import UUID
from app.models.invite import InviteStatus

class InviteCreate(BaseModel):
    email: EmailStr

class TrainerInviteCreate(BaseModel):
    email: EmailStr
    name: Optional[str] = None

class InviteResponse(BaseModel):
    id: UUID
    email: EmailStr
    token: Optional[str] = None # Only return token on creation
    status: InviteStatus
    expires_at: datetime
    invite_link: str

    class Config:
        from_attributes = True

class InvitePublicInfo(BaseModel):
    email: EmailStr
    trainer_name: Optional[str] = None
    trainer_id: Optional[UUID] = None
