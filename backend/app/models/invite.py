import uuid
from sqlalchemy import Column, String, ForeignKey, Enum, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta
import enum

from app.db.session import Base

class InviteStatus(str, enum.Enum):
    PENDING = "PENDING"
    REGISTERED = "REGISTERED"

class StudentInvite(Base):
    __tablename__ = "student_invites"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    email = Column(String, unique=True, index=True, nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    status = Column(Enum(InviteStatus), default=InviteStatus.PENDING, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow())

    trainer = relationship("User", back_populates="invites")
