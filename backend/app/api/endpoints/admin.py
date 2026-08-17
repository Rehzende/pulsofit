from typing import Any, List
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import delete, update
from app.api import deps
from app.core.config import settings
from app.db.session import get_db
from app.models.user import User, UserRole, SubscriptionStatus
from app.models.trainer_profile import TrainerProfile
from app.models.subscription_plan import SubscriptionPlan
from app.schemas.user import User as UserSchema
from app.schemas.trainer_profile import TrainerProfileUpdate
from uuid import UUID

router = APIRouter()

@router.get("/users", response_model=List[UserSchema])
async def read_all_users(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()

from sqlalchemy.orm import selectinload

@router.get("/trainers", response_model=List[UserSchema])
async def read_trainers(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    # Fetch active/inactive trainers
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.role == UserRole.TRAINER)
        .offset(skip)
        .limit(limit)
    )
    trainers = result.scalars().all()
    
    # Fetch pending invites (where trainer_id is NULL, implying system/admin invite)
    from app.models.invite import StudentInvite, InviteStatus
    invites_result = await db.execute(
        select(StudentInvite)
        .filter(StudentInvite.trainer_id == None, StudentInvite.status == InviteStatus.PENDING)
    )
    invites = invites_result.scalars().all()
    
    # Convert invites to UserSchema-like objects
    invite_users = []
    for invite in invites:
        # Create a mock User object for the invite
        # We use the schema directly or a dict that matches the schema
        invite_users.append(
            UserSchema(
                id=invite.id, # Use invite ID as temp ID
                email=invite.email,
                full_name="Pending Invite",
                role=UserRole.TRAINER,
                is_active=False,
                xp_points=0,
                current_streak=0,
                level=1,
                invite_status="PENDING",
                invite_link=f"{settings.FRONTEND_URL.rstrip('/')}/register?type=trainer&token={invite.token}"
            )
        )
        
    # Combine lists (invites first or last? Let's put them first)
    return invite_users + list(trainers)

from fastapi import Body

@router.post("/trainers", response_model=UserSchema)
async def create_trainer(
    user_in: Any = Body(...), # Explicitly mark as Body
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    # Extract data from user_in (it comes as a dict or object depending on how it's passed)
    # Since the frontend sends {email, password, full_name}, we can use that.
    # We should ideally use a Pydantic schema here, but for now let's handle the dict.
    
    # If user_in is a Pydantic model, .dict() it. If it's a dict, use it.
    if hasattr(user_in, 'dict'):
        user_data = user_in.dict()
    else:
        user_data = user_in
        
    email = user_data.get("email")
    password = user_data.get("password")
    full_name = user_data.get("full_name")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password are required")

    # 1. Check if user already exists
    result = await db.execute(select(User).filter(User.email == email))
    existing_user = result.scalars().first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists",
        )

    # 2. Get Free Plan
    plan_result = await db.execute(select(SubscriptionPlan).filter(SubscriptionPlan.name == "Free"))
    free_plan = plan_result.scalars().first()
    
    # If no free plan, try to get ANY plan or handle error
    plan_id = free_plan.id if free_plan else None
    
    # 3. Create User
    from app.core import security
    user = User(
        email=email,
        hashed_password=security.get_password_hash(password),
        full_name=full_name,
        role=UserRole.TRAINER,
        is_active=True,
        plan_id=plan_id,
        subscription_status=SubscriptionStatus.ACTIVE
    )
    db.add(user)
    await db.flush() # Get ID

    # 4. Create Trainer Profile
    profile = TrainerProfile(
        user_id=user.id,
        brand_name=full_name, # Default to name
        primary_color="#000000", # Default
        enable_iot=free_plan.features.get("iot_enabled", False) if free_plan and free_plan.features else False,
        is_verified=True # Admins create verified trainers
    )
    db.add(profile)
    
    await db.commit()
    await db.refresh(user)
    
    # Reload with profile for schema
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == user.id)
    )
    return result.scalars().first()

from app.schemas.user import UserStatusUpdate, UserIoTUpdate

@router.patch("/trainers/{trainer_id}/status", response_model=UserSchema)
async def toggle_trainer_status(
    trainer_id: UUID,
    status_in: UserStatusUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id)
    )
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    user.is_active = status_in.is_active
    await db.commit()
    await db.refresh(user)
    return user

@router.patch("/trainers/{trainer_id}/iot", response_model=UserSchema)
async def toggle_trainer_iot(
    trainer_id: UUID,
    iot_in: UserIoTUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    result = await db.execute(select(TrainerProfile).filter(TrainerProfile.user_id == trainer_id))
    profile = result.scalars().first()
    if not profile:
        # Create profile if not exists? Or error?
        raise HTTPException(status_code=404, detail="Trainer profile not found")
        
    profile.enable_iot = iot_in.iot_enabled
    await db.commit()
    
    # Return user to match frontend expectation
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id)
    )
    return result.scalars().first()

@router.get("/trainers/{trainer_id}", response_model=UserSchema)
async def get_trainer(
    trainer_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id, User.role == UserRole.TRAINER)
    )
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Trainer not found")
    return user

from app.schemas.user import UserUpdate

@router.patch("/trainers/{trainer_id}", response_model=UserSchema)
async def update_trainer(
    trainer_id: UUID,
    user_in: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id)
    )
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # SEC-6: Whitelist allowed fields (prevent mass assignment)
    UPDATABLE_FIELDS = {"full_name", "photo_url", "gender", "weight_kg", "whatsapp_number"}

    update_data = user_in.dict(exclude_unset=True)
    for field, value in update_data.items():
        if field not in UPDATABLE_FIELDS:
            raise HTTPException(status_code=400, detail=f"Cannot update field: {field}")
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)
    return user

from sqlalchemy import func

@router.get("/stats", response_model=Any)
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    from datetime import datetime, timedelta

    now = datetime.utcnow()
    since_24h = now - timedelta(hours=24)
    since_7d = now - timedelta(days=7)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    active_trainers = await db.execute(
        select(func.count(User.id)).filter(User.role == UserRole.TRAINER, User.is_active == True)
    )
    active_plans = await db.execute(
        select(func.count(SubscriptionPlan.id)).filter(SubscriptionPlan.is_active == True)
    )
    active_students = await db.execute(
        select(func.count(User.id)).filter(User.role == UserRole.STUDENT, User.is_active == True)
    )

    # Total cadastrados (trainers + students)
    total_users = await db.execute(
        select(func.count(User.id)).filter(
            User.role.in_([UserRole.TRAINER, UserRole.STUDENT])
        )
    )

    # Novos cadastros hoje
    new_today = await db.execute(
        select(func.count(User.id)).filter(
            User.role.in_([UserRole.TRAINER, UserRole.STUDENT]),
        )
    )

    # Logados últimas 24h
    logged_24h = await db.execute(
        select(func.count(User.id)).filter(
            User.last_login_at >= since_24h,
            User.role.in_([UserRole.TRAINER, UserRole.STUDENT]),
        )
    )

    # Logados últimos 7 dias
    logged_7d = await db.execute(
        select(func.count(User.id)).filter(
            User.last_login_at >= since_7d,
            User.role.in_([UserRole.TRAINER, UserRole.STUDENT]),
        )
    )

    # Receita estimada
    revenue_query = (
        select(func.sum(SubscriptionPlan.price))
        .join(User, User.plan_id == SubscriptionPlan.id)
        .filter(User.is_active == True)
    )
    total_revenue = await db.execute(revenue_query)

    return {
        "active_trainers": active_trainers.scalar() or 0,
        "active_students": active_students.scalar() or 0,
        "active_plans": active_plans.scalar() or 0,
        "total_revenue": float(total_revenue.scalar() or 0),
        "total_users": total_users.scalar() or 0,
        "logged_24h": logged_24h.scalar() or 0,
        "logged_7d": logged_7d.scalar() or 0,
    }

@router.patch("/trainers/{trainer_id}/verify", response_model=UserSchema)
async def verify_trainer(
    trainer_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    result = await db.execute(select(TrainerProfile).filter(TrainerProfile.user_id == trainer_id))
    profile = result.scalars().first()
    if not profile:
        raise HTTPException(status_code=404, detail="Trainer profile not found")

    profile.is_verified = True
    await db.commit()

    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id)
    )
    return result.scalars().first()


from pydantic import BaseModel as PydanticBaseModel

class AssignPlanRequest(PydanticBaseModel):
    plan_id: UUID

@router.patch("/trainers/{trainer_id}/plan", response_model=UserSchema)
async def assign_trainer_plan(
    trainer_id: UUID,
    body: AssignPlanRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Admin assigns a subscription plan to a trainer.
    Automatically syncs enable_ai_workouts based on plan features.ai_workouts."""
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # Load trainer
    user_result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id, User.role == UserRole.TRAINER)
    )
    trainer = user_result.scalars().first()
    if not trainer:
        raise HTTPException(status_code=404, detail="Trainer not found")

    # Load plan
    plan_result = await db.execute(
        select(SubscriptionPlan).filter(SubscriptionPlan.id == body.plan_id)
    )
    plan = plan_result.scalars().first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    # Assign plan to user
    trainer.plan_id = plan.id

    # Sync TrainerProfile feature flags from plan.features
    if trainer.trainer_profile:
        features = plan.features or {}
        trainer.trainer_profile.enable_ai_workouts = bool(features.get("ai_workouts", False))
        trainer.trainer_profile.enable_iot = bool(features.get("iot_enabled", trainer.trainer_profile.enable_iot))

    await db.commit()

    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == trainer_id)
    )
    return result.scalars().first()


@router.post("/users/{user_id}/promote-to-trainer", response_model=UserSchema)
async def promote_user_to_trainer(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Promotes any user (STUDENT or otherwise) to TRAINER role, creating a TrainerProfile."""
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    result = await db.execute(
        select(User).options(selectinload(User.trainer_profile)).filter(User.id == user_id)
    )
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="User is already a trainer")
    if user.role == UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Cannot demote admin")

    user.role = UserRole.TRAINER

    if not user.trainer_profile:
        plan_result = await db.execute(select(SubscriptionPlan).filter(SubscriptionPlan.name == "Free"))
        free_plan = plan_result.scalars().first()
        profile = TrainerProfile(
            user_id=user.id,
            brand_name=user.full_name or user.email.split("@")[0],
            primary_color="#000000",
            is_verified=True,
            enable_iot=False,
            enable_ai_workouts=False,
        )
        db.add(profile)
        if free_plan and not user.plan_id:
            user.plan_id = free_plan.id

    await db.commit()

    result = await db.execute(
        select(User).options(selectinload(User.trainer_profile)).filter(User.id == user_id)
    )
    return result.scalars().first()


@router.delete("/users/{user_id}", status_code=204)
async def delete_user(
    user_id: UUID,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
):
    """Delete any user (STUDENT or TRAINER) with full cascade. SUPER_ADMIN cannot be deleted."""
    from fastapi import BackgroundTasks as _BT
    from sqlalchemy import delete as sa_delete, update as sa_update
    from app.models.magic_link import MagicLink
    from app.models.notification import Notification
    from app.models.assessment import BodyAssessment
    from app.models.trainer_review import TrainerReview
    from app.models.workout import Workout
    from app.models.invite import StudentInvite
    from app.models.user import student_trainer_association
    from app.services.email import EmailService

    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    result = await db.execute(select(User).filter(User.id == user_id))
    target = result.scalars().first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if target.role == UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Cannot delete a super admin account")

    # Capture before delete
    target_email = target.email
    target_name = target.full_name or target.email
    target_role = target.role

    # 1. Desvincular associações aluno↔treinador
    await db.execute(
        sa_delete(student_trainer_association).where(
            (student_trainer_association.c.student_id == user_id)
            | (student_trainer_association.c.trainer_id == user_id)
        )
    )

    # 2. Magic links
    await db.execute(sa_delete(MagicLink).where(MagicLink.user_id == user_id))

    # 3. Notificações
    await db.execute(sa_delete(Notification).where(Notification.user_id == user_id))

    # 4. Avaliações corporais
    await db.execute(sa_delete(BodyAssessment).where(BodyAssessment.user_id == user_id))

    # 5. Reviews: anonimizar (aluno) ou deletar (treinador)
    if target_role == UserRole.STUDENT:
        await db.execute(
            sa_update(TrainerReview)
            .where(TrainerReview.student_id == user_id)
            .values(student_id=None)
        )
    else:
        await db.execute(sa_delete(TrainerReview).where(TrainerReview.trainer_id == user_id))

    # 6. Convites do treinador
    await db.execute(sa_delete(StudentInvite).where(StudentInvite.trainer_id == user_id))

    # 7. Treinos próprios (cascade derruba workout_items e sessions)
    workouts_result = await db.execute(select(Workout).where(Workout.user_id == user_id))
    for workout in workouts_result.scalars().all():
        await db.delete(workout)

    # 8. Deletar usuário (cascade: trainer_profile, workout_groups, device_tokens)
    await db.delete(target)
    await db.commit()

    background_tasks.add_task(
        EmailService().send_account_deletion_email, target_email, target_name
    )
    return None


@router.delete("/trainers/{trainer_id}", status_code=204)
async def delete_trainer(
    trainer_id: UUID,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
):
    """Kept for backwards compatibility — delegates to delete_user."""
    return await delete_user(trainer_id, background_tasks, db, current_user)

from app.models.exercise import ExerciseLibrary, ExerciseStatus, ExerciseGroupItem, TrainerFavoriteExercise
from app.models.workout import WorkoutItem
from app.schemas.exercise import Exercise as ExerciseSchema
from pydantic import BaseModel

@router.get("/exercises/pending", response_model=List[ExerciseSchema])
async def get_pending_exercises(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Get all exercises pending review."""
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    result = await db.execute(
        select(ExerciseLibrary).filter(ExerciseLibrary.status == ExerciseStatus.PENDING_REVIEW)
    )
    return result.scalars().all()

@router.patch("/exercises/{exercise_id}/approve", response_model=ExerciseSchema)
async def approve_exercise(
    exercise_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    result = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == exercise_id))
    exercise = result.scalars().first()
    
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")
        
    exercise.status = ExerciseStatus.APPROVED
    await db.commit()
    await db.refresh(exercise)
    return exercise

class MergeExerciseRequest(BaseModel):
    target_canonical_id: UUID

@router.post("/exercises/{exercise_id}/merge", status_code=200)
async def merge_exercise(
    exercise_id: UUID,
    req: MergeExerciseRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    # 1. Look up pending exercise
    pending_res = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == exercise_id))
    pending_ex = pending_res.scalars().first()
    if not pending_ex:
        raise HTTPException(status_code=404, detail="Pending exercise not found")
        
    # 2. Look up canonical exercise
    canonical_res = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == req.target_canonical_id))
    canonical_ex = canonical_res.scalars().first()
    if not canonical_ex:
        raise HTTPException(status_code=404, detail="Canonical exercise not found")
        
    # 3. Add alias
    current_aliases = list(canonical_ex.aliases) if canonical_ex.aliases else []
    if pending_ex.name.lower() not in [a.lower() for a in current_aliases] and pending_ex.name.lower() != canonical_ex.name.lower():
        current_aliases.append(pending_ex.name)
        canonical_ex.aliases = current_aliases
        
    # 4. Migrate associations
    await db.execute(
        update(WorkoutItem).where(WorkoutItem.exercise_id == exercise_id)
        .values(exercise_id=req.target_canonical_id)
    )
    await db.execute(
        update(ExerciseGroupItem).where(ExerciseGroupItem.exercise_id == exercise_id)
        .values(exercise_id=req.target_canonical_id)
    )
    
    await db.execute(
        delete(TrainerFavoriteExercise).where(TrainerFavoriteExercise.exercise_id == exercise_id)
    )
    
    # 5. Delete pending exercise
    await db.delete(pending_ex)
    await db.commit()
    
    return {"status": "merged_successfully"}
