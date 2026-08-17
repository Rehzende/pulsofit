"""Notification creation + FCM push dispatch."""
import json
import logging
import asyncio
from uuid import UUID
from typing import Optional, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.notification import Notification, NotificationType
from app.models.device_token import DeviceToken

logger = logging.getLogger(__name__)

# Global set for background task references (prevents GC of pending tasks)
background_tasks = set()


async def create_notification(
    db: AsyncSession,
    user_id: UUID,
    type: NotificationType,
    title: str,
    body: str,
    data: Optional[dict[str, Any]] = None,
) -> Notification:
    """Create and persist a notification, then fire-and-forget FCM push."""
    notification = Notification(
        user_id=user_id,
        type=type,
        title=title,
        body=body,
        data=data,
    )
    db.add(notification)
    await db.flush()

    # Fire-and-forget FCM push with strong reference protection
    task = asyncio.create_task(
        _send_push_to_user(user_id, title, body, data or {})
    )
    background_tasks.add(task)
    task.add_done_callback(background_tasks.discard)
    
    return notification


# ── FCM v1 HTTP API ──────────────────────────────────────────

def _get_fcm_access_token() -> Optional[str]:
    """Return a short-lived OAuth2 bearer token for the FCM v1 API."""
    from app.core.config import settings
    if not settings.GOOGLE_APPLICATION_CREDENTIALS_JSON or not settings.FCM_PROJECT_ID:
        return None
    try:
        from google.oauth2 import service_account
        import google.auth.transport.requests as google_requests

        info = json.loads(settings.GOOGLE_APPLICATION_CREDENTIALS_JSON)
        creds = service_account.Credentials.from_service_account_info(
            info,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
        creds.refresh(google_requests.Request())
        return creds.token
    except Exception as exc:
        logger.error("FCM: failed to obtain access token: %s", exc)
        return None


def _send_fcm_sync(project_id: str, token: str, title: str, body: str, data: dict) -> None:
    """Synchronous FCM v1 send — wrapped in asyncio.to_thread by caller."""
    import requests as http

    access_token = _get_fcm_access_token()
    if not access_token:
        logger.error("FCM: failed to obtain access token")
        return

    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    payload = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": {k: str(v) for k, v in data.items()},
            "android": {
                "priority": "high",
                "notification": {
                    "channel_id": "pulso_default",
                    "sound": "default",
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                }
            },
            "apns": {
                "payload": {
                    "aps": {
                        "alert": {"title": title, "body": body},
                        "sound": "default",
                        "badge": 1,
                    }
                }
            }
        }
    }
    try:
        resp = http.post(
            url,
            json=payload,
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10,
        )
        if resp.status_code in (200, 204):
            logger.info("FCM: notification sent successfully (token …%s)", token[-8:])
        else:
            logger.warning("FCM send failed (token …%s, status=%d): %s", token[-8:], resp.status_code, resp.text)
    except Exception as exc:
        logger.error("FCM request error: %s", exc)


async def _send_push_to_user(
    user_id: UUID, title: str, body: str, data: dict
) -> None:
    from app.core.config import settings
    from app.db.session import AsyncSessionLocal

    if not settings.FCM_PROJECT_ID:
        logger.warning("FCM: FCM_PROJECT_ID not configured")
        return

    if not settings.GOOGLE_APPLICATION_CREDENTIALS_JSON:
        logger.warning("FCM: GOOGLE_APPLICATION_CREDENTIALS_JSON not configured")
        return

    try:
        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(DeviceToken).where(DeviceToken.user_id == user_id)
            )
            tokens = result.scalars().all()
    except Exception as exc:
        logger.error("FCM: failed to fetch device tokens: %s", exc)
        return

    logger.info("FCM: found %d token(s) for user %s", len(tokens), user_id)

    for device in tokens:
        logger.info("FCM: sending to device (platform=%s, token=%s...)", device.platform, device.token[-8:])
        await asyncio.to_thread(
            _send_fcm_sync, settings.FCM_PROJECT_ID, device.token, title, body, data
        )
