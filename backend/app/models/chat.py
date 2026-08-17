import uuid
from datetime import datetime
from sqlalchemy import Column, String, UUID, ForeignKey, Boolean, DateTime, Index, UniqueConstraint, Text
from sqlalchemy.orm import relationship
from app.db.session import Base


class ChatConversation(Base):
    __tablename__ = "chat_conversations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    trainer_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)
    last_message_at = Column(DateTime, nullable=True, index=True)

    # Relationships
    student = relationship("User", foreign_keys=[student_id], backref="conversations_as_student")
    trainer = relationship("User", foreign_keys=[trainer_id], backref="conversations_as_trainer")
    messages = relationship("ChatMessage", backref="conversation", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("student_id", "trainer_id", name="unique_trainer_student_conversation"),
        Index("idx_chat_conv_last_msg", "last_message_at"),
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conversation_id = Column(UUID(as_uuid=True), ForeignKey("chat_conversations.id"), nullable=False, index=True)
    sender_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    body = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)
    read_at = Column(DateTime, nullable=True)

    # Relationships
    sender = relationship("User", foreign_keys=[sender_id], backref="sent_messages")

    __table_args__ = (
        Index("idx_chat_msg_conv_created", "conversation_id", "created_at"),
    )
