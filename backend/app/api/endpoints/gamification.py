from typing import Any, Dict, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, cast, Date
from app.api import deps
from app.db.session import get_db
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSessionStatus, Workout, WorkoutItem
from app.models.trainer_profile import TrainerProfile
from app.schemas.workout_session import WorkoutSessionCreate, WorkoutSessionUpdate, WorkoutSession as WorkoutSessionSchema
from datetime import datetime
from uuid import UUID

router = APIRouter()


# ─────────────────────────────────────────────
# 7-DAY CHALLENGE
# ─────────────────────────────────────────────

@router.post("/challenge/start")
async def start_challenge(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Start the 7-day workout challenge for the current user."""
    if current_user.challenge_7d_started_at is not None and current_user.challenge_7d_completed_at is None:
        raise HTTPException(status_code=400, detail="Desafio já em andamento.")
    current_user.challenge_7d_started_at = datetime.utcnow()
    current_user.challenge_7d_completed_at = None
    await db.commit()
    return {"message": "Desafio de 7 dias iniciado!", "started_at": current_user.challenge_7d_started_at}


@router.get("/challenge/status")
async def get_challenge_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Get current 7-day challenge progress."""
    if current_user.challenge_7d_started_at is None:
        return {"active": False, "days_completed": 0, "completed": False, "started_at": None}

    # Count distinct workout days since challenge started
    result = await db.execute(
        select(func.count(func.distinct(cast(WorkoutSession.end_time, Date))))
        .where(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.status == WorkoutSessionStatus.COMPLETED,
            WorkoutSession.end_time >= current_user.challenge_7d_started_at,
        )
    )
    days_completed = result.scalar() or 0

    return {
        "active": current_user.challenge_7d_completed_at is None,
        "days_completed": days_completed,
        "completed": current_user.challenge_7d_completed_at is not None,
        "started_at": current_user.challenge_7d_started_at,
        "completed_at": current_user.challenge_7d_completed_at,
    }

from pydantic import BaseModel

@router.patch("/{session_id}/progress")
async def update_session_progress(
    session_id: UUID,
    progress_data: Dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Update workout session progress and check if it should be saved as draft.
    """
    result = await db.execute(select(WorkoutSession).filter(WorkoutSession.id == session_id))
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    if session.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not your session")
    
    # Update progress
    session.progress_data = progress_data
    session.last_activity_time = datetime.utcnow()
    
    # Check if session has been running for more than 2 hours
    time_elapsed = (datetime.utcnow() - session.start_time).total_seconds()
    if time_elapsed > 7200:  # 2 hours in seconds
        session.status = WorkoutSessionStatus.DRAFT
    
    await db.commit()
    await db.refresh(session)
    
    return {
        "message": "Progress updated",
        "session_id": session.id,
        "status": session.status,
        "should_save_as_draft": time_elapsed > 7200
    }

@router.get("/drafts", response_model=List[WorkoutSessionSchema])
async def get_draft_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get all draft workout sessions for the current user.
    """
    result = await db.execute(
        select(WorkoutSession)
        .filter(WorkoutSession.user_id == current_user.id)
        .filter(WorkoutSession.status == WorkoutSessionStatus.DRAFT)
        .order_by(WorkoutSession.last_activity_time.desc())
    )
    sessions = result.scalars().all()
    return sessions