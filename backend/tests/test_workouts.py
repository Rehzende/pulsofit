import pytest
import uuid
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime
from app.core.config import settings
from app.models.user import User, UserRole
from app.models.workout import Workout, WorkoutItem
from app.models.exercise import ExerciseLibrary
from uuid import uuid4

@pytest.fixture
async def trainer_token(client, db):
    """Register a trainer and get their access token."""
    email = "testador.personal@pulsofit.app"
    await client.post("/api/v1/auth/magic-link", json={"email": email, "desired_role": "TRAINER"})
    response = await client.post("/api/v1/auth/verify-magic-link", json={"token": "123456", "email": email})
    
    # Update Trainer Profile to enable AI
    result = await db.execute(select(User).filter(User.email == email))
    user = result.scalars().first()
    user.accepted_ai_terms_at = datetime.utcnow()
    
    from app.models.trainer_profile import TrainerProfile
    profile_result = await db.execute(select(TrainerProfile).filter(TrainerProfile.user_id == user.id))
    profile = profile_result.scalars().first()
    profile.enable_ai_workouts = True
    
    await db.commit()
    
    return response.json()["access_token"]

from unittest.mock import patch, AsyncMock

@pytest.mark.asyncio
@patch("app.api.endpoints.ai_workouts._run_trainer_generate_job", new_callable=AsyncMock)
async def test_ai_workout_generation_integrity(mock_worker, client: AsyncClient, db: AsyncSession, trainer_token, mock_gemini):
    # 1. Setup user that accepted AI terms
    user_id = str(uuid.uuid4())
    user = User(
        id=user_id,
        email="ai_test@pulso.fit",
        role=UserRole.TRAINER,
        accepted_ai_terms_at=datetime.utcnow()
    )
    ai_response = {
        "summary": "Programa de hipertrofia teste.",
        "workouts": [
            {
                "name": "Treino A - Superiores",
                "notes": "Foco em técnica",
                "exercises": [
                    {
                        "exercise_name": "Supino Reto",
                        "sets": 3,
                        "reps_min": 10,
                        "reps_max": 12,
                        "rest_seconds": 60,
                        "notes": "Controlar a descida"
                    }
                ]
            }
        ]
    }
    
    # Configure mock
    import json
    mock_gemini.generate_content.return_value.text = json.dumps(ai_response)
    
    headers = {"Authorization": f"Bearer {trainer_token}"}
    
    # 2. Generate Workout (Background task)
    # We use a student_id for IDOR check. Let's register a student first or just use a dummy that we link.
    # Actually, for the /generate endpoint, we need student_ids that belong to the trainer.
    
    # No student linked yet, so let's skip the student check for now or link one.
    # Actually, I'll bypass the student check by mocking the relationship if needed, 
    # but the easiest is to just create a student and link them.
    from app.models.user import student_trainer_association
    student = User(email="aluno.teste@gmail.com", role=UserRole.STUDENT, is_active=True)
    db.add(student)
    await db.flush()
    
    trainer_res = await db.execute(select(User).filter(User.email == "testador.personal@pulsofit.app"))
    trainer = trainer_res.scalars().first()
    
    await db.execute(
        student_trainer_association.insert().values(
            student_id=student.id,
            trainer_id=trainer.id
        )
    )
    await db.commit()

    # Request generation
    payload = {
        "student_ids": [str(student.id)],
        "text": "Monte um treino de superiores focado em supino."
    }
    
    response = await client.post(f"{settings.API_V1_STR}/ai-workouts/generate", json=payload, headers=headers)
    assert response.status_code == 202
    job_id = response.json()["job_id"]
    
    # 3. Simulate job completion (since it's a background task in FastAPI)
    # In integration tests, we can wait or manually call the worker if we want to be synchronous.
    # The /jobs/{id} endpoint will show 'pending' because we didn't run the worker.
    # 3. Simulate job completion by updating the job in the DB manually
    # We avoid running the background worker in the API test to prevent SQLite session deadlocks.
    from app.models.ai_workout_job import AIWorkoutJob
    
    job = await db.get(AIWorkoutJob, job_id)
    job.status = "DONE"
    job.result_data = ai_response
    job.completed_at = datetime.utcnow()
    await db.commit()
    
    # 4. Check Job Result via polling
    poll_response = await client.get(f"{settings.API_V1_STR}/ai-workouts/jobs/{job_id}", headers=headers)
    assert poll_response.status_code == 200
    assert poll_response.json()["status"] == "done"
    assert poll_response.json()["result"]["summary"] == ai_response["summary"]

    # 5. Save Program Integrity
    # This persists the AI data into actual Workouts/WorkoutItems
    save_payload = {
        "program_name": "Programa IA Teste",
        "workouts": ai_response["workouts"],
        "student_ids": [str(student.id)]
    }
    
    save_response = await client.post(f"{settings.API_V1_STR}/ai-workouts/save-program", json=save_payload, headers=headers)
    assert save_response.status_code == 200
    assert save_response.json()["saved_count"] == 1
    
    # 6. Verify Database Integrity
    # Check if Workout and WorkoutItem exist
    workout_res = await db.execute(select(Workout).filter(Workout.user_id == student.id))
    workout = workout_res.scalars().first()
    assert workout is not None
    assert workout.name == "Treino A - Superiores"
    
    items_res = await db.execute(select(WorkoutItem).filter(WorkoutItem.workout_id == workout.id))
    items = items_res.scalars().all()
    assert len(items) == 1
    assert items[0].sets == 3
    
    # Verify exercise was created/found
    exercise_res = await db.execute(select(ExerciseLibrary).filter(ExerciseLibrary.id == items[0].exercise_id))
    exercise = exercise_res.scalars().first()
    assert exercise is not None
    assert exercise.name == "Supino Reto"
