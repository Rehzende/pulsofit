import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, Enum, Float, JSON, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.session import Base
import enum

class WorkoutSessionStatus(str, enum.Enum):
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    ABANDONED = "ABANDONED"
    DRAFT = "DRAFT"

class MethodologyType(str, enum.Enum):
    NORMAL = "NORMAL"
    DROP_SET = "DROP_SET"
    REST_PAUSE = "REST_PAUSE"
    PIRAMIDE = "PIRAMIDE"
    FST_7 = "FST_7"
    AMRAP = "AMRAP"
    EMOM = "EMOM"

class Workout(Base):
    __tablename__ = "workouts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    scheduled_for = Column(DateTime, nullable=True)
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    group_id = Column(UUID(as_uuid=True), ForeignKey("workout_groups.id", ondelete="SET NULL"), nullable=True)
    is_favorite = Column(Boolean, default=False, nullable=False, server_default="false")

    items = relationship("WorkoutItem", back_populates="workout", cascade="all, delete-orphan")
    user = relationship("User", backref="workouts")
    sessions = relationship("WorkoutSession", back_populates="workout", cascade="all, delete-orphan")
    group = relationship("WorkoutGroup", back_populates="workouts")

class WorkoutItem(Base):
    __tablename__ = "workout_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    workout_id = Column(UUID(as_uuid=True), ForeignKey("workouts.id"), nullable=False)
    exercise_id = Column(UUID(as_uuid=True), ForeignKey("exercise_library.id"), nullable=False)

    sets = Column(Integer, nullable=False)
    reps_min = Column(Integer, nullable=True)
    reps_max = Column(Integer, nullable=True)
    # Per-set reps, e.g. [12, 10, 8]. When set, overrides the reps_min/reps_max
    # range (one value per series). Null = use the range for every set.
    reps_per_set = Column(JSON, nullable=True)
    duration_seconds = Column(Integer, nullable=True)  # For cardio/time-based exercises
    weight_kg = Column(Float, nullable=True)
    rest_seconds = Column(Integer, nullable=False)
    notes = Column(String, nullable=True)

    # IoT Fields
    target_zone_min_bpm = Column(Integer, nullable=True)
    target_zone_max_bpm = Column(Integer, nullable=True)
    target_rpe = Column(Integer, nullable=True) # 1-10 scale
    
    # Grouping
    superset_id = Column(UUID(as_uuid=True), nullable=True)

    # Training methodology
    methodology_type = Column(Enum(MethodologyType), nullable=False, default=MethodologyType.NORMAL)
    methodology_params = Column(JSON, nullable=True)

    workout = relationship("Workout", back_populates="items")
    exercise = relationship("ExerciseLibrary")

    @property
    def exercise_name(self):
        return self.exercise.name if self.exercise else None

    @property
    def instructions(self):
        return self.exercise.instructions if self.exercise else None

    @property
    def video_url(self):
        return self.exercise.video_url if self.exercise else None

    @property
    def gif_url(self):
        return self.exercise.gif_url if self.exercise else None

    @property
    def equipment_photo_url(self):
        return self.exercise.equipment_photo_url if self.exercise else None

class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    workout_id = Column(UUID(as_uuid=True), ForeignKey("workouts.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    start_time = Column(DateTime, default=lambda: datetime.utcnow())
    end_time = Column(DateTime, nullable=True)
    status = Column(Enum(WorkoutSessionStatus), default=WorkoutSessionStatus.IN_PROGRESS)
    shareable_image_url = Column(String, nullable=True)
    progress_data = Column(JSON, nullable=True)  # {exercise_id: {completed_sets: 2, total_sets: 3}}
    last_activity_time = Column(DateTime, nullable=True)
    workout_snapshot = Column(JSON, nullable=True)  # Snapshot of workout items at execution time
    
    # Calorie tracking
    calories_burned = Column(Float, nullable=True)
    xp_earned = Column(Integer, nullable=True)
    average_heart_rate = Column(Integer, nullable=True)
    heart_rate_data = Column(JSON, nullable=True)
    
    workout = relationship("Workout", back_populates="sessions")
    user = relationship("User")

    # Mood tracking (1=Exhausted, 2=Tired, 3=OK, 4=Good, 5=On Fire)
    mood_before = Column(Integer, nullable=True)
    mood_after = Column(Integer, nullable=True)

    @property
    def duration_seconds(self) -> int | None:
        if self.start_time and self.end_time:
            delta = self.end_time - self.start_time
            secs = int(delta.total_seconds())
            return secs if secs > 0 else None
        return None

