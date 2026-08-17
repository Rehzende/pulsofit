from datetime import datetime
from typing import Optional, Any
from uuid import UUID
from pydantic import BaseModel


class NotificationRead(BaseModel):
    id: UUID
    user_id: UUID
    type: str
    title: str
    body: str
    data: Optional[dict[str, Any]] = None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationUnreadCount(BaseModel):
    unread_count: int
