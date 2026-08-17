import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.session import Base


class MagicLink(Base):
    __tablename__ = "magic_links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    token_hash = Column(String, nullable=False, index=True)
    short_code = Column(String(6), nullable=True, index=True)
    is_used = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow())
    expires_at = Column(DateTime, nullable=False)

    user = relationship("User", backref="magic_links")
