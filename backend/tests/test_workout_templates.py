import pytest
import uuid
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User, UserRole, student_trainer_association
from app.models.workout_template import WorkoutTemplate

@pytest.fixture
async def trainer_student_setup(client, db):
    # Register trainer
    trainer_email = "trainer_template@pulsofit.app"
    await client.post("/api/v1/auth/magic-link", json={"email": trainer_email, "desired_role": "TRAINER"})
    resp_trainer = await client.post("/api/v1/auth/verify-magic-link", json={"token": "123456", "email": trainer_email})
    trainer_token = resp_trainer.json()["access_token"]

    result = await db.execute(select(User).filter(User.email == trainer_email))
    trainer = result.scalars().first()

    # Create student
    student = User(email="student_template@pulsofit.app", role=UserRole.STUDENT, is_active=True)
    db.add(student)
    await db.flush()

    # Link student to trainer
    await db.execute(
        student_trainer_association.insert().values(
            student_id=student.id,
            trainer_id=trainer.id
        )
    )
    await db.commit()
    
    return trainer, trainer_token, student

@pytest.mark.asyncio
async def test_apply_workout_template(client: AsyncClient, db: AsyncSession, trainer_student_setup):
    trainer, trainer_token, student = trainer_student_setup
    
    # 1. Create a template
    template_id = uuid.uuid4()
    template = WorkoutTemplate(
        id=template_id,
        trainer_id=trainer.id,
        name="Hypertrophy Template",
        description="A great template"
    )
    db.add(template)
    await db.commit()

    headers = {"Authorization": f"Bearer {trainer_token}"}
    
    # 2. Apply template
    payload = {
        "student_id": str(student.id)
    }
    
    response = await client.post(
        f"/api/v1/workout-templates/{template_id}/apply",
        headers=headers,
        json=payload
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Hypertrophy Template"
    assert data["user_id"] == str(student.id)
    assert "sessions" in data
