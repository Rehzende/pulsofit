import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Integer, ForeignKey, Enum as SQLEnum, UUID as SQLUUID, JSON
from sqlalchemy.orm import relationship
from app.db.session import Base
from app.models.workout import MethodologyType


class WorkoutTemplate(Base):
    """Reusable workout template owned by a trainer."""
    __tablename__ = "workout_templates"

    id = Column(SQLUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trainer_id = Column(SQLUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    goal = Column(String, nullable=True)  # e.g., "Hipertrofia", "Emagrecimento"
    level = Column(String, nullable=True)  # e.g., "Iniciante", "Intermediário", "Avançado"
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    trainer = relationship("User", back_populates="workout_templates")
    items = relationship(
        "WorkoutTemplateItem",
        cascade="all, delete-orphan",
        back_populates="template",
        order_by="WorkoutTemplateItem.order_index"
    )


class WorkoutTemplateItem(Base):
    """Exercise prescription within a workout template."""
    __tablename__ = "workout_template_items"

    id = Column(SQLUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    template_id = Column(SQLUUID(as_uuid=True), ForeignKey("workout_templates.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(SQLUUID(as_uuid=True), ForeignKey("exercise_library.id"), nullable=False)
    exercise_name = Column(String, nullable=True)  # Snapshot of exercise name at creation time
    sets = Column(Integer, nullable=False)
    reps_min = Column(Integer, nullable=True)
    reps_max = Column(Integer, nullable=True)
    duration_seconds = Column(Integer, nullable=True)  # For cardio/time-based exercises
    rest_seconds = Column(Integer, nullable=False, default=60)
    notes = Column(String, nullable=True)
    methodology_type = Column(SQLEnum(MethodologyType), nullable=False, default=MethodologyType.NORMAL)
    methodology_params = Column(JSON, nullable=True)
    superset_id = Column(SQLUUID(as_uuid=True), nullable=True)  # For grouping exercises
    order_index = Column(Integer, nullable=False, default=0)

    template = relationship("WorkoutTemplate", back_populates="items")
    exercise = relationship("ExerciseLibrary")
