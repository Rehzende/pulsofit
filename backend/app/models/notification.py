import uuid
from datetime import datetime
import enum
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.session import Base


class NotificationType(str, enum.Enum):
    HIRING_REQUEST = "HIRING_REQUEST"
    HIRING_ACCEPTED = "HIRING_ACCEPTED"
    HIRING_REJECTED = "HIRING_REJECTED"
    NEW_REVIEW = "NEW_REVIEW"
    NEW_WORKOUT = "NEW_WORKOUT"
    STREAK_WARNING = "STREAK_WARNING"
    STUDENT_TRAINING = "STUDENT_TRAINING"
    NEW_CHAT = "NEW_CHAT"


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    type = Column(Enum(NotificationType), nullable=False)
    title = Column(String, nullable=False)
    body = Column(String, nullable=False)
    data = Column(JSONB, nullable=True)
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)

    user = relationship("User", backref="notifications")
