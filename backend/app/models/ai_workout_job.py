"""
AI Workout Job model — tracks async Gemini generation jobs.
Status flow: PENDING → PROCESSING → DONE | FAILED
"""
from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID as pgUUID, JSONB
from datetime import datetime
import uuid

from app.db.session import Base


class AIWorkoutJob(Base):
    __tablename__ = "ai_workout_jobs"

    id = Column(pgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)

    # Who requested
    user_id = Column(
        pgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Job type — mirrors AIUsageLog.request_type
    job_type = Column(String(32), nullable=False)  # 'anamnesis' | 'generate'

    # Cache key — if same hash exists as DONE, return immediately
    prompt_hash = Column(String(64), nullable=False, index=True)

    # Lifecycle
    status = Column(String(16), nullable=False, default="PENDING", index=True)
    # PENDING → PROCESSING → DONE | FAILED

    # Result payload (same shape as before)
    result_data = Column(JSONB, nullable=True)

    # Error info
    error_message = Column(Text, nullable=True)

    created_at = Column(DateTime, default=lambda: datetime.utcnow(), index=True)
    completed_at = Column(DateTime, nullable=True)
