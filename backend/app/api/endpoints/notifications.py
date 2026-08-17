"""Notification endpoints — list, mark read, count unread, device token management."""
from typing import Any, List
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func

from app.api import deps
from app.db.session import get_db
from app.models.notification import Notification
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.notification import NotificationRead, NotificationUnreadCount
from app.schemas.device_token import DeviceTokenRegister, DeviceTokenDelete

router = APIRouter()


@router.get("/", response_model=List[NotificationRead])
async def get_notifications(
    skip: int = 0,
    limit: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """List notifications for current user, most recent first."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/unread-count", response_model=NotificationUnreadCount)
async def get_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Return count of unread notifications."""
    result = await db.execute(
        select(func.count(Notification.id))
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,  # noqa: E712
        )
    )
    count = result.scalar() or 0
    return NotificationUnreadCount(unread_count=count)


@router.put("/{notification_id}/read")
async def mark_as_read(
    notification_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Mark a single notification as read."""
    result = await db.execute(
        select(Notification).where(Notification.id == notification_id)
    )
    notification = result.scalars().first()

    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    if notification.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    notification.is_read = True
    await db.commit()
    return {"message": "Marked as read"}


@router.put("/read-all")
async def mark_all_as_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Mark all notifications as read for current user."""
    from sqlalchemy import update

    await db.execute(
        update(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,  # noqa: E712
        )
        .values(is_read=True)
    )
    await db.commit()
    return {"message": "All notifications marked as read"}


# ── Device Token ──────────────────────────────────────────────

@router.post("/device-token")
async def register_device_token(
    body: DeviceTokenRegister,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Register (or refresh) an FCM device token for push notifications."""
    result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == current_user.id,
            DeviceToken.token == body.token,
        )
    )
    existing = result.scalars().first()

    if existing:
        existing.platform = body.platform
        existing.updated_at = datetime.utcnow()
    else:
        db.add(DeviceToken(
            user_id=current_user.id,
            token=body.token,
            platform=body.platform,
        ))

    try:
        await db.commit()
    except Exception:
        # Handle race condition: token was inserted by another request
        await db.rollback()

    return {"message": "Device token registered"}


@router.delete("/device-token")
async def unregister_device_token(
    body: DeviceTokenDelete,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Remove an FCM device token (called on logout)."""
    result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == current_user.id,
            DeviceToken.token == body.token,
        )
    )
    device = result.scalars().first()
    if device:
        await db.delete(device)
        await db.commit()
    return {"message": "Device token removed"}


@router.post("/test-push")
async def send_test_notification(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Send a test push notification to current user (debugging)."""
    from app.services.notification_service import create_notification
    from app.models.notification import NotificationType

    await create_notification(
        db=db,
        user_id=current_user.id,
        type=NotificationType.NEW_WORKOUT,
        title="Teste de Notificação 🔔",
        body="Se você vê isso, push está funcionando!",
        data={"test": "true"},
    )
    await db.commit()
    return {"message": "Test notification sent"}


@router.post("/test-push-all")
async def send_test_notification_all(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Send a test push notification to all users with registered tokens (admin debugging)."""
    from app.services.notification_service import create_notification
    from app.models.notification import NotificationType

    # Get all unique users with device tokens
    result = await db.execute(
        select(DeviceToken.user_id).distinct()
    )
    user_ids = result.scalars().all()

    sent_count = 0
    for user_id in user_ids:
        try:
            await create_notification(
                db=db,
                user_id=user_id,
                type=NotificationType.NEW_WORKOUT,
                title="Teste em Broadcast 📢",
                body="Teste de notificação para todos!",
                data={"test": "broadcast"},
            )
            sent_count += 1
        except Exception as e:
            import logging
            logging.error(f"Failed to send notification to {user_id}: {e}")

    await db.commit()
    return {
        "message": f"Test notifications sent to {sent_count} users with tokens",
        "user_count": sent_count,
    }
