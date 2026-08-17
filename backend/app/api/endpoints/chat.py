from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import and_, or_, desc, func
from datetime import datetime
from uuid import UUID
import logging

from app.api import deps

logger = logging.getLogger(__name__)
from app.db.session import get_db
from app.models.user import User, student_trainer_association
from app.models.chat import ChatConversation, ChatMessage
from app.schemas.chat import (
    ChatMessageCreate,
    ChatMessageRead,
    ChatConversationRead,
    ChatConversationList,
    ChatConversationDetail,
)
from app.services.redis_service import redis_service


# ── Helper: Batch-load last message and unread counts ──────────────────────────
async def _load_conversation_extras(
    db: AsyncSession,
    conversation_ids: list,
    current_user_id,
) -> tuple[dict, dict]:
    """
    Batch-load last_message and unread_count for a list of conversations.
    Eliminates N+1 queries by aggregating in 2 queries instead of 2N.

    Returns:
        (last_messages: dict[conv_id -> row], unread_counts: dict[conv_id -> int])
    """
    if not conversation_ids:
        return {}, {}

    # ── Batch Query 1: Last message per conversation ──────────────
    # Get the max created_at per conversation, then join to get body
    max_dates_subq = (
        select(
            ChatMessage.conversation_id,
            func.max(ChatMessage.created_at).label("max_created_at"),
        )
        .where(ChatMessage.conversation_id.in_(conversation_ids))
        .group_by(ChatMessage.conversation_id)
        .subquery()
    )

    last_msg_result = await db.execute(
        select(
            ChatMessage.conversation_id,
            ChatMessage.body,
            ChatMessage.created_at,
        ).join(
            max_dates_subq,
            and_(
                ChatMessage.conversation_id == max_dates_subq.c.conversation_id,
                ChatMessage.created_at == max_dates_subq.c.max_created_at,
            ),
        )
    )
    last_messages = {row.conversation_id: row for row in last_msg_result.all()}

    # ── Batch Query 2: Unread count per conversation ──────────────
    unread_result = await db.execute(
        select(
            ChatMessage.conversation_id,
            func.count(ChatMessage.id).label("unread_count"),
        )
        .where(
            and_(
                ChatMessage.conversation_id.in_(conversation_ids),
                ChatMessage.sender_id != current_user_id,
                ChatMessage.is_read == False,
            )
        )
        .group_by(ChatMessage.conversation_id)
    )
    unread_counts = {row.conversation_id: row.unread_count for row in unread_result.all()}

    return last_messages, unread_counts


router = APIRouter()


@router.post("/conversations", response_model=ChatConversationList)
async def create_or_get_conversation(
    trainer_id: str = Query(None),
    student_id: str = Query(None),
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create or get existing conversation with a trainer or student"""

    logger.debug(f"create_or_get_conversation: user={current_user.id}, trainer_id={trainer_id}, student_id={student_id}")

    # Determine other user based on role
    if current_user.trainer_profile:
        # Trainer initiating: must provide student_id
        if not student_id:
            raise HTTPException(status_code=400, detail="student_id required for trainer")
        try:
            other_user_id = UUID(student_id)
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Invalid student_id format")
        other_is_trainer = False
    else:
        # Student initiating: must provide trainer_id
        if not trainer_id:
            raise HTTPException(status_code=400, detail="trainer_id required for student")
        try:
            other_user_id = UUID(trainer_id)
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Invalid trainer_id format")
        other_is_trainer = True

    # Verify other user exists
    other_user_query = select(User).options(selectinload(User.trainer_profile)).where(User.id == other_user_id)
    other_user_result = await db.execute(other_user_query)
    other_user = other_user_result.scalars().first()

    if not other_user:
        raise HTTPException(status_code=404, detail="User not found")

    # If looking for trainer, verify they have trainer profile
    if other_is_trainer and not other_user.trainer_profile:
        raise HTTPException(status_code=404, detail="Trainer not found")

    # Verify permission
    if current_user.trainer_profile:
        # Trainer initiating with student: verify association
        assoc_query = select(student_trainer_association).where(
            and_(
                student_trainer_association.c.trainer_id == current_user.id,
                student_trainer_association.c.student_id == other_user_id,
            )
        )
        assoc_result = await db.execute(assoc_query)
        if not assoc_result.first():
            raise HTTPException(status_code=403, detail="You don't have permission to chat with this student")
    else:
        # Student initiating with trainer: verify association
        assoc_query = select(student_trainer_association).where(
            and_(
                student_trainer_association.c.student_id == current_user.id,
                student_trainer_association.c.trainer_id == other_user_id,
            )
        )
        assoc_result = await db.execute(assoc_query)
        if not assoc_result.first():
            raise HTTPException(status_code=403, detail="You don't have permission to chat with this trainer")

    # Determine conversation participants
    if current_user.trainer_profile:
        conv_student_id = other_user_id
        conv_trainer_id = current_user.id
    else:
        conv_student_id = current_user.id
        conv_trainer_id = other_user_id

    # Check if conversation already exists
    existing_query = select(ChatConversation).where(
        and_(
            ChatConversation.student_id == conv_student_id,
            ChatConversation.trainer_id == conv_trainer_id,
        )
    )
    existing_result = await db.execute(existing_query)
    existing = existing_result.scalars().first()

    if existing:
        return ChatConversationList(
            id=existing.id,
            other_user_id=other_user.id,
            other_user_name=other_user.full_name or other_user.email,
            other_user_photo_url=other_user.photo_url,
            last_message_body=None,
            last_message_at=existing.last_message_at,
            unread_count=0,
            is_from_trainer=bool(other_user.trainer_profile),
        )

    # Create new conversation
    conversation = ChatConversation(
        student_id=conv_student_id,
        trainer_id=conv_trainer_id,
    )
    db.add(conversation)
    await db.commit()
    await db.refresh(conversation)

    return ChatConversationList(
        id=conversation.id,
        other_user_id=other_user.id,
        other_user_name=other_user.full_name or other_user.email,
        other_user_photo_url=other_user.photo_url,
        last_message_body=None,
        last_message_at=conversation.last_message_at,
        unread_count=0,
        is_from_trainer=bool(other_user.trainer_profile),
    )


@router.get("/conversations", response_model=list[ChatConversationList])
async def list_conversations(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all conversations for current user (trainer or student)"""

    # Filter conversations based on role
    if current_user.trainer_profile:
        # Trainers: see conversations where they are trainer (with their students)
        # OR conversations where they are student (another trainer chatting with them)
        query = select(ChatConversation).where(
            or_(
                # As trainer with their students (must be in association)
                and_(
                    ChatConversation.trainer_id == current_user.id,
                    ChatConversation.student_id.in_(
                        select(student_trainer_association.c.student_id).where(
                            student_trainer_association.c.trainer_id == current_user.id
                        )
                    ),
                ),
                # As student (another trainer initiated conversation)
                ChatConversation.student_id == current_user.id,
            )
        ).order_by(desc(ChatConversation.last_message_at)).options(
            selectinload(ChatConversation.student), selectinload(ChatConversation.trainer)
        )
    else:
        # Students: see conversations with their trainers
        query = select(ChatConversation).where(
            ChatConversation.student_id == current_user.id
        ).order_by(desc(ChatConversation.last_message_at)).options(
            selectinload(ChatConversation.student), selectinload(ChatConversation.trainer)
        )

    result = await db.execute(query)
    conversations = result.scalars().all()

    # Batch-load last_message and unread_count for all conversations at once
    # This eliminates N+1 queries: instead of 2N queries, we do 2 aggregate queries
    conversation_ids = [conv.id for conv in conversations]
    last_messages, unread_counts = await _load_conversation_extras(
        db, conversation_ids, current_user.id
    )

    conversations_list = []
    for conv in conversations:
        # Determine who is the "other" user
        is_trainer = current_user.id == conv.trainer_id
        other_user_id = conv.student_id if is_trainer else conv.trainer_id

        # Get other user details (already eager-loaded via selectinload)
        other_user = conv.student if is_trainer else conv.trainer

        # Get last message from batch results (dict lookup, no query)
        last_msg = last_messages.get(conv.id)

        conversations_list.append(
            ChatConversationList(
                id=conv.id,
                other_user_id=other_user_id,
                other_user_name=other_user.full_name if other_user else None,
                other_user_photo_url=other_user.photo_url if other_user else None,
                last_message_body=last_msg.body if last_msg else None,
                last_message_at=last_msg.created_at if last_msg else None,
                unread_count=unread_counts.get(conv.id, 0),
                is_from_trainer=is_trainer,
            )
        )

    return conversations_list


@router.get("/conversations/{conversation_id}/messages", response_model=ChatConversationDetail)
async def get_conversation_messages(
    conversation_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get messages for a conversation"""

    # Get conversation
    conv_query = select(ChatConversation).where(
        ChatConversation.id == conversation_id
    ).options(selectinload(ChatConversation.student), selectinload(ChatConversation.trainer))

    conv_result = await db.execute(conv_query)
    conversation = conv_result.scalars().first()

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found. If you're a trainer, use POST /chat/conversations/?student_id=... to create a conversation first."
        )

    # Check access: must be trainer or student in conversation
    if (current_user.id != conversation.trainer_id and
            current_user.id != conversation.student_id):
        raise HTTPException(status_code=403, detail="Access denied")



    # Get messages
    msg_query = select(ChatMessage).where(
        ChatMessage.conversation_id == conversation_id
    ).order_by(desc(ChatMessage.created_at)).limit(limit).offset(offset).options(
        selectinload(ChatMessage.sender)
    )

    msg_result = await db.execute(msg_query)
    messages = list(reversed(msg_result.scalars().all()))  # Reverse to get chronological order

    # Count unread
    unread_query = select(ChatMessage).where(
        and_(
            ChatMessage.conversation_id == conversation_id,
            ChatMessage.sender_id != current_user.id,
            ChatMessage.is_read == False,
        )
    )
    unread_result = await db.execute(unread_query)
    unread_count = len(unread_result.scalars().all())

    messages_read = [
        ChatMessageRead(
            id=msg.id,
            conversation_id=msg.conversation_id,
            sender_id=msg.sender_id,
            sender_name=msg.sender.full_name if msg.sender else None,
            body=msg.body,
            is_read=msg.is_read,
            created_at=msg.created_at,
            read_at=msg.read_at,
        )
        for msg in messages
    ]

    return ChatConversationDetail(
        id=conversation.id,
        student_id=conversation.student_id,
        trainer_id=conversation.trainer_id,
        student_name=conversation.student.full_name if conversation.student else None,
        trainer_name=conversation.trainer.full_name if conversation.trainer else None,
        created_at=conversation.created_at,
        last_message_at=conversation.last_message_at,
        messages=messages_read,
        unread_count=unread_count,
        is_from_trainer=current_user.id == conversation.trainer_id,
    )


@router.post("/messages", response_model=ChatMessageRead)
async def create_message(
    payload: ChatMessageCreate,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create new message in conversation"""

    # Get conversation
    conv_query = select(ChatConversation).where(
        ChatConversation.id == payload.conversation_id
    ).options(selectinload(ChatConversation.student), selectinload(ChatConversation.trainer))

    conv_result = await db.execute(conv_query)
    conversation = conv_result.scalars().first()

    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    # Check access
    if (current_user.id != conversation.trainer_id and
            current_user.id != conversation.student_id):
        raise HTTPException(status_code=403, detail="Access denied")



    # Create message
    message = ChatMessage(
        conversation_id=payload.conversation_id,
        sender_id=current_user.id,
        body=payload.body,
        is_read=False,
        created_at=datetime.utcnow(),
    )

    db.add(message)

    # Update conversation's last_message_at
    conversation.last_message_at = datetime.utcnow()
    db.add(conversation)

    await db.commit()
    await db.refresh(message, ["sender"])

    recipient_id = conversation.student_id if current_user.id == conversation.trainer_id else conversation.trainer_id

    ws_payload = {
        "event": "CHAT_MESSAGE",
        "message_id": str(message.id),
        "conversation_id": str(message.conversation_id),
        "sender_id": str(message.sender_id),
        "sender_name": current_user.full_name,
        "body": message.body,
        "is_read": False,
        "created_at": message.created_at.isoformat(),
    }

    # Broadcast via Redis (for chat screen polling)
    await redis_service.publish(f"chat:conv:{conversation.id}", ws_payload)

    # Broadcast via WebSocket directly to recipient (for real-time in-workout banner)
    from app.websockets.manager import manager as ws_manager
    await ws_manager.broadcast_to_user(str(recipient_id), ws_payload)
    try:
        from app.services.notification_service import create_notification
        from app.models.notification import NotificationType

        # TODO: Use NEW_CHAT once enum migration is fixed
        # For now, use STUDENT_TRAINING as a placeholder
        await create_notification(
            db=db,
            user_id=recipient_id,
            type=NotificationType.STUDENT_TRAINING,
            title=f"Mensagem de {current_user.full_name}",
            body=message.body[:80],  # First 80 chars
            data={
                "conversation_id": str(conversation.id),
                "message_id": str(message.id),
                "sender_id": str(current_user.id),
            },
        )
    except Exception as e:
        logger.warning(f"Failed to send chat notification: {e}")

    return ChatMessageRead(
        id=message.id,
        conversation_id=message.conversation_id,
        sender_id=message.sender_id,
        sender_name=current_user.full_name,
        body=message.body,
        is_read=message.is_read,
        created_at=message.created_at,
        read_at=message.read_at,
    )


@router.patch("/messages/{message_id}/read", status_code=200)
async def mark_message_read(
    message_id: UUID,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark message as read"""

    msg_query = select(ChatMessage).where(
        ChatMessage.id == message_id
    ).options(selectinload(ChatMessage.conversation))

    msg_result = await db.execute(msg_query)
    message = msg_result.scalars().first()

    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    # Check access: must be receiver of message
    if message.sender_id == current_user.id:
        raise HTTPException(status_code=403, detail="Cannot mark own messages as read")

    conversation = message.conversation

    # Check access to conversation
    if (current_user.id != conversation.trainer_id and
            current_user.id != conversation.student_id):
        raise HTTPException(status_code=403, detail="Access denied")

    # Update message
    message.is_read = True
    message.read_at = datetime.utcnow()
    db.add(message)
    await db.commit()

    # Broadcast read receipt
    await redis_service.publish(
        f"chat:conv:{conversation.id}",
        {
            "event": "READ_RECEIPT",
            "message_id": str(message.id),
            "conversation_id": str(conversation.id),
            "read_at": message.read_at.isoformat(),
        },
    )

    return {"status": "ok"}


@router.get("/available-trainers", response_model=list[dict])
async def get_available_trainers(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get list of trainers the student can chat with (those in student_trainer_association)"""

    # Check if current user is a student
    if current_user.trainer_profile:
        raise HTTPException(status_code=403, detail="Only students can view available trainers")

    # Get trainers that this student is associated with
    query = select(User).options(selectinload(User.trainer_profile)).join(
        student_trainer_association,
        student_trainer_association.c.trainer_id == User.id
    ).where(
        student_trainer_association.c.student_id == current_user.id
    )

    result = await db.execute(query)
    trainers = result.scalars().all()

    # Get existing conversations (to show conversation_id if exists)
    existing_convs_query = select(ChatConversation).where(
        ChatConversation.student_id == current_user.id
    )
    existing_result = await db.execute(existing_convs_query)
    existing_convs = existing_result.scalars().all()
    existing_conv_map = {conv.trainer_id: conv.id for conv in existing_convs}

    # Build list with all trainers (don't filter them out)
    available = []
    for trainer in trainers:
        trainer_data = {
            "id": str(trainer.id),
            "full_name": trainer.full_name,
            "photo_url": trainer.photo_url,
            "brand_name": trainer.trainer_profile.brand_name if trainer.trainer_profile else None,
            "has_conversation": str(trainer.id) in existing_conv_map,  # Add flag
            "conversation_id": str(existing_conv_map[trainer.id]) if trainer.id in existing_conv_map else None,  # Add conversation ID if exists
        }
        available.append(trainer_data)

    return available


@router.get("/available-students", response_model=list[dict])
async def get_available_students(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get list of students the trainer can chat with (those in student_trainer_association)"""

    # Check if current user is a trainer
    if not current_user.trainer_profile:
        raise HTTPException(status_code=403, detail="Only trainers can view available students")

    # Get students that this trainer is associated with
    query = select(User).join(
        student_trainer_association,
        student_trainer_association.c.student_id == User.id
    ).where(
        student_trainer_association.c.trainer_id == current_user.id
    )

    result = await db.execute(query)
    students = result.scalars().all()

    # Get existing conversations (to show conversation_id if exists)
    existing_convs_query = select(ChatConversation).where(
        ChatConversation.trainer_id == current_user.id
    )
    existing_result = await db.execute(existing_convs_query)
    existing_convs = existing_result.scalars().all()
    existing_conv_map = {conv.student_id: conv.id for conv in existing_convs}

    # Build list with all students (don't filter them out)
    available = []
    for student in students:
        student_data = {
            "id": str(student.id),
            "full_name": student.full_name,
            "photo_url": student.photo_url,
            "has_conversation": str(student.id) in existing_conv_map,  # Add flag
            "conversation_id": str(existing_conv_map[student.id]) if student.id in existing_conv_map else None,  # Add conversation ID if exists
        }
        available.append(student_data)

    return available
