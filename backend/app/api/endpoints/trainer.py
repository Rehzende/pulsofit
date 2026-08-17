from typing import Any, Dict
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from app.models.user import student_trainer_association
from datetime import datetime, timedelta
from app.api import deps
from app.core import security
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.workout import WorkoutSession, Workout
from app.models.trainer_profile import TrainerProfile
from app.schemas.trainer_profile import TrainerProfileUpdate, TrainerProfile as TrainerProfileSchema
from app.schemas.user import UserCreate, User as UserSchema
from app.schemas.trainer import LiveSessionResponse
from app.models.workout import WorkoutSessionStatus
from sqlalchemy.orm import selectinload
from typing import List

router = APIRouter()

@router.get("/students", response_model=List[UserSchema])
async def get_students(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get all students for the current trainer.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")

    result = await db.execute(
        select(User)
        .join(student_trainer_association, User.id == student_trainer_association.c.student_id)
        .filter(student_trainer_association.c.trainer_id == current_user.id)
        .options(selectinload(User.trainer_profile))
    )
    return result.scalars().all()

@router.post("/students/{student_id}", status_code=201, response_model=UserSchema)
async def add_student(
    student_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Add an existing student to the trainer's list.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")

    # Verify student exists and is a student
    result = await db.execute(
        select(User)
        .filter(User.id == student_id, User.role == UserRole.STUDENT)
    )
    student = result.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Check if already associated
    result = await db.execute(
        select(student_trainer_association).where(
            (student_trainer_association.c.student_id == student_id)
            & (student_trainer_association.c.trainer_id == current_user.id)
        )
    )
    if result.first():
        raise HTTPException(status_code=400, detail="Student already assigned to you")

    # Add to trainers list
    student.trainers.append(current_user)
    db.add(student)
    await db.commit()
    await db.refresh(student)
    return student

@router.delete("/students/{student_id}", status_code=204)
async def remove_student(
    student_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> None:
    """
    Remove a student from the trainer's list (unassign trainer).
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")
    
    # Verify student belongs to trainer
    result = await db.execute(
        select(User)
        .join(student_trainer_association, User.id == student_trainer_association.c.student_id)
        .filter(
            User.id == student_id,
            student_trainer_association.c.trainer_id == current_user.id,
        )
    )
    student = result.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found or not assigned to you")
    
    # Unassign trainer (remove from list)
    # Since it's a many-to-many relationship (User.trainers), we remove current_user from student.trainers
    # But we need to load the relationship first or use delete on association table if we had direct access
    # Easier to just remove from the list if loaded.
    
    # We need to load the collection to modify it
    # Re-fetch with options if needed, but let's try modifying the collection directly if loaded
    # The previous query didn't load 'trainers'.
    
    # Let's fetch student with trainers loaded
    result = await db.execute(
        select(User)
        .filter(User.id == student_id)
        .options(selectinload(User.trainers))
    )
    student = result.scalars().first()
    
    if student:
        # Remove current_user from student.trainers
        student.trainers = [t for t in student.trainers if t.id != current_user.id]
        # Also clear trainer_id if it was used for single trainer logic (legacy?)
        # The User model has 'trainer_id' column too? Let's check User model.
        if student.trainer_id == current_user.id:
             student.trainer_id = None
             
        db.add(student)
        await db.commit()

@router.get("/profile", response_model=TrainerProfileSchema)
async def get_trainer_profile(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get current trainer profile.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")
    
    result = await db.execute(select(TrainerProfile).filter(TrainerProfile.user_id == current_user.id))
    profile = result.scalars().first()
    if not profile:
        profile = TrainerProfile(user_id=current_user.id)
        db.add(profile)
        await db.commit()
        await db.refresh(profile)
    
    return profile

@router.put("/profile", response_model=TrainerProfileSchema)
async def update_trainer_profile(
    profile_in: TrainerProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Update trainer profile.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")
    
    # Find profile
    result = await db.execute(select(TrainerProfile).filter(TrainerProfile.user_id == current_user.id))
    profile = result.scalars().first()
    if not profile:
        # Should exist if trainer, but create if missing
        profile = TrainerProfile(user_id=current_user.id)
        db.add(profile)
    
    if profile_in.slug is not None:
        # Check uniqueness (exclude own profile)
        existing = await db.execute(
            select(TrainerProfile).filter(
                TrainerProfile.slug == profile_in.slug,
                TrainerProfile.user_id != current_user.id
            )
        )
        if existing.scalars().first():
            raise HTTPException(status_code=409, detail="Este slug já está em uso. Escolha outro.")
        profile.slug = profile_in.slug
    if profile_in.brand_name is not None:
        profile.brand_name = profile_in.brand_name
    if profile_in.logo_url is not None:
        profile.logo_url = profile_in.logo_url
    if profile_in.photo_url is not None:
        current_user.photo_url = profile_in.photo_url
    if profile_in.primary_color is not None:
        profile.primary_color = profile_in.primary_color
    if profile_in.whatsapp_number is not None:
        profile.whatsapp_number = profile_in.whatsapp_number
    if profile_in.instagram_handle is not None:
        profile.instagram_handle = profile_in.instagram_handle
    if profile_in.bio is not None:
        profile.bio = profile_in.bio
    if profile_in.specialties is not None:
        profile.specialties = profile_in.specialties
    if profile_in.hourly_rate is not None:
        profile.hourly_rate = profile_in.hourly_rate
    if profile_in.is_available_for_hire is not None:
        profile.is_available_for_hire = profile_in.is_available_for_hire
    if profile_in.modality is not None:
        profile.modality = profile_in.modality
    if profile_in.gyms is not None:
        profile.gyms = profile_in.gyms

    db.add(current_user)
    await db.commit()
    await db.refresh(profile)
    return profile

@router.post("/students", response_model=UserSchema)
async def create_student(
    student_in: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Trainer creates a student.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")
    
    # Check email
    result = await db.execute(select(User).filter(User.email == student_in.email))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Email already registered")
        
    user = User(
        email=student_in.email,
        hashed_password=security.get_password_hash(student_in.password),
        role=UserRole.STUDENT,
        trainer_id=current_user.id,
        resting_hr=student_in.resting_hr,
        max_hr=student_in.max_hr,
        is_active=True,
        xp_points=0,
        current_streak=0,
        level=1,
        medical_history=student_in.medical_history
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user

@router.get("/stats")
async def get_trainer_stats(
    student_id: UUID = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Dict[str, Any]:
    """
    Get aggregated stats for the trainer dashboard or specific student.
    """
    if current_user.role != UserRole.TRAINER:
         raise HTTPException(status_code=400, detail="Not a trainer")

    if student_id:
        # Stats for a specific student
        # Verify student belongs to trainer
        result = await db.execute(
            select(User).filter(User.id == student_id, User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ))
        )
        student = result.scalars().first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
            
        # Calculate attendance (last 30 days)
        now = datetime.utcnow()
        thirty_days_ago = now - timedelta(days=30)
        
        result = await db.execute(
            select(func.count(WorkoutSession.id))
            .filter(WorkoutSession.user_id == student_id, WorkoutSession.start_time >= thirty_days_ago)
        )
        sessions_last_30 = result.scalar() or 0
        # Assuming 3 workouts/week goal = ~12/month
        attendance_rate = min(100, int((sessions_last_30 / 12) * 100))
        
        return {
            "attendance_rate": attendance_rate,
            "current_streak": student.current_streak or 0,
            "sessions_last_30": sessions_last_30
        }

    # 1. Active Students
    result = await db.execute(
        select(func.count(User.id))
        .filter(User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ), User.is_active == True)
    )
    active_students = result.scalar() or 0

    # 2. Total Assigned Students (for retention)
    result = await db.execute(
        select(func.count(User.id))
        .filter(User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ))
    )
    total_students = result.scalar() or 0
    retention_rate = (active_students / total_students * 100) if total_students > 0 else 0

    # 3. Monthly Workouts (Sessions completed by students in current month)
    now = datetime.utcnow()
    start_of_month = datetime(now.year, now.month, 1)
    
    # We need to join WorkoutSession -> User -> Trainers
    # Or check if user is in trainer's students
    result = await db.execute(
        select(func.count(WorkoutSession.id))
        .join(User, WorkoutSession.user_id == User.id)
        .filter(
            User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ), 
            WorkoutSession.start_time >= start_of_month
        )
    )
    monthly_workouts = result.scalar() or 0

    # 4. Active Streaks
    result = await db.execute(
        select(func.count(User.id))
        .filter(User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ), User.current_streak > 0)
    )
    active_streaks = result.scalar() or 0

    # 5. Total Workouts (Created this month)
    result = await db.execute(
        select(func.count(Workout.id))
        .join(User, Workout.user_id == User.id)
        .filter(
            User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ),
            Workout.scheduled_for >= start_of_month
        )
    )
    total_workouts = result.scalar() or 0

    # 6. Average Attendance (of active students)
    # We can approximate this by looking at the average sessions_last_30 of active students
    # Or just use the global monthly_workouts / active_students if > 0
    avg_attendance = 0
    if active_students > 0:
        # Simple metric: Average workouts per student this month
        avg_attendance = int((monthly_workouts / active_students) * 100) # Just a percentage score for now
        # Or better, if we want "Frequency", maybe just return the raw number or a calculated score
        # The frontend expects a percentage string "X%" or similar, let's return int
    
    return {
        "active_students": active_students,
        "monthly_workouts": monthly_workouts,
        "retention_rate": round(retention_rate, 1),
        "active_streaks": active_streaks,
        "total_workouts": total_workouts,
        "avg_attendance": avg_attendance
    }

@router.get("/live-sessions", response_model=List[LiveSessionResponse])
async def get_live_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get live workout sessions for the trainer's students.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")

    three_minutes_ago = datetime.utcnow() - timedelta(minutes=3)
    
    # Query active sessions for students of this trainer
    result = await db.execute(
        select(WorkoutSession)
        .join(WorkoutSession.user)
        .filter(
            User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ),
            WorkoutSession.status == WorkoutSessionStatus.IN_PROGRESS,
            WorkoutSession.end_time == None,
            # Add a heartbeat check: either last_activity is recent,
            # or the session just started (for older app versions)
            (
                (WorkoutSession.last_activity_time != None) & (WorkoutSession.last_activity_time >= three_minutes_ago)
            ) | (
                (WorkoutSession.last_activity_time == None) & (WorkoutSession.start_time >= three_minutes_ago)
            )
        )
        .options(selectinload(WorkoutSession.user), selectinload(WorkoutSession.workout))
    )
    sessions = result.scalars().all()

    live_sessions = []
    for session in sessions:
        # Get heart rate if available
        current_hr = None
        if session.heart_rate_data:
            # Assuming heart_rate_data is a list of points: [{"timestamp": "...", "bpm": 120}, ...]
            if isinstance(session.heart_rate_data, list) and len(session.heart_rate_data) > 0:
                last_point = session.heart_rate_data[-1]
                if isinstance(last_point, dict):
                    current_hr = last_point.get("bpm") or last_point.get("value")
            elif isinstance(session.heart_rate_data, dict):
                 current_hr = session.heart_rate_data.get("current") or session.heart_rate_data.get("bpm")

        live_sessions.append(LiveSessionResponse(
            session_id=session.id,
            student_id=session.user.id,
            student_name=session.user.full_name or session.user.email,
            student_avatar=session.user.photo_url,
            student_phone=session.user.whatsapp_number,
            workout_name=session.workout.name,
            start_time=session.start_time,
            current_heart_rate=current_hr
        ))

    return live_sessions


@router.get("/engagement")
async def get_student_engagement(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Returns per-student engagement data for the trainer dashboard Engagement Board.
    risk_level: AT_RISK | IRREGULAR | ON_TRACK
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not a trainer")

    result = await db.execute(
        select(User)
        .filter(User.id.in_(
                select(student_trainer_association.c.student_id).where(
                    student_trainer_association.c.trainer_id == current_user.id
                )
            ), User.is_active == True)
    )
    students = result.scalars().all()

    from datetime import datetime, timedelta

    now = datetime.utcnow()  # naive UTC — consistent with how end_time/start_time are stored
    seven_days_ago = now - timedelta(days=7)

    engagement_data = []

    for student in students:
        # Last finished session
        last_session_result = await db.execute(
            select(WorkoutSession)
            .filter(
                WorkoutSession.user_id == student.id,
                WorkoutSession.status == WorkoutSessionStatus.COMPLETED,
                WorkoutSession.end_time != None,
            )
            .order_by(WorkoutSession.end_time.desc())
            .limit(1)
        )
        last_session = last_session_result.scalars().first()

        # Sessions in last 7 days
        week_sessions_result = await db.execute(
            select(func.count(WorkoutSession.id))
            .filter(
                WorkoutSession.user_id == student.id,
                WorkoutSession.start_time >= seven_days_ago,
                WorkoutSession.status == WorkoutSessionStatus.COMPLETED,
            )
        )
        sessions_last_7 = week_sessions_result.scalar() or 0

        # Days since last session (by calendar day, not elapsed time)
        # Normalize end_time to naive UTC in case the DB driver returns a timezone-aware value
        days_since_last = None
        if last_session and last_session.end_time:
            end_time = last_session.end_time
            if end_time.tzinfo is not None:
                end_time = end_time.replace(tzinfo=None)  # strip tz → naive UTC
            # Use calendar date comparison to avoid hour/minute issues
            days_since_last = (now.date() - end_time.date()).days

        # Risk classification
        if days_since_last is None or days_since_last >= 5:
            risk_level = "AT_RISK"
            engagement_score = max(0, 20 - (days_since_last or 30) * 2)
        elif days_since_last >= 3 or sessions_last_7 <= 1:
            risk_level = "IRREGULAR"
            engagement_score = 40 + sessions_last_7 * 10
        else:
            risk_level = "ON_TRACK"
            engagement_score = min(100, 60 + sessions_last_7 * 10 + (student.current_streak or 0) * 2)

        # Upcoming workouts count
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        upcoming_result = await db.execute(
            select(func.count(Workout.id))
            .filter(
                Workout.user_id == student.id,
                (Workout.scheduled_for >= start_of_today) | (Workout.scheduled_for == None),
            )
        )
        upcoming_workouts = upcoming_result.scalar() or 0

        engagement_data.append({
            "student_id": str(student.id),
            "student_name": student.full_name or student.email.split("@")[0],
            "student_email": student.email,
            "photo_url": student.photo_url,
            "current_streak": student.current_streak or 0,
            "sessions_last_7_days": sessions_last_7,
            "days_since_last_session": days_since_last,
            "last_session_date": last_session.end_time.isoformat() if last_session and last_session.end_time else None,
            "risk_level": risk_level,
            "engagement_score": min(100, max(0, int(engagement_score))),
            "upcoming_workouts_count": upcoming_workouts,
        })

    # Sort: AT_RISK first, IRREGULAR second, ON_TRACK last
    risk_order = {"AT_RISK": 0, "IRREGULAR": 1, "ON_TRACK": 2}
    engagement_data.sort(key=lambda x: (risk_order[x["risk_level"]], -(x["sessions_last_7_days"])))

    return engagement_data