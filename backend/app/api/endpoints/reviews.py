"""Trainer Reviews (Testimonials) endpoints."""
from datetime import datetime
from typing import Any, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.api import deps
from app.db.session import get_db
from app.models.trainer_review import TrainerReview
from app.models.user import User, UserRole, student_trainer_association
from app.models.notification import NotificationType
from app.services.notification_service import create_notification

router = APIRouter()


# ─── Schemas ─────────────────────────────────────────────────────────────────

class ReviewCreate(BaseModel):
    trainer_id: UUID
    rating: int = Field(..., ge=1, le=5)
    text: Optional[str] = Field(None, max_length=500)


class ReviewResponse(BaseModel):
    id: UUID
    trainer_id: UUID
    student_id: Optional[UUID]
    student_name: Optional[str]
    student_photo: Optional[str]
    rating: int
    text: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ReviewStats(BaseModel):
    average_rating: float
    total_reviews: int
    reviews: List[ReviewResponse]


# ─── Endpoints ───────────────────────────────────────────────────────────────

@router.post("/", response_model=ReviewResponse, status_code=201)
async def create_review(
    body: ReviewCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Student submits a review for a trainer they have worked with."""
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="Apenas alunos podem enviar depoimentos.")

    # Verify the student has/had a relationship with this trainer
    link = await db.execute(
        select(student_trainer_association).where(
            student_trainer_association.c.student_id == current_user.id,
            student_trainer_association.c.trainer_id == body.trainer_id,
        )
    )
    if not link.first():
        raise HTTPException(
            status_code=403,
            detail="Você precisa ser aluno deste treinador para deixar um depoimento.",
        )

    # Check if already reviewed (upsert: update if exists)
    existing = await db.execute(
        select(TrainerReview).where(
            TrainerReview.trainer_id == body.trainer_id,
            TrainerReview.student_id == current_user.id,
        )
    )
    review = existing.scalars().first()

    if review:
        review.rating = body.rating
        review.text = body.text
        review.created_at = datetime.utcnow()
    else:
        review = TrainerReview(
            trainer_id=body.trainer_id,
            student_id=current_user.id,
            rating=body.rating,
            text=body.text,
        )
        db.add(review)

    await db.commit()
    await db.refresh(review)

    # Notify trainer about new review
    await create_notification(
        db=db,
        user_id=body.trainer_id,
        type=NotificationType.NEW_REVIEW,
        title="Novo depoimento! ⭐",
        body=f"{current_user.full_name or 'Um aluno'} deixou um depoimento ({body.rating}⭐).",
        data={"review_id": str(review.id), "student_name": current_user.full_name, "rating": body.rating},
    )
    await db.commit()

    return ReviewResponse(
        id=review.id,
        trainer_id=review.trainer_id,
        student_id=review.student_id,
        student_name=current_user.full_name,
        student_photo=current_user.photo_url,
        rating=review.rating,
        text=review.text,
        created_at=review.created_at,
    )


@router.get("/trainer/{trainer_id}", response_model=ReviewStats)
async def get_trainer_reviews(
    trainer_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Get all public reviews for a trainer (available to anyone logged in)."""
    result = await db.execute(
        select(TrainerReview, User)
        .outerjoin(User, TrainerReview.student_id == User.id)
        .where(
            TrainerReview.trainer_id == trainer_id,
            TrainerReview.is_public == True,
        )
        .order_by(TrainerReview.created_at.desc())
    )
    rows = result.all()

    reviews = [
        ReviewResponse(
            id=r.id,
            trainer_id=r.trainer_id,
            student_id=r.student_id,
            student_name=u.full_name if u else "Usuário removido",
            student_photo=u.photo_url if u else None,
            rating=r.rating,
            text=r.text,
            created_at=r.created_at,
        )
        for r, u in rows
    ]

    avg = round(sum(r.rating for r in reviews) / len(reviews), 1) if reviews else 0.0

    return ReviewStats(
        average_rating=avg,
        total_reviews=len(reviews),
        reviews=reviews,
    )


@router.get("/my-review/{trainer_id}", response_model=Optional[ReviewResponse])
async def get_my_review(
    trainer_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Check if the current student has already reviewed this trainer."""
    result = await db.execute(
        select(TrainerReview).where(
            TrainerReview.trainer_id == trainer_id,
            TrainerReview.student_id == current_user.id,
        )
    )
    review = result.scalars().first()
    if not review:
        return None
    return ReviewResponse(
        id=review.id,
        trainer_id=review.trainer_id,
        student_id=review.student_id,
        student_name=current_user.full_name,
        student_photo=current_user.photo_url,
        rating=review.rating,
        text=review.text,
        created_at=review.created_at,
    )
