from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query, status
from app.websockets.manager import manager
from app.api import deps
from jose import jwt, JWTError
from app.core.config import settings
from app.schemas.token import TokenPayload
from app.models.user import User, UserRole
from app.db.session import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

router = APIRouter()

async def get_user_from_token(token: str, db: AsyncSession) -> User | None:
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        token_data = TokenPayload(**payload)
    except (JWTError, Exception):
        return None
    
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainers))
        .filter(User.id == token_data.sub)
    )
    return result.scalars().first()

@router.websocket("/connect")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    # Validate Token
    user = await get_user_from_token(token, db)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id = str(user.id)
    await manager.connect(websocket, user_id)
    
    try:
        while True:
            data = await websocket.receive_json()
            # Handle incoming messages
            # If Student sends "START_SESSION" or "HEART_RATE", broadcast to their Trainer(s)
            
            event_type = data.get("event")
            
            if user.role == UserRole.STUDENT:
                if event_type in ["START_SESSION", "HEART_RATE", "ONLINE"]:
                    # Broadcast to all trainers of this student
                    # We need to fetch trainers if not loaded, but we loaded them in get_user_from_token
                    
                    payload = {
                        "event": event_type,
                        "student_id": user_id,
                        "student_name": user.full_name,
                        "data": data.get("data")
                    }
                    
                    for trainer in user.trainers:
                        await manager.broadcast_to_user(str(trainer.id), payload)
                        
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
        # Optional: Notify trainers that student went offline
