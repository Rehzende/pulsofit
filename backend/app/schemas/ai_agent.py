from typing import List, Optional, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, ConfigDict
from enum import Enum

class AgentActionStatus(str, Enum):
    NONE = "NONE"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    EXECUTED = "EXECUTED"

class AgentMessageBase(BaseModel):
    role: str
    content: Optional[str] = None
    tool_calls: Optional[List[Any]] = None
    tool_call_id: Optional[str] = None
    action_status: AgentActionStatus = AgentActionStatus.NONE
    action_data: Optional[Any] = None

class AgentMessageCreate(AgentMessageBase):
    pass

class AgentMessage(AgentMessageBase):
    id: UUID
    session_id: UUID
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class AgentSessionBase(BaseModel):
    title: Optional[str] = None

class AgentSessionCreate(AgentSessionBase):
    pass

class AgentSession(AgentSessionBase):
    id: UUID
    trainer_id: UUID
    created_at: datetime
    updated_at: datetime
    messages: List[AgentMessage] = []
    model_config = ConfigDict(from_attributes=True)

from pydantic import BaseModel, ConfigDict, Field, field_validator

class AgentChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    session_id: Optional[UUID] = None

    @field_validator('message')
    @classmethod
    def message_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('A mensagem não pode estar vazia')
        return v.strip()

class AgentActionExecuteRequest(BaseModel):
    message_id: UUID
    action: str # "approve" or "reject"
