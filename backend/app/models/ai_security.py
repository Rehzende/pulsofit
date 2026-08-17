from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, JSON
from datetime import datetime
from sqlalchemy.dialects.postgresql import UUID as pgUUID
import uuid

from app.db.session import Base

class AIUsageLog(Base):
    __tablename__ = "ai_usage_logs"

    id = Column(pgUUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(pgUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    request_type = Column(String, nullable=False) # 'generate' ou 'anamnesis'
    tokens_used = Column(Integer, default=0)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), index=True)

class AIResponseCache(Base):
    __tablename__ = "ai_response_cache"

    hash_key = Column(String, primary_key=True, index=True)
    response_data = Column(JSON, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), index=True)
