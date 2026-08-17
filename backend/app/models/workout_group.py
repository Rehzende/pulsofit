from sqlalchemy import Column, String, DateTime, ForeignKey, UUID as SQLUUID, UniqueConstraint, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.session import Base
import uuid


class WorkoutGroup(Base):
    __tablename__ = "workout_groups"

    id = Column(SQLUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    trainer_id = Column(SQLUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(SQLUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    start_date = Column(DateTime(timezone=True), nullable=True)  # When the program/folder starts
    end_date = Column(DateTime(timezone=True), nullable=True)    # When the program/folder ends
    is_active = Column(Boolean, default=True, nullable=False)    # False when moved to inactive
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    trainer = relationship("User", foreign_keys=[trainer_id], back_populates="workout_groups")
    student = relationship("User", foreign_keys=[student_id])
    workouts = relationship("Workout", back_populates="group")

    # Unique constraint: trainer can't have duplicate group names (including per student if specified)
    __table_args__ = (
        UniqueConstraint('name', 'trainer_id', 'student_id', name='uq_workout_group_name_trainer_student'),
    )
