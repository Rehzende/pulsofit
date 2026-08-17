from pydantic import BaseModel, EmailStr, UUID4
from typing import Optional, Any
from datetime import datetime
from app.models.user import UserRole, SubscriptionStatus, Gender
from app.schemas.trainer_profile import TrainerProfile

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    birthday: Optional[datetime] = None
    photo_url: Optional[str] = None
    whatsapp_number: Optional[str] = None
    role: UserRole = UserRole.STUDENT
    resting_hr: Optional[int] = None
    max_hr: Optional[int] = None
    is_active: Optional[bool] = True
    gender: Optional[Gender] = None
    
    # Gamification
    xp_points: Optional[int] = 0
    current_streak: Optional[int] = 0
    level: Optional[int] = 1
    
    # Subscription
    subscription_status: Optional[SubscriptionStatus] = SubscriptionStatus.TRIAL
    subscription_end_date: Optional[datetime] = None
    
    # Medical
    medical_history: Optional[Any] = None
    anamnesis_completed: Optional[bool] = False
    
    # Legal
    accepted_ai_terms_at: Optional[datetime] = None

    # Tracking
    last_login_at: Optional[datetime] = None

    # Invite Status (for UI display)
    invite_status: Optional[str] = None
    invite_link: Optional[str] = None

class UserCreate(UserBase):
    password: str
    trainer_id: Optional[UUID4] = None

class StudentRegister(BaseModel):
    token: str
    name: str
    password: str
    phone: Optional[str] = None

class TrainerRegister(BaseModel):
    name: str
    email: EmailStr
    password: str
    phone: Optional[str] = None
    brand_name: Optional[str] = None

class UserUpdate(UserBase):
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    is_active: Optional[bool] = None
    subscription_status: Optional[SubscriptionStatus] = None
    plan_id: Optional[UUID4] = None
    medical_history: Optional[Any] = None
    # ... other fields

class UserStatusUpdate(BaseModel):
    is_active: bool

class UserIoTUpdate(BaseModel):
    iot_enabled: bool

class UserMeUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    birthday: Optional[datetime] = None
    photo_url: Optional[str] = None
    whatsapp_number: Optional[str] = None
    medical_history: Optional[Any] = None
    anamnesis_completed: Optional[bool] = None
    gender: Optional[str] = None
    weight_kg: Optional[float] = None


class UserInDBBase(UserBase):
    id: UUID4
    trainer_id: Optional[UUID4] = None
    plan_id: Optional[UUID4] = None

    class Config:
        from_attributes = True

class User(UserInDBBase):
    trainer_profile: Optional[TrainerProfile] = None # For Trainer's own profile

    # Flattened trainer branding for students (populated manually or via property)
    trainer_brand_name: Optional[str] = None
    trainer_logo_url: Optional[str] = None
    trainer_primary_color: Optional[str] = None
    trainer_whatsapp_number: Optional[str] = None

    # Subscription plan name (populated manually from the related SubscriptionPlan)
    plan_name: Optional[str] = None
