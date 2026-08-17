from typing import Any, List                                          
from fastapi import APIRouter, Depends, HTTPException                 
from sqlalchemy.ext.asyncio import AsyncSession                       
from sqlalchemy.future import select                                  
from sqlalchemy.orm import selectinload
from sqlalchemy import func, cast, Date, update                               
from app.api import deps                                              
from app.db.session import get_db                                     
from app.models.workout import Workout, WorkoutItem, MethodologyType                   
from app.models.exercise import ExerciseLibrary                       
from app.models.user import User, UserRole, student_trainer_association
from app.schemas.workout import WorkoutCreate, WorkoutUpdate, Workout as WorkoutSchema, WeeklyStatusResponse, SmartWarning
from app.models.workout import WorkoutSession, WorkoutSessionStatus   
from app.models.notification import NotificationType
from app.services.notification_service import create_notification
from uuid import UUID
from datetime import datetime, timedelta, timezone
router = APIRouter()

@router.get("/", response_model=List[WorkoutSchema])
async def read_workouts(
    skip: int = 0,
    limit: int = 100,
    student_id: UUID = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Retrieve workouts.
    Cleans up abandoned IN_PROGRESS sessions (>6 hours old).
    """
    # Clean up abandoned sessions (IN_PROGRESS for >6 hours)
    six_hours_ago = datetime.utcnow() - timedelta(hours=6)
    cleanup_result = await db.execute(
        update(WorkoutSession)
        .where(
            (WorkoutSession.status == WorkoutSessionStatus.IN_PROGRESS) &
            (WorkoutSession.start_time < six_hours_ago)
        )
        .values(status=WorkoutSessionStatus.COMPLETED)
    )
    if cleanup_result.rowcount > 0:
        await db.commit()

    if current_user.role == UserRole.STUDENT:
        result = await db.execute(
            select(Workout)
            .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise), selectinload(Workout.sessions))
            .filter(Workout.user_id == current_user.id)
            .order_by(Workout.scheduled_for.desc(), Workout.id.desc())
            .offset(skip)
            .limit(limit)
        )
    else:
        # Trainer sees workouts of their students
        query = select(Workout).options(selectinload(Workout.items).selectinload(WorkoutItem.exercise), selectinload(Workout.sessions))

        if student_id:
            # Filter by specific student
            # First verify student belongs to trainer
            student_check = await db.execute(
                select(User)
                .options(selectinload(User.trainers))
                .filter(User.id == student_id)
            )
            student = student_check.scalars().first()
            if not student or not any(t.id == current_user.id for t in student.trainers):
                print(f"DEBUG: Access denied. Student {student_id} does not belong to trainer {current_user.id}")
                raise HTTPException(status_code=403, detail="Student does not belong to this trainer")

            query = query.filter(Workout.user_id == student_id)
        else:
            # Show all workouts from trainer's students
            query = query.join(User, Workout.user_id == User.id).join(
                student_trainer_association, User.id == student_trainer_association.c.student_id
            ).filter(student_trainer_association.c.trainer_id == current_user.id)

        query = query.order_by(Workout.scheduled_for.desc(), Workout.id.desc())
        result = await db.execute(query.offset(skip).limit(limit))
    return result.scalars().all()

@router.get("/weekly-status", response_model=WeeklyStatusResponse)
async def get_weekly_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get weekly status for the current user (student).
    Returns completed days (0-6, Sun-Sat), whether today is completed, and the next workout.
    """
    if current_user.role != UserRole.STUDENT:
        # For trainers, this might need different logic or be invalid
        # For now, return empty/default
        return WeeklyStatusResponse(completed_days=[], today_completed=False, next_workout=None)

    # 1. Calculate week range (Sunday to Saturday)
    # Assuming UTC for simplicity, but ideally should use user's timezone
    now = datetime.utcnow()
    # Adjust to Brazil time (UTC-3) for "today" logic if needed, but keeping it simple for now
    # Or better, rely on client to interpret, but we need to know "completed days" relative to something.
    # Let's use naive calculation based on current server time.
    
    # Find start of week (Sunday)
    # weekday(): Mon=0, Sun=6. 
    # We want Sun=0, Sat=6 for the response to match JS getDay()
    # Python: Mon=0...Sun=6
    # If today is Mon(0), last Sun was yesterday (-1 day)
    # If today is Sun(6), last Sun was today (0 days ago)
    
    today_weekday_python = now.weekday() # 0-6 (Mon-Sun)
    # Convert to 0-6 (Sun-Sat)
    # Mon(0) -> 1
    # Sun(6) -> 0
    today_weekday_js = (today_weekday_python + 1) % 7
    
    start_of_week = now - timedelta(days=today_weekday_js)
    start_of_week = start_of_week.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_week = start_of_week + timedelta(days=7)

    # 2. Query finished sessions this week
    result = await db.execute(
        select(WorkoutSession)
        .filter(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.status == WorkoutSessionStatus.COMPLETED,
            WorkoutSession.start_time >= start_of_week,
            WorkoutSession.start_time < end_of_week
        )
    )
    sessions = result.scalars().all()
    
    completed_days = set()
    today_completed = False
    
    for session in sessions:
        # Convert session time to JS weekday (0-6 Sun-Sat)
        # Assuming session.start_time is UTC or naive
        # We should probably handle timezone here properly, but for MVP:
        wd_python = session.start_time.weekday()
        wd_js = (wd_python + 1) % 7
        completed_days.add(wd_js)
        
        # Check if today
        if session.start_time.date() == now.date():
            today_completed = True
            
    # 3. Find next workout
    # Exclude workouts that already have finished sessions
    
    next_workout = None
    
    query_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if today_completed:
        query_date = query_date + timedelta(days=1)
    
    # Get upcoming workouts and filter out those with finished sessions
    result = await db.execute(
        select(Workout)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise), selectinload(Workout.sessions))
        .filter(
            Workout.user_id == current_user.id,
            Workout.scheduled_for >= query_date
        )
        .order_by(Workout.scheduled_for.asc())
    )
    workouts = result.scalars().all()
    
    # Find first workout without a finished session
    for workout in workouts:
        has_finished_session = any(
            session.status == WorkoutSessionStatus.COMPLETED 
            for session in workout.sessions
        )
        if not has_finished_session:
            next_workout = workout
            break
    
    return WeeklyStatusResponse(
        completed_days=list(completed_days),
        today_completed=today_completed,
        next_workout=next_workout
    )

@router.post("/", response_model=WorkoutSchema)
async def create_workout(
    workout_in: WorkoutCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Create new workout.
    """
    # Verify permissions: Trainer can create for student, Student can create for self
    target_student_id = workout_in.student_id
    
    if current_user.role == UserRole.STUDENT:
        # Student creating for self
        if target_student_id and target_student_id != current_user.id:
             raise HTTPException(status_code=403, detail="Students can only create workouts for themselves")
        target_student_id = current_user.id
        
    elif current_user.role == UserRole.TRAINER:
        # Trainer creating for student
        if not target_student_id:
             raise HTTPException(status_code=400, detail="Student ID required for trainers")
             
        # Verify student exists and belongs to trainer
        result = await db.execute(
            select(User)
            .options(selectinload(User.trainers))
            .filter(User.id == target_student_id)
        )
        student = result.scalars().first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
        
        # Check M:N relationship
        is_linked = any(t.id == current_user.id for t in student.trainers)
        if not is_linked:
            raise HTTPException(status_code=400, detail="Student does not belong to this trainer")
    else:
         raise HTTPException(status_code=403, detail="Not authorized")

    # Create Workout
    # Ensure naive datetime
    scheduled_for = workout_in.scheduled_for
    if scheduled_for and scheduled_for.tzinfo:
        scheduled_for = scheduled_for.replace(tzinfo=None)

    db_workout = Workout(
        name=workout_in.name,
        user_id=target_student_id,
        scheduled_for=scheduled_for,
        group_id=workout_in.group_id
    )
    db.add(db_workout)
    await db.flush()

    # Process Items
    for item_in in workout_in.items:
        # Resolve Exercise
        exercise_id = item_in.exercise_id
        if not exercise_id and hasattr(item_in, 'exercise_name') and item_in.exercise_name:
            # Look up by name
            result = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.name == item_in.exercise_name))
            exercise = result.scalars().first()
            if not exercise:
                # Create new exercise on the fly
                exercise = ExerciseLibrary(name=item_in.exercise_name, category="Uncategorized")
                db.add(exercise)
                await db.flush()
            exercise_id = exercise.id
        
        if not exercise_id:
             raise HTTPException(status_code=400, detail=f"Exercise not found or name not provided for item")

        db_item = WorkoutItem(
            workout_id=db_workout.id,
            exercise_id=exercise_id,
            sets=item_in.sets,
            reps_min=item_in.reps_min,
            reps_max=item_in.reps_max,
            reps_per_set=item_in.reps_per_set,
            duration_seconds=item_in.duration_seconds,
            weight_kg=item_in.weight_kg,
            rest_seconds=item_in.rest_seconds,
            notes=item_in.notes,
            target_zone_min_bpm=item_in.target_zone_min_bpm,
            target_zone_max_bpm=item_in.target_zone_max_bpm,
            target_rpe=item_in.target_rpe,
            superset_id=item_in.superset_id,
            methodology_type=item_in.methodology_type
        )
        db.add(db_item)

    # Commit all items once, then notify the student a single time.
    # (Previously commit + notification were inside the loop, which sent one
    #  NEW_WORKOUT notification per exercise.)
    await db.commit()
    await db.refresh(db_workout)

    if current_user.role == UserRole.TRAINER and target_student_id:
        await create_notification(
            db=db,
            user_id=target_student_id,
            type=NotificationType.NEW_WORKOUT,
            title="Novo Treino",
            body=f"Seu treinador {current_user.full_name} te enviou um novo treino: {workout_in.name}",
            data={"workout_id": str(db_workout.id), "trainer_id": str(current_user.id)}
        )

    # Reload with items
    result = await db.execute(
        select(Workout)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise), selectinload(Workout.sessions))
        .filter(Workout.id == db_workout.id)
    )
    return result.scalars().first()

@router.get("/{workout_id}", response_model=WorkoutSchema)
async def read_workout(
    workout_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get workout by ID.
    """
    result = await db.execute(
        select(Workout)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise), selectinload(Workout.sessions))
        .filter(Workout.id == workout_id)
    )
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    # Access control
    if current_user.role == UserRole.STUDENT and workout.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    if current_user.role == UserRole.TRAINER:
        # Check if student belongs to trainer
        result = await db.execute(
            select(User)
            .options(selectinload(User.trainers))
            .filter(User.id == workout.user_id)
        )
        student = result.scalars().first()
        
        is_linked = False
        if student:
             is_linked = any(t.id == current_user.id for t in student.trainers)
             
        if not student or not is_linked:
             raise HTTPException(status_code=400, detail="Not enough permissions")

    return workout

@router.put("/{workout_id}", response_model=WorkoutSchema)
async def update_workout(
    workout_id: UUID,
    workout_in: WorkoutUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Update a workout.
    """
    result = await db.execute(
        select(Workout)
        .options(selectinload(Workout.items).selectinload(WorkoutItem.exercise), selectinload(Workout.sessions))
        .filter(Workout.id == workout_id)
    )
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    # Students can fully edit their own workouts
    if current_user.role == UserRole.STUDENT:
        if workout.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not enough permissions")

    # Access control for trainers: must own the student
    elif current_user.role == UserRole.TRAINER:
        result = await db.execute(
            select(User)
            .options(selectinload(User.trainers))
            .filter(User.id == workout.user_id)
        )
        student = result.scalars().first()
        if not student or not any(t.id == current_user.id for t in student.trainers):
            raise HTTPException(status_code=403, detail="Not enough permissions")
    else:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # Update fields
    if workout_in.name is not None:
        workout.name = workout_in.name
    if workout_in.scheduled_for is not None:
        # Ensure naive datetime for Postgres TIMESTAMP WITHOUT TIME ZONE
        dt = workout_in.scheduled_for
        if dt.tzinfo is not None:
            dt = dt.replace(tzinfo=None)
        workout.scheduled_for = dt
    if workout_in.group_id is not None:
        workout.group_id = workout_in.group_id
        
    # Update items if provided (Full replacement for simplicity)
    if workout_in.items is not None:
        # Delete existing items
        for item in workout.items:
            await db.delete(item)
            
        # Add new items
        for item_in in workout_in.items:
             # Resolve Exercise (Same logic as create)
            exercise_id = item_in.exercise_id
            if not exercise_id and hasattr(item_in, 'exercise_name') and item_in.exercise_name:
                result = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.name == item_in.exercise_name))
                exercise = result.scalars().first()
                if not exercise:
                    exercise = ExerciseLibrary(name=item_in.exercise_name, category="Uncategorized")
                    db.add(exercise)
                    await db.flush()
                exercise_id = exercise.id
            
            if not exercise_id:
                 continue # Skip invalid items? Or raise error?

            db_item = WorkoutItem(
                workout_id=workout.id,
                exercise_id=exercise_id,
                sets=item_in.sets,
                reps_min=item_in.reps_min,
                reps_max=item_in.reps_max,
                reps_per_set=item_in.reps_per_set,
                duration_seconds=item_in.duration_seconds,
                weight_kg=item_in.weight_kg,
                rest_seconds=item_in.rest_seconds,
                notes=item_in.notes,
                target_zone_min_bpm=item_in.target_zone_min_bpm,
                target_zone_max_bpm=item_in.target_zone_max_bpm,
                target_rpe=item_in.target_rpe,
                superset_id=item_in.superset_id,
                methodology_type=item_in.methodology_type
            )
            db.add(db_item)

    await db.commit()
    result = await db.execute(
        select(Workout)
        .options(
            selectinload(Workout.items).selectinload(WorkoutItem.exercise),
            selectinload(Workout.sessions)
        )
        .filter(Workout.id == workout_id)
    )
    return result.scalars().first()

@router.delete("/{workout_id}")
async def delete_workout(
    workout_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Delete a workout.
    """
    result = await db.execute(
        select(Workout)
        .filter(Workout.id == workout_id)
    )
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")

    # Access control: student can delete their own, trainer can delete their students'
    if current_user.role == UserRole.STUDENT:
        if workout.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not enough permissions")
    elif current_user.role == UserRole.TRAINER:
        result = await db.execute(
            select(User)
            .options(selectinload(User.trainers))
            .filter(User.id == workout.user_id)
        )
        student = result.scalars().first()
        if not student or not any(t.id == current_user.id for t in student.trainers):
            raise HTTPException(status_code=403, detail="Not enough permissions")
    else:
        raise HTTPException(status_code=403, detail="Not authorized")

    await db.delete(workout)
    await db.commit()
    return {"message": "Workout deleted successfully"}

@router.post("/{workout_id}/favorite", response_model=WorkoutSchema)
async def toggle_favorite_workout(
    workout_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Toggle favorite status of a workout. Only the workout owner can favorite it."""
    result = await db.execute(
        select(Workout)
        .options(selectinload(Workout.items), selectinload(Workout.sessions))
        .filter(Workout.id == workout_id)
    )
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    if workout.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    workout.is_favorite = not workout.is_favorite
    await db.commit()
    await db.refresh(workout)
    return workout

@router.get("/{workout_id}/smart-warnings", response_model=List[SmartWarning])
async def get_workout_smart_warnings(
    workout_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get smart warnings for a workout.
    Checks if intense methodologies (DROP_SET, REST_PAUSE, FST_7) are applied to
    muscle groups with low recovery (< 40%).
    """
    # Fetch workout with items and exercises
    result = await db.execute(
        select(Workout)
        .options(
            selectinload(Workout.items).selectinload(WorkoutItem.exercise),
            selectinload(Workout.user)
        )
        .filter(Workout.id == workout_id)
    )
    workout = result.scalars().first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")

    # Access control
    if current_user.role == UserRole.STUDENT:
        if workout.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not enough permissions")
    elif current_user.role == UserRole.TRAINER:
        # Trainer can check warnings for their students
        result = await db.execute(
            select(User)
            .options(selectinload(User.trainers))
            .filter(User.id == workout.user_id)
        )
        student = result.scalars().first()
        if not student or not any(t.id == current_user.id for t in student.trainers):
            raise HTTPException(status_code=403, detail="Not enough permissions")
    else:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Intense methodologies that need recovery check
    intense_methodologies = {MethodologyType.DROP_SET, MethodologyType.REST_PAUSE, MethodologyType.FST_7}

    # Calculate recovery status for the student
    now = datetime.utcnow()
    lookback = now - timedelta(days=7)

    # Get completed sessions in the last 7 days
    sessions_result = await db.execute(
        select(WorkoutSession)
        .filter(
            WorkoutSession.user_id == workout.user_id,
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
    last_trained = {}
    for session in sessions:
        if not session.end_time or not session.workout:
            continue
        for item in session.workout.items:
            if item.exercise and item.exercise.muscle_group:
                group = item.exercise.muscle_group.value
                if group not in last_trained or session.end_time > last_trained[group]:
                    last_trained[group] = session.end_time

    # Check each workout item for warnings
    warnings = []
    for item in workout.items:
        if not item.exercise or item.methodology_type not in intense_methodologies:
            continue

        muscle_group = item.exercise.muscle_group.value if item.exercise.muscle_group else None
        if not muscle_group:
            continue

        # Calculate recovery percentage
        recovery_pct = 100
        if muscle_group in last_trained:
            trained_time = last_trained[muscle_group]
            if trained_time.tzinfo is not None:
                trained_time = trained_time.replace(tzinfo=None)
            hours_ago = (now - trained_time).total_seconds() / 3600

            if hours_ago < 24:
                recovery_pct = int(min(95, (hours_ago / 24) * 100))
            elif hours_ago < 48:
                recovery_pct = int(50 + ((hours_ago - 24) / 24) * 50)
            else:
                recovery_pct = 100

        # Add warning if recovery is low
        if recovery_pct < 40:
            warnings.append(SmartWarning(
                exercise_name=item.exercise_name or item.exercise.name,
                muscle_group=muscle_group,
                recovery_pct=recovery_pct,
                methodology_type=item.methodology_type.value
            ))

    return warnings
