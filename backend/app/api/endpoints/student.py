from typing import Any, Dict, List
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, desc
from sqlalchemy.orm import selectinload
from app.api import deps
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.workout import Workout, WorkoutItem, WorkoutSession, WorkoutSessionStatus
from app.models.exercise import ExerciseLibrary, MuscleGroup

router = APIRouter()


@router.get("/stats")
async def get_student_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Dict[str, Any]:
    """
    Get stats for the student dashboard.
    """
    if current_user.role != UserRole.STUDENT:
         raise HTTPException(status_code=400, detail="Not a student")

    stmt = (
        select(ExerciseLibrary.name, func.max(WorkoutItem.weight_kg).label("max_weight"))
        .join(WorkoutItem, ExerciseLibrary.id == WorkoutItem.exercise_id)
        .join(Workout, WorkoutItem.workout_id == Workout.id)
        .filter(Workout.user_id == current_user.id)
        .group_by(ExerciseLibrary.name)
        .having(func.max(WorkoutItem.weight_kg) != None)
        .order_by(desc("max_weight"))
        .limit(5)
    )
    
    result = await db.execute(stmt)
    pbs = [{"exercise": row[0], "weight": row[1]} for row in result.all()]

    return {
        "xp_points": current_user.xp_points,
        "current_streak": current_user.current_streak,
        "best_streak": current_user.best_streak or 0,
        "level": current_user.level,
        "personal_bests": pbs
    }


@router.get("/recovery")
async def get_recovery_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Dict[str, Any]:
    """
    Get muscle recovery status for the body map.
    Analyzes completed workout sessions to determine how recovered each muscle group is.
    - TIRED: last trained < 24h ago
    - RECOVERING: last trained 24-48h ago
    - FRESH: last trained > 48h ago or never
    """
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=400, detail="Not a student")

    now = datetime.utcnow()
    lookback = now - timedelta(days=7)  # Only look at last 7 days

    # Get completed sessions in the last 7 days with their workout items + exercises
    sessions_result = await db.execute(
        select(WorkoutSession)
        .filter(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.status == WorkoutSessionStatus.COMPLETED,
            WorkoutSession.end_time >= lookback,
            WorkoutSession.end_time != None,
        )
        .options(
            selectinload(WorkoutSession.workout)
            .selectinload(Workout.items)
            .selectinload(WorkoutItem.exercise)
        )
        .order_by(WorkoutSession.end_time.desc())
    )
    sessions = sessions_result.scalars().all()

    # Track the most recent training time for each muscle group
    all_groups = [g.value for g in MuscleGroup]
    last_trained: Dict[str, datetime] = {}

    for session in sessions:
        if not session.end_time or not session.workout:
            continue
        for item in session.workout.items:
            if item.exercise and item.exercise.muscle_group:
                group = item.exercise.muscle_group.value
                # Keep the most recent time
                if group not in last_trained or session.end_time > last_trained[group]:
                    last_trained[group] = session.end_time

    # Classify each muscle group
    muscle_groups: Dict[str, Dict[str, Any]] = {}
    fresh_count = 0

    for group in all_groups:
        trained_time = None
        hours_since = None

        if group in last_trained:
            # Ensure both datetimes are naive for comparison
            trained_time = last_trained[group]
            if trained_time.tzinfo is not None:
                trained_time = trained_time.replace(tzinfo=None)
            hours_ago = (now - trained_time).total_seconds() / 3600
            hours_since = round(hours_ago, 1)

            if hours_ago < 24:
                status = "TIRED"
                recovery_pct = int(min(95, (hours_ago / 24) * 100))
            elif hours_ago < 48:
                status = "RECOVERING"
                recovery_pct = int(50 + ((hours_ago - 24) / 24) * 50)
            else:
                status = "FRESH"
                recovery_pct = 100
                fresh_count += 1
        else:
            status = "FRESH"
            recovery_pct = 100
            fresh_count += 1

        muscle_groups[group] = {
            "status": status,
            "recovery_percentage": recovery_pct,
            "hours_since_training": hours_since,
        }

    # Overall recovery percentage
    total_pct = sum(mg["recovery_percentage"] for mg in muscle_groups.values())
    overall = int(total_pct / len(all_groups)) if all_groups else 100

    return {
        "overall_percentage": overall,
        "muscle_groups": muscle_groups,
    }
