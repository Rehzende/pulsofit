from pydantic import BaseModel, UUID4, field_validator
from typing import Optional, Literal
import re

SLUG_RE = re.compile(r'^[a-z0-9][a-z0-9\-]{1,28}[a-z0-9]$')

class TrainerProfileBase(BaseModel):
    slug: Optional[str] = None
    brand_name: Optional[str] = None
    logo_url: Optional[str] = None
    photo_url: Optional[str] = None
    primary_color: Optional[str] = "#000000"
    whatsapp_number: Optional[str] = None
    instagram_handle: Optional[str] = None

    # Marketplace Fields
    is_available_for_hire: Optional[bool] = False
    modality: Optional[Literal["presencial", "online", "hibrido"]] = None
    specialties: Optional[list[str]] = None
    gyms: Optional[list[str]] = None
    bio: Optional[str] = None
    hourly_rate: Optional[float] = None

    @field_validator('slug')
    @classmethod
    def validate_slug(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == '':
            return None
        v = v.lower().strip()
        if not SLUG_RE.match(v):
            raise ValueError(
                'Slug deve ter entre 3 e 30 caracteres, conter apenas letras minúsculas, '
                'números e hífens, e não pode começar ou terminar com hífen.'
            )
        return v

class TrainerProfileCreate(TrainerProfileBase):
    pass

class TrainerProfileUpdate(TrainerProfileBase):
    pass

class TrainerProfile(TrainerProfileBase):
    id: UUID4
    user_id: UUID4
    enable_iot: bool = False
    enable_ai_vision: bool = False
    is_verified: bool = False

    class Config:
        from_attributes = True
        populate_by_name = True
