import uuid
from sqlalchemy import Column, String, Boolean, ForeignKey, Float
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship
from app.db.session import Base

class TrainerProfile(Base):
    __tablename__ = "trainer_profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False)
    
    slug = Column(String, unique=True, nullable=True, index=True)
    brand_name = Column(String, nullable=True)
    logo_url = Column(String, nullable=True)
    primary_color = Column(String, default="#000000")
    whatsapp_number = Column(String, nullable=True)
    instagram_handle = Column(String, nullable=True)
    
    # Marketplace Fields
    is_available_for_hire = Column(Boolean, default=False)
    modality = Column(String, nullable=True)  # 'presencial', 'online', 'hibrido'
    specialties = Column(ARRAY(String), nullable=True)
    gyms = Column(ARRAY(String), nullable=True)  # academias/locais de atendimento
    bio = Column(String, nullable=True)
    hourly_rate = Column(Float, nullable=True)
    
    # Feature Flags (Controlled by Super Admin)
    enable_iot = Column(Boolean, default=False)
    enable_ai_vision = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    enable_ai_workouts = Column(Boolean, default=False, nullable=False)

    user = relationship("User", back_populates="trainer_profile")
