from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, cast, Date
from sqlalchemy.orm import selectinload
from app.api import deps
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.workout import WorkoutSession, WorkoutSessionStatus, Workout, WorkoutItem
from app.models.workout_group import WorkoutGroup
from app.models.trainer_profile import TrainerProfile
from app.schemas.workout_session import WorkoutSessionCreate, WorkoutSessionUpdate, WorkoutSession as WorkoutSessionSchema
from app.models.notification import NotificationType
from app.services.notification_service import create_notification
from app.models.user import student_trainer_association
from datetime import datetime, date, timedelta
from uuid import UUID
from pydantic import BaseModel

router = APIRouter()


async def _resolve_share_branding(db: AsyncSession, current_user: User, workout) -> tuple:
    """Branding for the share card from the trainer who OWNS the workout
    (via its group/folder), falling back to the student's primary trainer.

    A student can have multiple trainers; the share card must reflect the
    trainer that prescribed THIS workout, not whichever happens to be the
    student's primary `trainer_id`.
    Returns (brand_primary_color, brand_logo_url, trainer_instagram_handle).
    """
    trainer_id = None
    if workout is not None and getattr(workout, "group_id", None):
        grp_res = await db.execute(
            select(WorkoutGroup).filter(WorkoutGroup.id == workout.group_id)
        )
        grp = grp_res.scalars().first()
        if grp and grp.trainer_id:
            trainer_id = grp.trainer_id
    if trainer_id is None:
        trainer_id = current_user.trainer_id

    brand_color, logo_url, instagram_handle = "#000000", None, None
    if trainer_id:
        res = await db.execute(
            select(TrainerProfile).filter(TrainerProfile.user_id == trainer_id)
        )
        profile = res.scalars().first()
        if profile:
            brand_color = profile.primary_color or "#000000"
            logo_url = profile.logo_url
            instagram_handle = profile.instagram_handle
    return brand_color, logo_url, instagram_handle


async def _check_challenge(user: User, db: AsyncSession) -> bool:
    """Auto-complete the 7-day challenge when user reaches 7 distinct workout days.
    Returns True if challenge was just completed."""
    if user.challenge_7d_started_at is None or user.challenge_7d_completed_at is not None:
        return False
    result = await db.execute(
        select(func.count(func.distinct(cast(WorkoutSession.end_time, Date))))
        .where(
            WorkoutSession.user_id == user.id,
            WorkoutSession.status == WorkoutSessionStatus.COMPLETED,
            WorkoutSession.end_time >= user.challenge_7d_started_at,
        )
    )
    days = result.scalar() or 0
    if days >= 7:
        user.challenge_7d_completed_at = datetime.utcnow()
        return True
    return False


def _update_streak(user: User) -> bool:
    """Update user streak based on calendar days.
    
    Rules:
    - Only increments once per calendar day
    - If last workout was yesterday → increment streak
    - If last workout was today → keep streak as-is
    - If last workout was 2+ days ago → reset streak to 1
    
    Returns True if streak was incremented, False if already counted today.
    """
    today = datetime.utcnow().date()
    last_date: date | None = getattr(user, 'last_workout_date', None)

    if last_date is None:
        user.current_streak = 1
    elif last_date == today:
        return False
    elif (today - last_date).days == 1:
        user.current_streak = (user.current_streak or 0) + 1
    else:
        user.current_streak = 1

    user.last_workout_date = today
    if user.current_streak > (user.best_streak or 0):
        user.best_streak = user.current_streak
    return True


class WorkoutFinishRequest(BaseModel):
    workout_id: UUID
    duration_seconds: int
    average_heart_rate: Optional[int] = None
    heart_rate_data: list[dict] | None = None
    calories_burned: Optional[float] = None
    exercises_data: Optional[list] = None  # List of {exercise_id, sets} or {exercise_id, load}

class ExerciseHistoryRecord(BaseModel):
    """Response model for exercise history endpoint"""
    date: str  # YYYY-MM-DD
    session_id: UUID
    workout_name: str
    sets: list[dict]  # [{set, weight_kg, reps_done}]
    max_weight_kg: float
    total_volume: float  # sum(weight_kg * reps_done)

@router.post("/start", response_model=WorkoutSessionSchema)
async def start_session(
    session_in: WorkoutSessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Start a workout session.
    """
    # Verify workout exists
    result = await db.execute(select(Workout).filter(Workout.id == session_in.workout_id))
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    # Access control: User must own the workout (student) or be assigned it
    if workout.user_id != current_user.id:
         raise HTTPException(status_code=400, detail="This workout is not assigned to you")

    session = WorkoutSession(
        workout_id=session_in.workout_id,
        user_id=current_user.id,
        start_time=datetime.utcnow(),
        status=WorkoutSessionStatus.IN_PROGRESS
    )
    db.add(session)

    # Resolve o trainer responsável pelo treino (3 níveis de fallback)
    target_trainer_id = None

    if workout.group_id is not None:
        group_result = await db.execute(
            select(WorkoutGroup).where(WorkoutGroup.id == workout.group_id)
        )
        group = group_result.scalars().first()
        # Evita notificar o próprio aluno (grupos auto-criados onde trainer_id == student_id)
        if group and group.trainer_id != current_user.id:
            target_trainer_id = group.trainer_id

    if target_trainer_id is None and current_user.trainer_id is not None:
        target_trainer_id = current_user.trainer_id

    notification_kwargs = dict(
        db=db,
        type=NotificationType.STUDENT_TRAINING,
        title="Aluno treinando agora! 💪",
        body=f"{current_user.full_name or 'Seu aluno'} está treinando neste momento.",
        data={"student_id": str(current_user.id), "student_name": current_user.full_name, "workout_id": str(session_in.workout_id)},
    )

    if target_trainer_id is not None:
        await create_notification(user_id=target_trainer_id, **notification_kwargs)
    else:
        # Fallback: sem grupo e sem trainer_id primário → notifica todos (comportamento legado)
        trainer_ids_result = await db.execute(
            select(student_trainer_association.c.trainer_id)
            .where(student_trainer_association.c.student_id == current_user.id)
        )
        for row in trainer_ids_result.all():
            await create_notification(user_id=row[0], **notification_kwargs)

    await db.commit()
    await db.refresh(session)
    return session

@router.post("/{session_id}/heartbeat")
async def update_session_heartbeat(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Updates the last_activity_time for a session, to show it's still active.
    Called periodically by the mobile app during a workout.
    """
    result = await db.execute(
        select(WorkoutSession).filter(
            WorkoutSession.id == session_id,
            WorkoutSession.user_id == current_user.id
        )
    )
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Active session not found")

    if session.status != WorkoutSessionStatus.IN_PROGRESS:
        # Don't update a session that's already finished
        return {"status": "ignored", "message": "Session is not in progress."}
        
    session.last_activity_time = datetime.utcnow()
    await db.commit()
    
    return {"status": "ok", "last_activity": session.last_activity_time}

@router.post("/finish")
async def finish_workout_simple(
    finish_in: WorkoutFinishRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Simple finish workout endpoint. Creates a session and finishes it immediately.
    Calculates calories burned using the Keytel formula with a safe fallback.
    """
    # Verify workout exists and ownership (IDOR check)
    result = await db.execute(select(Workout).filter(Workout.id == finish_in.workout_id))
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    if workout.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="This workout is not assigned to you")
    
    duration_min = max(1, finish_in.duration_seconds / 60)
    calories_burned = finish_in.calories_burned
    
    # 1. Calculate calories if not provided
    if calories_burned is None:
        if (finish_in.average_heart_rate and finish_in.average_heart_rate > 0 and
            current_user.weight_kg and
            current_user.birthday and
            current_user.gender):
            
            age = (datetime.utcnow().date() - current_user.birthday.date() if isinstance(current_user.birthday, datetime) else current_user.birthday).days // 365
            weight_kg = current_user.weight_kg
            hr = finish_in.average_heart_rate
            
            from app.models.user import Gender
            if current_user.gender == Gender.MALE:
                cal_per_min = ((0.6309 * hr) + (0.1988 * weight_kg) + (0.2017 * age) - 55.0969) / 4.184
            else:
                cal_per_min = ((0.4472 * hr) + (0.1263 * weight_kg) + (0.074 * age) - 20.4022) / 4.184

            calories_burned = round(max(0, cal_per_min * duration_min), 1)
        
        elif current_user.weight_kg:
            result = await db.execute(
                select(Workout)
                .where(Workout.id == finish_in.workout_id)
                .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise))
            )
            workout_with_items = result.scalars().first()
            if workout_with_items and workout_with_items.items:
                met_values = [i.exercise.met_value for i in workout_with_items.items if i.exercise and i.exercise.met_value]
                if met_values:
                    avg_met = sum(met_values) / len(met_values)
                    calories_burned = round(avg_met * current_user.weight_kg * (finish_in.duration_seconds / 3600), 1)

    # Fallback default: 5 kcal per minute
    if calories_burned is None or calories_burned <= 0:
        calories_burned = round(duration_min * 5, 1)
    
    # 2. Gamification Calculations
    xp_earned = 100 + int(duration_min)
    
    # 3. Create Session and Update User in a single Atomic Transaction
    now = datetime.utcnow()
    session = WorkoutSession(
        workout_id=finish_in.workout_id,
        user_id=current_user.id,
        start_time=now - timedelta(seconds=finish_in.duration_seconds),
        end_time=now,
        status=WorkoutSessionStatus.COMPLETED,
        calories_burned=calories_burned,
        heart_rate_data=finish_in.heart_rate_data,
        xp_earned=xp_earned,
        average_heart_rate=finish_in.average_heart_rate
    )
    db.add(session)
    
    current_user.xp_points += xp_earned
    _update_streak(current_user)
    current_user.level = (current_user.xp_points // 1000) + 1
    challenge_just_completed = await _check_challenge(current_user, db)

    # Save exercises data to progress_data (per-set or legacy single load)
    if finish_in.exercises_data:
        progress_data = {}
        for exercise_data in finish_in.exercises_data:
            exercise_id = str(exercise_data.get('exercise_id'))
            if exercise_data.get('sets'):
                # New format: per-set data
                progress_data[exercise_id] = {
                    'sets': exercise_data.get('sets')
                }
            elif exercise_data.get('load') is not None and exercise_data.get('load', 0) > 0:
                # Legacy format: single load
                progress_data[exercise_id] = {
                    'load': exercise_data.get('load')
                }
        if progress_data:
            session.progress_data = progress_data

    # Capture workout snapshot (freeze exercise data at execution time)
    finish_workout_result = await db.execute(
        select(Workout)
        .where(Workout.id == finish_in.workout_id)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise))
    )
    snapshot_workout = finish_workout_result.scalars().first()
    if snapshot_workout and snapshot_workout.items:
        session.workout_snapshot = [
            {
                "exercise_id": str(item.exercise_id),
                "exercise_name": item.exercise_name or (item.exercise.name if item.exercise else None),
                "sets": item.sets,
                "reps_min": item.reps_min,
                "reps_max": item.reps_max,
                "weight_kg": item.weight_kg,
                "rest_seconds": item.rest_seconds,
                "notes": item.notes,
            }
            for item in snapshot_workout.items
        ]

    # Branding from the trainer who owns this workout (not the primary trainer)
    brand_color, logo_url, instagram_handle = await _resolve_share_branding(
        db, current_user, snapshot_workout
    )

    await db.commit()

    return {
        "message": "Workout finished!",
        "xp_earned": xp_earned,
        "new_total_xp": current_user.xp_points,
        "calories_burned": calories_burned,
        "average_heart_rate": finish_in.average_heart_rate,
        "current_streak": current_user.current_streak,
        "is_new_streak_record": current_user.current_streak == current_user.best_streak,
        "challenge_completed": challenge_just_completed,
        "share_context": {
            "brand_primary_color": brand_color,
            "brand_logo_url": logo_url,
            "trainer_instagram_handle": instagram_handle,
            "stats": {
                "duration_minutes": int(duration_min),
                "calories": calories_burned,
                "zone_minutes": int(duration_min)
            }
        }
    }

@router.post("/{session_id}/finish")
async def finish_session(
    session_id: UUID,
    session_update: WorkoutSessionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Finish an existing workout session.
    """
    result = await db.execute(select(WorkoutSession).filter(WorkoutSession.id == session_id))
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    if session.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not your session")

    # Update session
    end_time = session_update.end_time or datetime.utcnow()
    # Normalize: remove timezone if present (asyncpg requires naive UTC datetimes)
    if end_time.tzinfo is not None:
        end_time = end_time.replace(tzinfo=None)
    session.end_time = end_time
    session.status = WorkoutSessionStatus.COMPLETED
    session.shareable_image_url = session_update.shareable_image_url

    if session_update.average_heart_rate is not None:
        session.average_heart_rate = session_update.average_heart_rate
    if session_update.heart_rate_data is not None:
        session.heart_rate_data = session_update.heart_rate_data

    # Calorie calculation
    dur_sec = session_update.duration_seconds or int((session.end_time - session.start_time).total_seconds())
    dur_min = max(1, dur_sec / 60)
    
    if session_update.calories_burned is not None:
        session.calories_burned = session_update.calories_burned
    else:
        avg_hr = session_update.average_heart_rate or session.average_heart_rate or 0
        calories_burned = None

        if (avg_hr > 0 and current_user.weight_kg and current_user.birthday and current_user.gender):
            from app.models.user import Gender
            age = (datetime.utcnow().date() - current_user.birthday.date() if isinstance(current_user.birthday, datetime) else current_user.birthday).days // 365
            if current_user.gender == Gender.MALE:
                cal_per_min = ((0.6309 * avg_hr) + (0.1988 * current_user.weight_kg) + (0.2017 * age) - 55.0969) / 4.184
            else:
                cal_per_min = ((0.4472 * avg_hr) + (0.1263 * current_user.weight_kg) + (0.074 * age) - 20.4022) / 4.184
            calories_burned = round(max(0, cal_per_min * dur_min), 1)
        elif current_user.weight_kg:
            wo_result = await db.execute(
                select(Workout)
                .where(Workout.id == session.workout_id)
                .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise))
            )
            wo = wo_result.scalars().first()
            if wo and wo.items:
                met_values = [i.exercise.met_value for i in wo.items if i.exercise and i.exercise.met_value]
                if met_values:
                    avg_met = sum(met_values) / len(met_values)
                    calories_burned = round(max(0, avg_met * current_user.weight_kg * (dur_sec / 3600)), 1)

        # Fallback default: 5 kcal per minute
        if calories_burned is None or calories_burned <= 0:
            calories_burned = round(dur_min * 5, 1)
        session.calories_burned = calories_burned

    # Gamification Logic (Consistent: 100 base + 1 per minute)
    xp_gained = 100 + int(dur_min)
    session.xp_earned = xp_gained

    current_user.xp_points += xp_gained
    _update_streak(current_user)
    current_user.level = (current_user.xp_points // 1000) + 1
    challenge_just_completed = await _check_challenge(current_user, db)

    # Save exercises data to progress_data (per-set or legacy single load)
    if session_update.exercises_data:
        progress_data = {}
        for exercise_data in session_update.exercises_data:
            if exercise_data.sets:
                # New format: per-set data
                progress_data[str(exercise_data.exercise_id)] = {
                    'sets': [
                        {
                            'set': s.set,
                            'weight_kg': s.weight_kg,
                            'reps_done': s.reps_done,
                        }
                        for s in exercise_data.sets
                    ]
                }
            elif exercise_data.load is not None and exercise_data.load > 0:
                # Legacy format: single load
                progress_data[str(exercise_data.exercise_id)] = {
                    'load': exercise_data.load
                }
        if progress_data:
            session.progress_data = progress_data

    # Capture workout snapshot (freeze exercise data at execution time)
    snapshot_result = await db.execute(
        select(Workout)
        .where(Workout.id == session.workout_id)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise))
    )
    snapshot_workout = snapshot_result.scalars().first()
    if snapshot_workout and snapshot_workout.items:
        session.workout_snapshot = [
            {
                "exercise_id": str(item.exercise_id),
                "exercise_name": item.exercise_name or (item.exercise.name if item.exercise else None),
                "sets": item.sets,
                "reps_min": item.reps_min,
                "reps_max": item.reps_max,
                "weight_kg": item.weight_kg,
                "rest_seconds": item.rest_seconds,
                "notes": item.notes,
            }
            for item in snapshot_workout.items
        ]

    await db.commit()

    # Branding from the trainer who owns this workout (not the primary trainer)
    brand_color, logo_url, instagram_handle = await _resolve_share_branding(
        db, current_user, snapshot_workout
    )

    return {
        "message": "Workout finished!",
        "session_id": session.id,
        "xp_earned": xp_gained,
        "new_total_xp": current_user.xp_points,
        "calories_burned": session.calories_burned,
        "average_heart_rate": session.average_heart_rate,
        "current_streak": current_user.current_streak,
        "is_new_streak_record": current_user.current_streak == current_user.best_streak,
        "challenge_completed": challenge_just_completed,
        "share_context": {
            "brand_primary_color": brand_color,
            "brand_logo_url": logo_url,
            "trainer_instagram_handle": instagram_handle,
            "stats": {
                "duration_minutes": int(dur_min),
                "calories": session.calories_burned,
                "zone_minutes": int(dur_min)
            }
        }
    }

@router.get("/history", response_model=List[WorkoutSessionSchema])
async def get_workout_history(
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get workout history (only COMPLETED sessions) for the current user.
    """
    result = await db.execute(
        select(WorkoutSession)
        .filter(WorkoutSession.user_id == current_user.id)
        .filter(WorkoutSession.status == WorkoutSessionStatus.COMPLETED)
        .order_by(WorkoutSession.end_time.desc())
        .offset(skip)
        .limit(limit)
    )
    sessions = result.scalars().all()
    return sessions

@router.get("/debug/all-sessions", response_model=List[dict])
async def debug_all_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Debug: Get ALL sessions for current user (any status)."""
    result = await db.execute(
        select(WorkoutSession)
        .filter(WorkoutSession.user_id == current_user.id)
        .order_by(WorkoutSession.start_time.desc())
    )
    sessions = result.scalars().all()
    return [
        {
            "id": str(s.id),
            "status": s.status.value if s.status else None,
            "start_time": s.start_time.isoformat() if s.start_time else None,
            "end_time": s.end_time.isoformat() if s.end_time else None,
            "calories_burned": s.calories_burned,
        }
        for s in sessions
    ]

@router.get("/debug/db-stats", response_model=dict)
async def debug_db_stats(
    db: AsyncSession = Depends(get_db),
) -> Any:
    """Debug: Database statistics (no auth required)."""
    users = await db.execute(select(func.count()).select_from(User))
    workouts = await db.execute(select(func.count()).select_from(Workout))
    sessions = await db.execute(select(func.count()).select_from(WorkoutSession))

    return {
        "total_users": users.scalar(),
        "total_workouts": workouts.scalar(),
        "total_sessions": sessions.scalar(),
    }

@router.get("/student/{student_id}/history", response_model=List[WorkoutSessionSchema])
async def get_student_workout_history(
    student_id: UUID,
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get workout history for a specific student (Trainer access only).
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Apenas treinadores podem ver o histórico de alunos.")

    # Verify student belongs to trainer
    student_check = await db.execute(
        select(User)
        .join(student_trainer_association, User.id == student_trainer_association.c.student_id)
        .filter(User.id == student_id, student_trainer_association.c.trainer_id == current_user.id)
    )
    student = student_check.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Aluno não encontrado ou não vinculado a você.")

    result = await db.execute(
        select(WorkoutSession)
        .filter(WorkoutSession.user_id == student_id)
        .filter(WorkoutSession.status == WorkoutSessionStatus.COMPLETED)
        .order_by(WorkoutSession.end_time.desc())
        .options(selectinload(WorkoutSession.workout))
        .offset(skip)
        .limit(limit)
    )
    sessions = result.scalars().all()
    return sessions

@router.get("/exercise-history/{exercise_id}", response_model=List[ExerciseHistoryRecord])
async def get_exercise_history(
    exercise_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get exercise progression history: all sessions with this exercise's per-set data.
    Returns sorted by date (newest first) with aggregated stats: max_weight_kg, total_volume.
    """
    from sqlalchemy.orm import selectinload

    result = await db.execute(
        select(WorkoutSession)
        .where(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.status == WorkoutSessionStatus.COMPLETED
        )
        .options(selectinload(WorkoutSession.workout))
        .order_by(WorkoutSession.end_time.desc())
    )
    sessions = result.scalars().all()

    records = []
    exercise_id_str = str(exercise_id)

    for session in sessions:
        if not session.progress_data or exercise_id_str not in session.progress_data:
            continue

        exercise_data = session.progress_data[exercise_id_str]
        sets_list = exercise_data.get('sets', [])

        if not sets_list:
            continue

        # Calculate max weight and total volume
        max_weight = 0.0
        total_volume = 0.0

        for set_data in sets_list:
            weight = set_data.get('weight_kg', 0) or 0
            reps = set_data.get('reps_done', 0) or 0

            if weight > 0:
                max_weight = max(max_weight, weight)
            if weight > 0 and reps > 0:
                total_volume += weight * reps

        if max_weight > 0 or total_volume > 0:
            records.append(
                ExerciseHistoryRecord(
                    date=session.end_time.strftime('%Y-%m-%d') if session.end_time else '',
                    session_id=session.id,
                    workout_name=session.workout.name if session.workout else 'Unknown',
                    sets=sets_list,
                    max_weight_kg=max_weight,
                    total_volume=total_volume,
                )
            )

    return records

@router.delete("/history/{session_id}")
async def delete_workout_session(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Delete a workout session from history.
    """
    result = await db.execute(select(WorkoutSession).filter(WorkoutSession.id == session_id))
    session = result.scalars().first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    if session.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not your session")
        
    await db.delete(session)
    await db.commit()
    
    return {"message": "Session deleted"}


# ─────────────────────────────────────────────
# MOOD CHECK-IN
# ─────────────────────────────────────────────

class MoodUpdateRequest(BaseModel):
    session_id: Optional[UUID] = None
    mood: int  # 1-5
    phase: str  # "before" or "after"

@router.post("/mood")
async def update_mood(
    body: MoodUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Save pre/post workout mood. If session_id not provided, saves to most recent IN_PROGRESS session."""
    session = None
    if body.session_id:
        result = await db.execute(select(WorkoutSession).filter(WorkoutSession.id == body.session_id))
        session = result.scalars().first()
    else:
        # Find the most recent in-progress session
        result = await db.execute(
            select(WorkoutSession)
            .filter(WorkoutSession.user_id == current_user.id)
            .filter(WorkoutSession.status == WorkoutSessionStatus.IN_PROGRESS)
            .order_by(WorkoutSession.start_time.desc())
        )
        session = result.scalars().first()

    if not session or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    if not (1 <= body.mood <= 5):
        raise HTTPException(status_code=400, detail="Mood must be between 1 and 5")

    if body.phase == "before":
        session.mood_before = body.mood
    elif body.phase == "after":
        session.mood_after = body.mood
    else:
        raise HTTPException(status_code=400, detail="Phase must be 'before' or 'after'")

    await db.commit()
    return {"message": "Mood saved", "session_id": session.id, "mood": body.mood, "phase": body.phase}


# ─────────────────────────────────────────────
# STREAK PROTECTOR
# ─────────────────────────────────────────────

@router.post("/streak-protector/activate")
async def activate_streak_protector(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Use a streak protector to prevent losing current streak. Replenishes once per calendar month."""
    from datetime import date
    
    # Reset if it's a new month
    now = datetime.utcnow()
    if (current_user.last_streak_protector_reset is None or
        current_user.last_streak_protector_reset.month != now.month or
        current_user.last_streak_protector_reset.year != now.year):
        current_user.streak_protectors_available = 1
        current_user.streak_protectors_used_this_month = 0
        current_user.last_streak_protector_reset = now

    if current_user.streak_protectors_available <= 0:
        raise HTTPException(
            status_code=400,
            detail="Nenhum Streak Protector disponível este mês. Reabastecer em 01 do próximo mês."
        )

    # Activate: don't break streak, consume protector
    current_user.streak_protectors_available -= 1
    current_user.streak_protectors_used_this_month += 1
    # Keep current_streak as-is (the protector prevents the reset)

    await db.commit()
    return {
        "message": "Streak Protector ativado! Sua sequência foi salva. 🛡️",
        "streak_maintained": current_user.current_streak,
        "protectors_remaining": current_user.streak_protectors_available,
    }


@router.get("/streak-protector/status")
async def get_streak_protector_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Get the user's current streak protector status."""
    from datetime import datetime
    now = datetime.utcnow()
    # Auto-reset check
    is_new_month = (current_user.last_streak_protector_reset is None or
        current_user.last_streak_protector_reset.month != now.month or
        current_user.last_streak_protector_reset.year != now.year)
    
    available = 1 if is_new_month else (current_user.streak_protectors_available or 0)
    return {
        "available": available,
        "used_this_month": 0 if is_new_month else (current_user.streak_protectors_used_this_month or 0),
        "resets_on": f"01/{now.month + 1 if now.month < 12 else 1}/{now.year if now.month < 12 else now.year + 1}",
    }


# ─────────────────────────────────────────────
# MONTHLY STATS (WRAPPED)
# ─────────────────────────────────────────────

@router.get("/monthly-stats/{year}/{month}")
async def get_monthly_stats(
    year: int,
    month: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Get monthly workout stats for the Wrapped feature."""
    from sqlalchemy.orm import selectinload
    from collections import Counter

    start = datetime(year, month, 1)
    if month == 12:
        end = datetime(year + 1, 1, 1)
    else:
        end = datetime(year, month + 1, 1)

    result = await db.execute(
        select(WorkoutSession)
        .filter(WorkoutSession.user_id == current_user.id)
        .filter(WorkoutSession.status == WorkoutSessionStatus.COMPLETED)
        .filter(WorkoutSession.end_time >= start)
        .filter(WorkoutSession.end_time < end)
        .options(selectinload(WorkoutSession.workout).selectinload(Workout.items).selectinload(WorkoutItem.exercise))
        .order_by(WorkoutSession.end_time.asc())
    )
    sessions = result.scalars().all()

    if not sessions:
        return {
            "year": year, "month": month,
            "total_sessions": 0, "total_minutes": 0,
            "total_xp": 0, "total_calories": 0,
            "max_bpm": 0, "avg_bpm": 0,
            "favorite_day": None,
            "top_muscle_group": None,
            "streak_best": 0,
            "mood_avg_before": None,
            "mood_avg_after": None,
        }

    # Aggregations
    total_duration_sec = sum(
        int((s.end_time - s.start_time).total_seconds()) if s.end_time and s.start_time else 0
        for s in sessions
    )
    total_minutes = total_duration_sec // 60
    total_xp = sum(s.xp_earned or 0 for s in sessions)
    total_calories = sum(s.calories_burned or 0 for s in sessions)

    all_bpm = [s.average_heart_rate for s in sessions if s.average_heart_rate]
    max_bpm = max(all_bpm) if all_bpm else 0
    avg_bpm = int(sum(all_bpm) / len(all_bpm)) if all_bpm else 0

    # Favorite day of week
    days_pt = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
    day_counter = Counter(s.start_time.weekday() for s in sessions if s.start_time)
    favorite_day = days_pt[day_counter.most_common(1)[0][0]] if day_counter else None

    # Top muscle group
    muscle_counter = Counter()
    for s in sessions:
        if s.workout and s.workout.items:
            for item in s.workout.items:
                if item.exercise and item.exercise.muscle_group:
                    muscle_counter[item.exercise.muscle_group.value] += 1
    top_muscle = muscle_counter.most_common(1)[0][0] if muscle_counter else None

    # Mood averages
    moods_before = [s.mood_before for s in sessions if s.mood_before]
    moods_after = [s.mood_after for s in sessions if s.mood_after]
    mood_avg_before = round(sum(moods_before) / len(moods_before), 1) if moods_before else None
    mood_avg_after = round(sum(moods_after) / len(moods_after), 1) if moods_after else None

    return {
        "year": year,
        "month": month,
        "total_sessions": len(sessions),
        "total_minutes": total_minutes,
        "total_xp": total_xp,
        "total_calories": total_calories,
        "max_bpm": max_bpm,
        "avg_bpm": avg_bpm,
        "favorite_day": favorite_day,
        "top_muscle_group": top_muscle,
        "mood_avg_before": mood_avg_before,
        "mood_avg_after": mood_avg_after,
    }

