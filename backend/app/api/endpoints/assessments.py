from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.db.session import get_db
from app.models.assessment import BodyAssessment
from app.models.user import User, UserRole, student_trainer_association
from sqlalchemy.orm import selectinload
from app.schemas.assessment import BodyAssessmentCreate, BodyAssessment as BodyAssessmentSchema

router = APIRouter()

@router.post("/", response_model=BodyAssessmentSchema)
async def create_assessment(
    assessment_in: BodyAssessmentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Create new assessment.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=400, detail="Only trainers can create assessments")

    # Verify student exists and belongs to trainer
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainers))
        .filter(User.id == assessment_in.user_id)
    )
    student = result.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Check M:N relationship
    is_linked = any(t.id == current_user.id for t in student.trainers)
    if not is_linked:
        raise HTTPException(status_code=400, detail="Student does not belong to this trainer")

    assessment = BodyAssessment(
        user_id=assessment_in.user_id,
        photo_front_url=assessment_in.photo_front_url,
        photo_side_url=assessment_in.photo_side_url,
        photo_back_url=assessment_in.photo_back_url,
        body_fat_percent=assessment_in.body_fat_percent,
        muscle_mass_percent=assessment_in.muscle_mass_percent,
        status=assessment_in.status
    )
    db.add(assessment)
    await db.commit()
    await db.refresh(assessment)
    return assessment

@router.get("/", response_model=List[BodyAssessmentSchema])
async def read_assessments(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Retrieve assessments.
    """
    if current_user.role == UserRole.STUDENT:
        result = await db.execute(
            select(BodyAssessment)
            .filter(BodyAssessment.user_id == current_user.id)
            .offset(skip)
            .limit(limit)
        )
    else:
        # Trainer sees all assessments of their students? Or maybe filter by student_id query param?
        # For now, let's return all assessments for students belonging to this trainer.
        # This query is a bit more complex, let's keep it simple: return all assessments if trainer.
        # Ideally we should filter.
        # Trainer sees assessments of their students
        result = await db.execute(
            select(BodyAssessment)
            .join(User, BodyAssessment.user_id == User.id)
            .join(student_trainer_association, User.id == student_trainer_association.c.student_id)
            .filter(student_trainer_association.c.trainer_id == current_user.id)
            .offset(skip)
            .limit(limit)
        )
        
    return result.scalars().all()
