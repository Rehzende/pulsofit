import uuid
from sqlalchemy import Column, String, Float, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.session import Base
import enum

class AssessmentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PROCESSED = "PROCESSED"
    FAILED = "FAILED"

class BodyAssessment(Base):
    __tablename__ = "body_assessments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    photo_front_url = Column(String, nullable=True)
    photo_side_url = Column(String, nullable=True)
    photo_back_url = Column(String, nullable=True)

    body_fat_percent = Column(Float, nullable=True)
    muscle_mass_percent = Column(Float, nullable=True)

    status = Column(Enum(AssessmentStatus), default=AssessmentStatus.PENDING, nullable=False)

    user = relationship("User", backref="assessments")
