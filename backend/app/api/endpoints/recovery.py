"""
Recovery status endpoint - analyzes workout history to determine muscle group fatigue.
"""
from datetime import datetime, timedelta
from typing import Dict
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api import deps
from app.models.user import User
from app.models.workout import WorkoutSession, Workout, WorkoutItem, WorkoutSessionStatus
from app.models.exercise import MuscleGroup

router = APIRouter()


def calculate_fatigue_status(hours_since_workout: float) -> str:
    """
    Calculate fatigue status based on hours since last workout.
    
    - < 24h: RECOVERING (Red - 100% fatigue)
    - 24-48h: LIGHT (Yellow - 50% fatigue)
    - > 48h: READY (Green - 0% fatigue)
    """
    if hours_since_workout < 24:
        return "TIRED"
    elif hours_since_workout < 48:
        return "RECOVERING"
    else:
        return "FRESH"


@router.get("/recovery")
async def get_recovery_status(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
) -> Dict[str, str]:
    """
    Get muscle group recovery status based on last 72 hours of workout history.
    
    Returns a mapping of muscle groups to their recovery status:
    - TIRED: < 24h since last workout (Red)
    - RECOVERING: 24-48h since last workout (Yellow)
    - FRESH: > 48h since last workout (Green)
    
    Example response:
    {
        "LEGS": "TIRED",
        "CHEST": "FRESH",
        "BACK": "RECOVERING"
    }
    """
    # Calculate 72 hours ago
    seventy_two_hours_ago = datetime.utcnow() - timedelta(hours=72)
    
    # Query completed workout sessions from last 72 hours
    stmt = (
        select(WorkoutSession)
        .where(WorkoutSession.user_id == current_user.id)
        .where(WorkoutSession.status == WorkoutSessionStatus.COMPLETED)
        .where(WorkoutSession.end_time >= seventy_two_hours_ago)
        .options(
            selectinload(WorkoutSession.workout).selectinload(Workout.items).selectinload(WorkoutItem.exercise)
        )
        .order_by(WorkoutSession.end_time.desc())
    )
    
    result = await db.execute(stmt)
    sessions = result.scalars().all()
    
    # Track the most recent workout time for each muscle group
    muscle_group_last_workout: Dict[MuscleGroup, datetime] = {}
    
    for session in sessions:
        if not session.workout or not session.end_time:
            continue
            
        for item in session.workout.items:
            if not item.exercise or not item.exercise.muscle_group:
                continue
                
            muscle_group = item.exercise.muscle_group
            
            # Only track the most recent workout for each muscle group
            if muscle_group not in muscle_group_last_workout:
                muscle_group_last_workout[muscle_group] = session.end_time
    
    # Calculate recovery status for each muscle group
    recovery_status: Dict[str, str] = {}
    
    now = datetime.utcnow()
    
    for muscle_group, last_workout_time in muscle_group_last_workout.items():
        hours_since = (now - last_workout_time).total_seconds() / 3600
        status = calculate_fatigue_status(hours_since)
        recovery_status[muscle_group.value] = status
    
    # If no workouts found, all muscle groups are FRESH
    if not recovery_status:
        for muscle_group in MuscleGroup:
            recovery_status[muscle_group.value] = "FRESH"
    else:
        # Add FRESH status for muscle groups that haven't been worked in 72h
        for muscle_group in MuscleGroup:
            if muscle_group.value not in recovery_status:
                recovery_status[muscle_group.value] = "FRESH"
    
    return recovery_status
