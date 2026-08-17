from pydantic import BaseModel, UUID4
from typing import Optional, List
from datetime import datetime
from enum import Enum

class HiringRequestStatus(str, Enum):
    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"

class TrainerMarketplaceItem(BaseModel):
    user_id: UUID4
    full_name: str
    photo_url: Optional[str] = None
    brand_name: Optional[str] = None
    logo_url: Optional[str] = None
    bio: Optional[str] = None
    modality: Optional[str] = None  # 'presencial', 'online', 'hibrido'
    specialties: Optional[List[str]] = None
    gyms: Optional[List[str]] = None
    hourly_rate: Optional[float] = None
    primary_color: Optional[str] = "#7C3AED" # Default Pulso Violet
    whatsapp_number: Optional[str] = None
    email: Optional[str] = None           # só exposto quando request_status == ACCEPTED
    request_status: Optional[str] = "NONE" # NONE, PENDING, ACCEPTED, REJECTED
    average_rating: Optional[float] = None # média das avaliações públicas (1–5)
    total_reviews: int = 0                 # quantidade de avaliações públicas
    is_verified: bool = False              # selo de treinador verificado

    class Config:
        from_attributes = True

class HiringRequestRead(BaseModel):
    id: UUID4
    student_id: UUID4
    trainer_id: UUID4
    status: HiringRequestStatus
    created_at: datetime
    student_name: Optional[str] = None
    student_photo: Optional[str] = None

    class Config:
        from_attributes = True
