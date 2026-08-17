import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.session import Base


class TrainerReview(Base):
    """Student review/testimonial for a trainer."""
    __tablename__ = "trainer_reviews"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)

    rating = Column(Integer, nullable=False)          # 1–5 stars
    text = Column(Text, nullable=True)                # optional comment
    is_public = Column(Boolean, default=True)         # trainer can hide it later
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)

    trainer = relationship("User", foreign_keys=[trainer_id])
    student = relationship("User", foreign_keys=[student_id])
