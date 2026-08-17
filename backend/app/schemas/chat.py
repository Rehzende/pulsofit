from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import Optional, List


class ChatMessageBase(BaseModel):
    body: str


class ChatMessageCreate(ChatMessageBase):
    conversation_id: UUID


class ChatMessageRead(ChatMessageBase):
    id: UUID
    conversation_id: UUID
    sender_id: UUID
    sender_name: Optional[str] = None
    is_read: bool
    created_at: datetime
    read_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ChatConversationBase(BaseModel):
    student_id: UUID
    trainer_id: UUID


class ChatConversationCreate(ChatConversationBase):
    pass


class ChatConversationRead(ChatConversationBase):
    id: UUID
    created_at: datetime
    last_message_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ChatConversationDetail(ChatConversationRead):
    student_name: Optional[str] = None
    trainer_name: Optional[str] = None
    messages: List[ChatMessageRead] = []
    unread_count: int = 0
    is_from_trainer: bool = False  # True if current user is trainer


class ChatConversationList(BaseModel):
    id: UUID
    other_user_id: UUID
    other_user_name: Optional[str] = None
    other_user_photo_url: Optional[str] = None
    last_message_body: Optional[str] = None
    last_message_at: Optional[datetime] = None
    unread_count: int = 0
    is_from_trainer: bool  # True if current user is trainer


class WebSocketMessage(BaseModel):
    event: str
    conversation_id: Optional[UUID] = None
    body: Optional[str] = None
    sender_id: Optional[UUID] = None
    sender_name: Optional[str] = None
    message_id: Optional[UUID] = None
    is_read: Optional[bool] = None
    created_at: Optional[datetime] = None
    is_typing: Optional[bool] = None
