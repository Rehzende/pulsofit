import uuid
from datetime import datetime
from sqlalchemy import Column, String, ForeignKey, Enum, DateTime, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.session import Base
import enum

class AgentActionStatus(str, enum.Enum):
    NONE = "NONE"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    EXECUTED = "EXECUTED"

class AgentSession(Base):
    __tablename__ = "ai_agent_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    title = Column(String, nullable=True) # Ex: "Criação de treinos para João"

    trainer = relationship("User", foreign_keys=[trainer_id], backref="agent_sessions")
    student = relationship("User", foreign_keys=[student_id])
    messages = relationship("AgentMessage", back_populates="session", cascade="all, delete-orphan", order_by="AgentMessage.created_at")

from sqlalchemy import event

@event.listens_for(AgentSession, 'before_update')
def receive_before_update(mapper, connection, target):
    target.updated_at = datetime.utcnow()

class AgentMessage(Base):
    __tablename__ = "ai_agent_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("ai_agent_sessions.id", ondelete="CASCADE"), nullable=False)
    role = Column(String, nullable=False)  # user, assistant, tool
    content = Column(String, nullable=True) # Texto da mensagem
    
    # Para Function Calling
    tool_calls = Column(JSONB, nullable=True) # Se a IA solicitou uma função
    tool_call_id = Column(String, nullable=True) # Se esta mensagem for a resposta de uma tool
    
    # Estado da Ação (Rich UI)
    action_status = Column(Enum(AgentActionStatus), default=AgentActionStatus.NONE, nullable=False)
    action_data = Column(JSONB, nullable=True) # Payload da ação (ex: JSON do treino planejado)
    
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("AgentSession", back_populates="messages")
