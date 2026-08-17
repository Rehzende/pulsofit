import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, ForeignKey, Enum, Boolean, DateTime, Float, Date
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship, backref
from app.db.session import Base
# Import SubscriptionPlan to avoid circular import issues if possible, or just rely on string reference
# But for Alembic to see it, it needs to be imported in env.py or similar. 
# Here we just add the column.
import enum

class UserRole(str, enum.Enum):
    SUPER_ADMIN = "SUPER_ADMIN"
    TRAINER = "TRAINER"
    STUDENT = "STUDENT"

class SubscriptionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    TRIAL = "TRIAL"

class Gender(str, enum.Enum):
    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"

# Association Table
from sqlalchemy import Table
student_trainer_association = Table(
    "student_trainer_association",
    Base.metadata,
    Column("student_id", UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True),
    Column("trainer_id", UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True),
)

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True)
    birthday = Column(DateTime, nullable=True)  # Using DateTime for simplicity, could be Date
    photo_url = Column(String, nullable=True)
    whatsapp_number = Column(String, nullable=True)
    
    hashed_password = Column(String, nullable=True)
    role = Column(Enum(UserRole), default=UserRole.STUDENT, nullable=False)
    
    is_active = Column(Boolean, default=True)
    
    # Subscription
    subscription_status = Column(Enum(SubscriptionStatus), default=SubscriptionStatus.TRIAL, nullable=True)
    subscription_end_date = Column(DateTime, nullable=True)
    
    # Gamification
    xp_points = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    best_streak = Column(Integer, default=0)
    level = Column(Integer, default=1)

    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    
    # Subscription Plan
    plan_id = Column(UUID(as_uuid=True), ForeignKey("subscription_plans.id"), nullable=True)
    
    resting_hr = Column(Integer, nullable=True)
    max_hr = Column(Integer, nullable=True)
    
    # New fields for calorie calculation
    gender = Column(Enum(Gender), nullable=True)
    weight_kg = Column(Float, nullable=True)
    
    # Medical / Anamnesis
    medical_history = Column(JSONB, nullable=True)
    anamnesis_completed = Column(Boolean, default=False)
    
    # Streak Protector (1 life per month, auto-replenished)
    streak_protectors_available = Column(Integer, default=1)
    streak_protectors_used_this_month = Column(Integer, default=0)
    last_streak_protector_reset = Column(DateTime, nullable=True)

    # Streak tracking — used to ensure streak counts only once per calendar day
    last_workout_date = Column(Date, nullable=True)

    # Legal: AI self-responsibility terms acceptance
    accepted_ai_terms_at = Column(DateTime, nullable=True)

    # 7-day challenge
    challenge_7d_started_at = Column(DateTime, nullable=True)
    challenge_7d_completed_at = Column(DateTime, nullable=True)

    # Session tracking
    last_login_at = Column(DateTime, nullable=True)

    # M:N Relationship
    # ARCH-2: Use lazy="select" to avoid cascading eager loads
    # When accessed, use selectinload() explicitly in endpoints
    trainers = relationship(
        "User",
        secondary="student_trainer_association",
        primaryjoin="User.id==student_trainer_association.c.student_id",
        secondaryjoin="User.id==student_trainer_association.c.trainer_id",
        backref="students_list",
        lazy="select",
    )
    invites = relationship("StudentInvite", back_populates="trainer")

    # Relationships
    trainer_profile = relationship("TrainerProfile", uselist=False, back_populates="user", cascade="all, delete-orphan")
    # Note: primaryjoin explicit because WorkoutGroup has trainer_id + student_id FKs to users
    workout_groups = relationship("WorkoutGroup", back_populates="trainer", cascade="all, delete-orphan", primaryjoin="User.id==WorkoutGroup.trainer_id")
    workout_templates = relationship("WorkoutTemplate", back_populates="trainer", cascade="all, delete-orphan")

    @property
    def trainer_brand_name(self):
        return self.trainer_profile.brand_name if self.trainer_profile else None

    @property
    def trainer_logo_url(self):
        return self.trainer_profile.logo_url if self.trainer_profile else None

    @property
    def trainer_primary_color(self):
        return self.trainer_profile.primary_color if self.trainer_profile else None
