import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Boolean, Float, Enum, Text, ForeignKey, Integer, DateTime, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.session import Base

class MuscleGroup(str, enum.Enum):
    CHEST = "CHEST"
    BACK = "BACK"
    LEGS = "LEGS"
    ARMS = "ARMS"
    SHOULDERS = "SHOULDERS"
    CORE = "CORE"
    CARDIO = "CARDIO"

class ExerciseStatus(str, enum.Enum):
    APPROVED = "APPROVED"
    PENDING_REVIEW = "PENDING_REVIEW"
    REJECTED = "REJECTED"

class ExerciseLibrary(Base):
    __tablename__ = "exercise_library"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, index=True, nullable=False)
    category = Column(String, index=True, nullable=False)

    # Rich content fields
    description = Column(Text, nullable=True)
    instructions = Column(JSONB, nullable=True)  # Storing list of steps
    equipment = Column(JSONB, nullable=True)     # Storing list of equipment

    is_iot_compatible = Column(Boolean, default=False)

    # Intelligence fields
    muscle_group = Column(Enum(MuscleGroup), nullable=True, index=True)
    met_value = Column(Float, nullable=True)
    video_url = Column(String, nullable=True)
    gif_url = Column(String, nullable=True)  # Demonstration GIF (stick-figure) shown on execution screen
    equipment_photo_url = Column(String, nullable=True)

    # Curation / AI fields
    status = Column(Enum(ExerciseStatus), default=ExerciseStatus.APPROVED, index=True, server_default="APPROVED")
    created_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    aliases = Column(JSONB, nullable=False, server_default='[]', default=list)

    favorited_by = relationship("TrainerFavoriteExercise", back_populates="exercise", cascade="all, delete-orphan")
    group_items = relationship("ExerciseGroupItem", back_populates="exercise", cascade="all, delete-orphan")
    creator = relationship("User", foreign_keys=[created_by_id])


class TrainerFavoriteExercise(Base):
    __tablename__ = "trainer_favorite_exercises"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(UUID(as_uuid=True), ForeignKey("exercise_library.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)

    __table_args__ = (
        UniqueConstraint("trainer_id", "exercise_id", name="uq_trainer_favorite_exercise"),
    )

    trainer = relationship("User", foreign_keys=[trainer_id])
    exercise = relationship("ExerciseLibrary", back_populates="favorited_by")


class ExerciseGroup(Base):
    __tablename__ = "exercise_groups"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)

    trainer = relationship("User", foreign_keys=[trainer_id])
    items = relationship("ExerciseGroupItem", back_populates="group", cascade="all, delete-orphan", order_by="ExerciseGroupItem.order_index")


class ExerciseGroupItem(Base):
    __tablename__ = "exercise_group_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id = Column(UUID(as_uuid=True), ForeignKey("exercise_groups.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(UUID(as_uuid=True), ForeignKey("exercise_library.id", ondelete="CASCADE"), nullable=False)
    order_index = Column(Integer, nullable=False, default=0)
    sets = Column(Integer, nullable=False, default=3)
    reps_min = Column(Integer, nullable=True)
    reps_max = Column(Integer, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    rest_seconds = Column(Integer, nullable=False, default=60)

    group = relationship("ExerciseGroup", back_populates="items")
    exercise = relationship("ExerciseLibrary", back_populates="group_items")
