from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.future import select
from sqlalchemy import func
from sqlalchemy.orm import contains_eager, selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.trainer_review import TrainerReview
from typing import List, Optional
from uuid import UUID
from app.api import deps
from app.models.user import User, UserRole
from app.models.trainer_profile import TrainerProfile
from app.models.hiring_request import HiringRequest, HiringRequestStatus
from app.schemas.marketplace import TrainerMarketplaceItem, HiringRequestRead
from app.models.notification import NotificationType
from app.services.notification_service import create_notification

from app.models.subscription_plan import SubscriptionPlan

from app.models.invite import StudentInvite, InviteStatus
from datetime import datetime

router = APIRouter()

@router.post("/link-with-token/{token}")
async def link_with_invite_token(
    token: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
):
    """
    Allow a logged-in student to instantly link with a trainer using an invite token.
    Skips the hiring request process for direct invitations.
    """
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=400, detail="Only students can use invite tokens")

    # 1. Find and validate token
    result = await db.execute(
        select(StudentInvite).filter(
            StudentInvite.token == token,
            StudentInvite.status == InviteStatus.PENDING,
            StudentInvite.expires_at > datetime.utcnow(),
        )
    )
    invite = result.scalars().first()

    if not invite:
        raise HTTPException(status_code=404, detail="Invalid or expired invite token")

    if invite.trainer_id is None:
         raise HTTPException(status_code=400, detail="This is not a trainer-specific invite")

    # 2. Check if student is already linked to this trainer
    if current_user.trainer_id == invite.trainer_id:
         return {"message": "You are already linked to this trainer"}

    # 3. Perform instant linking
    trainer = await db.get(User, invite.trainer_id)
    if not trainer:
         raise HTTPException(status_code=404, detail="Trainer no longer exists")

    current_user.trainer_id = invite.trainer_id
    
    # Update association table
    await db.refresh(current_user, attribute_names=["trainers"])
    if trainer not in current_user.trainers:
        current_user.trainers.append(trainer)

    # 4. Mark invite as used
    invite.status = InviteStatus.REGISTERED
    
    # 5. Notify trainer
    await create_notification(
        db=db,
        user_id=invite.trainer_id,
        type=NotificationType.HIRING_ACCEPTED, # Reusing type for UI simplicity
        title="🎉 Novo aluno vinculado via link!",
        body=f"{current_user.full_name or 'Um aluno'} usou seu link de convite direto.",
        data={"student_id": str(current_user.id), "student_name": current_user.full_name},
    )

    await db.commit()
    
    return {
        "message": "Successfully linked with trainer!",
        "trainer_id": str(invite.trainer_id),
        "trainer_name": trainer.full_name
    }

@router.get("/trainers", response_model=List[TrainerMarketplaceItem])
async def get_marketplace_trainers(
    db: AsyncSession = Depends(deps.get_db),
    specialty: Optional[str] = Query(None),
    name: Optional[str] = Query(None),
    modality: Optional[str] = Query(None),
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(deps.get_current_user)
):
    query = (
        select(User)
        .join(TrainerProfile)
        .options(contains_eager(User.trainer_profile))
        .outerjoin(SubscriptionPlan, User.plan_id == SubscriptionPlan.id)
        .filter(
            User.role == UserRole.TRAINER,
            TrainerProfile.is_available_for_hire == True
        )
    )

    if name:
        query = query.filter(User.full_name.ilike(f"%{name}%"))

    if specialty:
        # Postgres array contains check.
        # Note: This assumes the DB supports array operations (Postgres does).
        query = query.filter(TrainerProfile.specialties.contains([specialty]))

    if modality:
        query = query.filter(TrainerProfile.modality == modality)

    # Order by plan price descending (premium first), then by name
    query = query.order_by(SubscriptionPlan.price.desc().nulls_last(), User.full_name.asc())

    result = await db.execute(query.offset(skip).limit(limit))
    users = result.scalars().all()

    # Aggregate public review ratings for the listed trainers in a single query
    # (avoids N+1). Maps trainer_id → (avg_rating, total_reviews).
    ratings = {}
    user_ids = [u.id for u in users]
    if user_ids:
        rating_result = await db.execute(
            select(
                TrainerReview.trainer_id,
                func.avg(TrainerReview.rating),
                func.count(TrainerReview.id),
            )
            .filter(
                TrainerReview.trainer_id.in_(user_ids),
                TrainerReview.is_public == True,
            )
            .group_by(TrainerReview.trainer_id)
        )
        for trainer_id, avg_rating, total in rating_result.all():
            ratings[trainer_id] = (
                round(float(avg_rating), 1) if avg_rating is not None else None,
                total or 0,
            )

    # Fetch hiring requests for the current user (student)
    # We need to know the status of request for each trainer
    hiring_requests = {}
    if current_user.role == UserRole.STUDENT:
        req_result = await db.execute(
            select(HiringRequest).filter(HiringRequest.student_id == current_user.id)
        )
        requests = req_result.scalars().all()
        for req in requests:
            hiring_requests[req.trainer_id] = req.status

    results = []
    for user in users:
        profile = user.trainer_profile
        
        # Determine status
        status = "NONE"
        if user.id in hiring_requests:
            status = hiring_requests[user.id]
        elif current_user.trainer_id == user.id:
             status = "ACCEPTED" # Already your trainer

        results.append(TrainerMarketplaceItem(
            user_id=user.id,
            full_name=user.full_name or "Trainer",
            photo_url=user.photo_url,
            brand_name=profile.brand_name,
            logo_url=profile.logo_url,
            bio=profile.bio,
            modality=profile.modality,
            specialties=profile.specialties,
            gyms=profile.gyms,
            hourly_rate=profile.hourly_rate,
            whatsapp_number=user.whatsapp_number or profile.whatsapp_number,
            request_status=status,
            average_rating=ratings.get(user.id, (None, 0))[0],
            total_reviews=ratings.get(user.id, (None, 0))[1],
            is_verified=bool(profile.is_verified),
        ))
        
    return results

@router.get("/trainers/{trainer_id}", response_model=TrainerMarketplaceItem)
async def get_trainer_profile(
    trainer_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
):
    query = select(User).join(TrainerProfile).options(contains_eager(User.trainer_profile)).filter(
        User.id == trainer_id,
        User.role == UserRole.TRAINER,
        TrainerProfile.is_available_for_hire == True
    )
    result = await db.execute(query)
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Trainer not found or not available")

    profile = user.trainer_profile
    
    # Determine status
    status = "NONE"
    
    if current_user.role == UserRole.STUDENT:
        if current_user.trainer_id == user.id:
            status = "ACCEPTED"
        else:
            req_result = await db.execute(
                select(HiringRequest).filter(
                    HiringRequest.student_id == current_user.id,
                    HiringRequest.trainer_id == user.id
                ).order_by(HiringRequest.created_at.desc()).limit(1)
            )
            latest_req = req_result.scalars().first()
            if latest_req:
                status = latest_req.status

    return TrainerMarketplaceItem(
        user_id=user.id,
        full_name=user.full_name or "Trainer",
        photo_url=user.photo_url,
        brand_name=profile.brand_name,
        logo_url=profile.logo_url,
        bio=profile.bio,
        modality=profile.modality,
        specialties=profile.specialties,
        gyms=profile.gyms,
        hourly_rate=profile.hourly_rate,
        primary_color=profile.primary_color or "#7C3AED",
        whatsapp_number=user.whatsapp_number or profile.whatsapp_number,
        email=user.email if status == "ACCEPTED" else None,
        request_status=status
    )

@router.post("/request/{trainer_id}", response_model=HiringRequestRead)
async def create_hiring_request(
    trainer_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
):
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=400, detail="Only students can send hiring requests")

    # Check if trainer exists
    trainer = await db.get(User, trainer_id)
    if not trainer or trainer.role != UserRole.TRAINER:
        raise HTTPException(status_code=404, detail="Trainer not found")

    # Check if request already exists
    result = await db.execute(
        select(HiringRequest).filter(
            HiringRequest.student_id == current_user.id,
            HiringRequest.trainer_id == trainer_id,
            HiringRequest.status == HiringRequestStatus.PENDING
        )
    )
    existing_request = result.scalars().first()
    if existing_request:
        raise HTTPException(status_code=400, detail="Request already pending")

    request = HiringRequest(
        student_id=current_user.id,
        trainer_id=trainer_id,
        status=HiringRequestStatus.PENDING
    )
    db.add(request)

    # Notify trainer about new hiring request
    await create_notification(
        db=db,
        user_id=trainer_id,
        type=NotificationType.HIRING_REQUEST,
        title="Nova solicitação de contratação",
        body=f"{current_user.full_name or 'Um aluno'} quer treinar com você!",
        data={"hiring_request_id": str(request.id), "student_name": current_user.full_name},
    )

    await db.commit()
    await db.refresh(request)
    return request

@router.get("/requests", response_model=List[HiringRequestRead])
async def get_hiring_requests(
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
):
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Only trainers can view requests")

    result = await db.execute(
        select(HiringRequest)
        .options(selectinload(HiringRequest.student))
        .filter(
            HiringRequest.trainer_id == current_user.id,
            HiringRequest.status == HiringRequestStatus.PENDING
        )
    )
    requests = result.scalars().all()
    
    # Map to schema with student info
    response = []
    for req in requests:
        response.append(HiringRequestRead(
            id=req.id,
            student_id=req.student_id,
            trainer_id=req.trainer_id,
            status=req.status,
            created_at=req.created_at,
            student_name=req.student.full_name,
            student_photo=req.student.photo_url
        ))
    return response

@router.put("/request/{request_id}/accept", response_model=HiringRequestRead)
async def accept_hiring_request(
    request_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
):
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Only trainers can accept requests")

    request = await db.get(HiringRequest, request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
        
    if request.trainer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    if request.status != HiringRequestStatus.PENDING:
        raise HTTPException(status_code=400, detail="Request not pending")

    # Update request status
    request.status = HiringRequestStatus.ACCEPTED
    
    # Link student to trainer
    student = await db.get(User, request.student_id)
    # Load trainers to append
    await db.refresh(student, attribute_names=["trainers"])
    
    student.trainer_id = current_user.id
    if current_user not in student.trainers:
        student.trainers.append(current_user)

    # Notify student that their request was accepted
    await create_notification(
        db=db,
        user_id=request.student_id,
        type=NotificationType.HIRING_ACCEPTED,
        title="Solicitação aceita! 🎉",
        body=f"{current_user.full_name or 'Seu trainer'} aceitou seu pedido de contratação.",
        data={"hiring_request_id": str(request.id), "trainer_name": current_user.full_name},
    )

    await db.commit()
    await db.refresh(request)
    return request

@router.put("/request/{request_id}/reject", response_model=HiringRequestRead)
async def reject_hiring_request(
    request_id: UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
):
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Only trainers can reject requests")

    request = await db.get(HiringRequest, request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
        
    if request.trainer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    request.status = HiringRequestStatus.REJECTED

    # Notify student that their request was rejected
    await create_notification(
        db=db,
        user_id=request.student_id,
        type=NotificationType.HIRING_REJECTED,
        title="Solicitação recusada",
        body=f"{current_user.full_name or 'O trainer'} recusou seu pedido de contratação.",
        data={"hiring_request_id": str(request.id), "trainer_name": current_user.full_name},
    )

    await db.commit()
    await db.refresh(request)
    return request
