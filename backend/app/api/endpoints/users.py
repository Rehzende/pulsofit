from typing import Any, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from app.api import deps
from app.core import security
from app.db.session import get_db
from app.models.user import User, UserRole, SubscriptionStatus, student_trainer_association
from app.models.trainer_profile import TrainerProfile
from app.models.subscription_plan import SubscriptionPlan
from app.schemas.user import UserCreate, User as UserSchema, UserMeUpdate
from app.services.email import EmailService

router = APIRouter()

@router.post("/register", response_model=UserSchema)
async def register_user(
    user_in: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
) -> Any:
    """
    Create new user or link existing user to trainer.
    """
    # Check if user exists
    result = await db.execute(
        select(User)
        .options(
            selectinload(User.trainers),
            selectinload(User.trainer_profile)
        )
        .filter(User.email == user_in.email)
    )
    existing_user = result.scalars().first()

    if existing_user:
        # Prevent self-linking
        if user_in.trainer_id and existing_user.id == user_in.trainer_id:
            raise HTTPException(
                status_code=400,
                detail="Cannot link a user to themselves as a trainer",
            )

        # If user exists, check if we are registering as a student for a trainer
        if user_in.role == UserRole.STUDENT and user_in.trainer_id:
            # Check if already linked
            is_linked = any(t.id == user_in.trainer_id for t in existing_user.trainers)
            if is_linked:
                raise HTTPException(
                    status_code=400,
                    detail="Student already registered with this trainer",
                )

            # Link to trainer
            trainer_result = await db.execute(select(User).filter(User.id == user_in.trainer_id))
            trainer = trainer_result.scalars().first()
            if not trainer:
                raise HTTPException(status_code=404, detail="Trainer not found")

            # Validate that the trainer is actually a TRAINER role
            if trainer.role != UserRole.TRAINER:
                raise HTTPException(
                    status_code=400,
                    detail="Specified user is not a trainer",
                )

            existing_user.trainers.append(trainer)
            await db.commit()
            await db.refresh(existing_user)
            return existing_user
        else:
            # User already exists and is trying to create another account with same email
            # Return 409 Conflict (semantic: resource already exists)
            raise HTTPException(
                status_code=409,
                detail=f"An account with email '{user_in.email}' already exists. Please log in instead.",
            )
    
    # Create new user
    user = User(
        email=user_in.email,
        hashed_password=security.get_password_hash(user_in.password),
        full_name=user_in.full_name,
        birthday=user_in.birthday.replace(tzinfo=None) if user_in.birthday else None,
        photo_url=user_in.photo_url,
        whatsapp_number=user_in.whatsapp_number,
        role=user_in.role,
        resting_hr=user_in.resting_hr,
        max_hr=user_in.max_hr,
        is_active=True,
        xp_points=0,
        current_streak=0,
        level=1,
        subscription_status=SubscriptionStatus.TRIAL
    )
    
    if user_in.trainer_id:
        trainer_result = await db.execute(select(User).filter(User.id == user_in.trainer_id))
        trainer = trainer_result.scalars().first()
        if trainer:
            user.trainers.append(trainer)

    db.add(user)
    await db.flush() # Get ID
    
    # If Trainer, create TrainerProfile
    if user.role == UserRole.TRAINER:
        profile = TrainerProfile(user_id=user.id)
        db.add(profile)
        
    await db.commit()
    
    # Reload user with profile/trainers
    stmt = select(User).options(selectinload(User.trainer_profile), selectinload(User.trainers)).filter(User.id == user.id)
    result = await db.execute(stmt)
    user = result.scalars().first()
    
    # Send welcome email
    email_service = EmailService()
    
    trainer_email = None
    if user.trainers:
        trainer_email = user.trainers[0].email
        
    background_tasks.add_task(
        email_service.send_welcome_email,
        user.email,
        user.full_name,
        user.role,
        trainer_email
    )

    return user

@router.get("/me", response_model=UserSchema)
async def read_user_me(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get current user.
    """
    # Reload user with trainers relationship
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile), selectinload(User.trainers))
        .filter(User.id == current_user.id)
    )
    user = result.scalars().first()

    # For trainers: ensure trainer_profile exists
    if user.role == UserRole.TRAINER and not user.trainer_profile:
        # Create missing trainer_profile
        user.trainer_profile = TrainerProfile(user_id=user.id)
        db.add(user.trainer_profile)
        await db.commit()

    # Convert to Pydantic model
    user_data = UserSchema.model_validate(user)

    # Populate plan_name if user has a plan
    if user.plan_id:
        plan_result = await db.execute(
            select(SubscriptionPlan).filter(SubscriptionPlan.id == user.plan_id)
        )
        plan = plan_result.scalars().first()
        if plan:
            user_data.plan_name = plan.name

    # If student, fetch first trainer's branding
    if user.role == UserRole.STUDENT and user.trainers:
        # Get the first trainer (in case student has multiple trainers)
        first_trainer = user.trainers[0]
        result = await db.execute(
            select(TrainerProfile)
            .filter(TrainerProfile.user_id == first_trainer.id)
        )
        profile = result.scalars().first()
        if profile:
            user_data.trainer_brand_name = profile.brand_name
            user_data.trainer_logo_url = profile.logo_url
            user_data.trainer_primary_color = profile.primary_color
            user_data.trainer_whatsapp_number = profile.whatsapp_number
            user_data.trainer_profile = profile

    return user_data

@router.put("/me", response_model=UserSchema)
async def update_user_me(
    user_in: UserMeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Update current user profile.
    """
    # Update user fields
    if user_in.full_name is not None:
        current_user.full_name = user_in.full_name
    if user_in.birthday is not None:
        current_user.birthday = user_in.birthday.replace(tzinfo=None)
    if user_in.photo_url is not None:
        current_user.photo_url = user_in.photo_url
    if user_in.whatsapp_number is not None:
        current_user.whatsapp_number = user_in.whatsapp_number
    if user_in.medical_history is not None:
        current_user.medical_history = user_in.medical_history
    if user_in.anamnesis_completed is not None:
        current_user.anamnesis_completed = user_in.anamnesis_completed
    if user_in.gender is not None:
        current_user.gender = user_in.gender
    if user_in.weight_kg is not None:
        current_user.weight_kg = user_in.weight_kg
    
    # Allow email update if needed, but usually requires verification
    # if user_in.email is not None:
    #     current_user.email = user_in.email
    
    await db.commit()
    await db.refresh(current_user)
    
    # Reload with relationships
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile), selectinload(User.trainers))
        .filter(User.id == current_user.id)
    )
    user = result.scalars().first()
    
    return UserSchema.model_validate(user)

@router.get("/students", response_model=List[UserSchema])
async def read_students(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Retrieve students for current trainer.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not enough permissions")
        
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .join(student_trainer_association, User.id == student_trainer_association.c.student_id)
        .filter(
            student_trainer_association.c.trainer_id == current_user.id
        )
    )
    students = result.scalars().all()
    
    # Fetch pending invites
    from app.models.invite import StudentInvite, InviteStatus
    invites_result = await db.execute(
        select(StudentInvite)
        .filter(
            StudentInvite.trainer_id == current_user.id,
            StudentInvite.status == InviteStatus.PENDING
        )
    )
    pending_invites = invites_result.scalars().all()
    
    # Convert invites to UserSchema-like objects
    student_list = []
    for student in students:
        student_data = UserSchema.model_validate(student)
        student_data.invite_status = "REGISTERED"
        student_list.append(student_data)
        
    for invite in pending_invites:
        # Create a dummy user object for the invite
        # We use the invite ID as the user ID for listing purposes
        from app.core.config import settings
        base_url = settings.FRONTEND_URL.rstrip('/')
        invite_link = f"{base_url}/register?token={invite.token}"
        
        invite_user = UserSchema(
            id=invite.id,
            email=invite.email,
            full_name="Pending Invite",
            role=UserRole.STUDENT,
            is_active=False,
            invite_status="PENDING",
            invite_link=invite_link,
            subscription_status=SubscriptionStatus.TRIAL
        )
        student_list.append(invite_user)
        
    return student_list

@router.get("/students/{student_id}", response_model=UserSchema)
async def read_student(
    student_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Get specific student by ID.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Not enough permissions")
        
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile), selectinload(User.trainers))
        .filter(User.id == student_id)
    )
    student = result.scalars().first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
        
    # Check if linked
    is_linked = any(t.id == current_user.id for t in student.trainers)
    if not is_linked:
        raise HTTPException(status_code=400, detail="Student does not belong to this trainer")
        
    return student


@router.post("/accept-ai-terms")
async def accept_ai_terms(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    User accepts the AI self-responsibility terms.
    Required before using AI-generated workouts or workout library.
    """
    from datetime import datetime
    current_user.accepted_ai_terms_at = datetime.utcnow()
    await db.commit()
    return {
        "message": "Termos aceitos com sucesso.",
        "accepted_at": current_user.accepted_ai_terms_at.isoformat(),
    }


@router.get("/ai-terms-status")
async def get_ai_terms_status(
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Check if the user has accepted the AI terms."""
    return {
        "accepted": current_user.accepted_ai_terms_at is not None,
        "accepted_at": current_user.accepted_ai_terms_at.isoformat() if current_user.accepted_ai_terms_at else None,
    }


@router.post("/link-trainer/{trainer_id}", response_model=UserSchema)
async def link_trainer(
    trainer_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Link the current user (student) to another trainer.
    Only students can link to a trainer.
    """
    # Only students can link to a trainer
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=403,
            detail="Only students can link to a trainer",
        )

    # Prevent self-linking
    if current_user.id == trainer_id:
        raise HTTPException(status_code=400, detail="Cannot link to yourself")

    # Verify trainer exists and is a trainer
    result = await db.execute(
        select(User)
        .filter(User.id == trainer_id, User.role == UserRole.TRAINER)
        .options(selectinload(User.trainer_profile))
    )
    trainer = result.scalars().first()
    if not trainer:
        raise HTTPException(status_code=404, detail="Trainer not found")

    # Check if already linked
    result = await db.execute(
        select(student_trainer_association).where(
            (student_trainer_association.c.student_id == current_user.id)
            & (student_trainer_association.c.trainer_id == trainer_id)
        )
    )
    if result.first():
        raise HTTPException(status_code=400, detail="Already linked to this trainer")

    # Load trainers relationship and add
    result = await db.execute(
        select(User)
        .filter(User.id == current_user.id)
        .options(selectinload(User.trainers))
    )
    user = result.scalars().first()
    user.trainers.append(trainer)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.put("/me/role", response_model=UserSchema)
async def upgrade_to_trainer(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Upgrade current user from STUDENT to TRAINER role.
    Creates a TrainerProfile if it doesn't exist.
    """
    # Only students can upgrade to trainer
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=403,
            detail="Only students can request to become a trainer",
        )

    if current_user.role == UserRole.TRAINER:
        raise HTTPException(
            status_code=400,
            detail="User is already a trainer"
        )

    # Update role to TRAINER
    current_user.role = UserRole.TRAINER

    # Ensure TrainerProfile exists
    if not current_user.trainer_profile:
        current_user.trainer_profile = TrainerProfile(user_id=current_user.id)

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    # Reload with relationships
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainer_profile))
        .filter(User.id == current_user.id)
    )
    user = result.scalars().first()

    return UserSchema.model_validate(user)


@router.delete("/me")
async def delete_account(
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Exclui permanentemente a conta do usuário autenticado e todos os seus dados.
    Esta ação é irreversível.
    """
    from sqlalchemy import delete as sa_delete, update as sa_update
    from app.models.magic_link import MagicLink
    from app.models.notification import Notification
    from app.models.assessment import BodyAssessment
    from app.models.trainer_review import TrainerReview
    from app.models.workout import Workout
    from app.models.invite import StudentInvite

    # Capturar dados antes do delete — após db.delete o objeto fica inacessível
    user_id = current_user.id
    user_email = current_user.email
    user_name = current_user.full_name or current_user.email
    user_role = current_user.role

    # 1. Desvincular associações aluno↔treinador
    await db.execute(
        sa_delete(student_trainer_association).where(
            (student_trainer_association.c.student_id == user_id)
            | (student_trainer_association.c.trainer_id == user_id)
        )
    )

    # 2. Deletar magic links
    await db.execute(sa_delete(MagicLink).where(MagicLink.user_id == user_id))

    # 3. Deletar notificações
    await db.execute(sa_delete(Notification).where(Notification.user_id == user_id))

    # 4. Deletar avaliações corporais
    await db.execute(sa_delete(BodyAssessment).where(BodyAssessment.user_id == user_id))

    # 6. Deletar convites enviados (apenas se for treinador)
    await db.execute(sa_delete(StudentInvite).where(StudentInvite.trainer_id == user_id))

    # 6.1 Reviews & Hiring Requests: anonimizar vínculo pessoal
    from app.models.hiring_request import HiringRequest
    # LGPD: remover vínculo pessoal, mas manter log de transação acadêmica/profissional
    if user_role == UserRole.STUDENT:
        await db.execute(
            sa_update(TrainerReview)
            .where(TrainerReview.student_id == user_id)
            .values(student_id=None)
        )
        await db.execute(
            sa_update(HiringRequest)
            .where(HiringRequest.student_id == user_id)
            .values(student_id=None)
        )
    else:
        # Treinador saindo: remover todas as reviews e requests associadas
        await db.execute(sa_delete(TrainerReview).where(TrainerReview.trainer_id == user_id))
        await db.execute(sa_delete(HiringRequest).where(HiringRequest.trainer_id == user_id))

    # 7. Deletar treinos próprios (cascade derruba workout_items e sessions)
    # Treinos de alunos NÃO são afetados — Workout.user_id aponta para o aluno
    workouts_result = await db.execute(
        select(Workout).where(Workout.user_id == user_id)
    )
    for workout in workouts_result.scalars().all():
        await db.delete(workout)

    # 8. Deletar o usuário (cascade derruba trainer_profile, workout_groups, device_tokens)
    await db.delete(current_user)

    await db.commit()

    # Enviar e-mail de confirmação em background (falha silenciosa — não invalida a deleção)
    background_tasks.add_task(
        EmailService().send_account_deletion_email, user_email, user_name
    )

    return {"message": "Conta e todos os dados associados foram excluídos permanentemente."}