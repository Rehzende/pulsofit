import pytest
import json
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.models.user import User, UserRole
from app.models.trainer_profile import TrainerProfile
from app.models.workout import Workout, WorkoutItem
from app.models.exercise import ExerciseLibrary
from uuid import UUID


@pytest.mark.asyncio
async def test_trainer_creates_ai_workout_for_student(client, db, mocker):
    """
    Full integration test: Trainer creates a workout via AI and saves it for a student.

    Flow:
    1. Create trainer via magic link
    2. Create student via magic link
    3. Link student to trainer
    4. Accept AI terms on trainer account
    5. Enable AI feature on trainer profile
    6. Generate workout via AI (mocked Gemini response)
    7. Save the AI program for the student
    8. Verify workouts were created in the database
    """

    # Use test accounts configured in settings
    trainer_email = "testador.personal@pulsofit.app"
    student_email = "testador.aluno@pulsofit.app"

    # ─────────────────────────────────────────────────────────────────────────────
    # 1. Create Trainer
    # ─────────────────────────────────────────────────────────────────────────────
    trainer_magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": trainer_email, "desired_role": "TRAINER"}
    )
    assert trainer_magic_resp.status_code == 200
    # Short code for testador accounts is from settings.TEST_TESTER_CODE
    trainer_short_code = trainer_magic_resp.json()["short_code"]

    trainer_verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": trainer_short_code, "email": trainer_email}
    )
    assert trainer_verify_resp.status_code == 200, f"Expected 200, got {trainer_verify_resp.status_code}: {trainer_verify_resp.json()}"
    trainer_token = trainer_verify_resp.json()["access_token"]
    trainer_headers = {"Authorization": f"Bearer {trainer_token}"}

    # Get trainer ID from DB
    result = await db.execute(select(User).filter(User.email == trainer_email))
    trainer = result.scalars().first()
    assert trainer is not None
    assert trainer.role == UserRole.TRAINER
    trainer_id = trainer.id

    # ─────────────────────────────────────────────────────────────────────────────
    # 2. Create Student
    # ─────────────────────────────────────────────────────────────────────────────
    student_magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": student_email, "desired_role": "STUDENT"}
    )
    assert student_magic_resp.status_code == 200
    # Short code for testador accounts is from settings.TEST_TESTER_CODE
    student_short_code = student_magic_resp.json()["short_code"]

    student_verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": student_short_code, "email": student_email}
    )
    assert student_verify_resp.status_code == 200, f"Expected 200, got {student_verify_resp.status_code}: {student_verify_resp.json()}"
    student_token = student_verify_resp.json()["access_token"]
    student_headers = {"Authorization": f"Bearer {student_token}"}

    # Get student ID from DB
    result = await db.execute(select(User).filter(User.email == student_email))
    student = result.scalars().first()
    assert student is not None
    assert student.role == UserRole.STUDENT
    student_id = student.id

    # ─────────────────────────────────────────────────────────────────────────────
    # 3. Link Student to Trainer (student accepts trainer)
    # ─────────────────────────────────────────────────────────────────────────────
    invite_resp = await client.post(
        "/api/v1/trainer/invite-student",
        headers=trainer_headers,
        json={"student_email": student_email}
    )
    assert invite_resp.status_code == 200

    # Student accepts the invitation
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainers))
        .filter(User.id == student_id)
    )
    student_db = result.scalars().first()
    student_db.trainers.append(trainer)
    await db.commit()

    # Verify relationship
    result = await db.execute(
        select(User)
        .options(selectinload(User.trainers))
        .filter(User.id == student_id)
    )
    student_check = result.scalars().first()
    assert any(t.id == trainer_id for t in student_check.trainers)

    # ─────────────────────────────────────────────────────────────────────────────
    # 4. Trainer accepts AI terms
    # ─────────────────────────────────────────────────────────────────────────────
    from datetime import datetime
    trainer.accepted_ai_terms_at = datetime.utcnow()
    await db.commit()

    # ─────────────────────────────────────────────────────────────────────────────
    # 5. Enable AI feature on trainer profile
    # ─────────────────────────────────────────────────────────────────────────────
    result = await db.execute(
        select(TrainerProfile).filter(TrainerProfile.user_id == trainer_id)
    )
    profile = result.scalars().first()
    profile.enable_ai_workouts = True
    await db.commit()

    # ─────────────────────────────────────────────────────────────────────────────
    # 6. Mock Gemini Response and Generate Workout
    # ─────────────────────────────────────────────────────────────────────────────
    mock_gemini_response = {
        "summary": "Programa de força e hipertrofia para iniciantes",
        "workouts": [
            {
                "name": "Dia 1 — Peito e Tríceps",
                "notes": "Enfoque em força",
                "exercises": [
                    {
                        "exercise_name": "Supino Reto",
                        "sets": 4,
                        "reps_min": 6,
                        "reps_max": 8,
                        "duration_seconds": None,
                        "rest_seconds": 120,
                        "notes": "Carga pesada",
                        "methodology_type": "NORMAL",
                        "methodology_params": None
                    },
                    {
                        "exercise_name": "Rosca Francesa",
                        "sets": 3,
                        "reps_min": 8,
                        "reps_max": 12,
                        "duration_seconds": None,
                        "rest_seconds": 60,
                        "notes": None,
                        "methodology_type": "NORMAL",
                        "methodology_params": None
                    }
                ]
            },
            {
                "name": "Dia 2 — Costas e Bíceps",
                "notes": "Volume moderado",
                "exercises": [
                    {
                        "exercise_name": "Puxada Frontal",
                        "sets": 4,
                        "reps_min": 8,
                        "reps_max": 12,
                        "duration_seconds": None,
                        "rest_seconds": 90,
                        "notes": None,
                        "methodology_type": "NORMAL",
                        "methodology_params": None
                    },
                    {
                        "exercise_name": "Rosca Direta",
                        "sets": 3,
                        "reps_min": 8,
                        "reps_max": 12,
                        "duration_seconds": None,
                        "rest_seconds": 60,
                        "notes": None,
                        "methodology_type": "NORMAL",
                        "methodology_params": None
                    }
                ]
            }
        ]
    }

    # Mock the Gemini model
    mock_model = mocker.patch("app.api.endpoints.ai_workouts.genai.GenerativeModel")
    instance = mock_model.return_value
    mock_response = mocker.Mock()
    mock_response.text = json.dumps(mock_gemini_response)
    instance.generate_content.return_value = mock_response

    # Call AI generate endpoint
    generate_resp = await client.post(
        "/api/v1/ai-workouts/generate",
        headers=trainer_headers,
        json={
            "student_ids": [str(student_id)],
            "text": "Crie um programa de força com foco em peito, costas e puxadas. 2x por semana, equipamento de academia completa."
        }
    )
    assert generate_resp.status_code == 202
    job_id = generate_resp.json()["job_id"]

    # Poll job until completion
    import asyncio
    max_attempts = 10
    for attempt in range(max_attempts):
        poll_resp = await client.get(
            f"/api/v1/ai-workouts/jobs/{job_id}",
            headers=trainer_headers
        )
        assert poll_resp.status_code == 200
        poll_data = poll_resp.json()

        if poll_data["status"] == "done":
            break
        await asyncio.sleep(0.1)

    assert poll_data["status"] == "done"
    ai_result = poll_data["result"]
    assert ai_result is not None

    # ─────────────────────────────────────────────────────────────────────────────
    # 7. Save AI Program for Student
    # ─────────────────────────────────────────────────────────────────────────────
    save_resp = await client.post(
        "/api/v1/ai-workouts/save-program",
        headers=trainer_headers,
        json={
            "program_name": "Força e Hipertrofia — João",
            "workouts": ai_result["workouts"],
            "student_ids": [str(student_id)]
        }
    )
    assert save_resp.status_code == 200
    save_data = save_resp.json()
    assert save_data["saved_count"] == 2  # 2 workouts (Dia 1 + Dia 2)
    assert len(save_data["workouts"]) == 2

    # ─────────────────────────────────────────────────────────────────────────────
    # 8. Verify Workouts Created
    # ─────────────────────────────────────────────────────────────────────────────
    result = await db.execute(
        select(Workout)
        .options(
            selectinload(Workout.items).selectinload(WorkoutItem.exercise)
        )
        .filter(Workout.user_id == student_id)
    )
    workouts = result.scalars().all()

    # Check we have 2 workouts
    assert len(workouts) == 2

    # Check workout names
    workout_names = {w.name for w in workouts}
    assert "Dia 1 — Peito e Tríceps" in workout_names
    assert "Dia 2 — Costas e Bíceps" in workout_names

    # Check first workout has correct exercises and items
    dia1 = [w for w in workouts if w.name == "Dia 1 — Peito e Tríceps"][0]
    assert len(dia1.items) == 2

    # Check exercises were resolved or created
    exercise_names = {item.exercise.name for item in dia1.items}
    assert "Supino Reto" in exercise_names
    assert "Rosca Francesa" in exercise_names

    # Check exercise parameters
    supino = [item for item in dia1.items if item.exercise.name == "Supino Reto"][0]
    assert supino.sets == 4
    assert supino.reps_min == 6
    assert supino.reps_max == 8
    assert supino.rest_seconds == 120

    # ─────────────────────────────────────────────────────────────────────────────
    # 9. Verify Student Can See Their Workouts
    # ─────────────────────────────────────────────────────────────────────────────
    list_resp = await client.get(
        "/api/v1/workouts/",
        headers=student_headers
    )
    assert list_resp.status_code == 200
    list_data = list_resp.json()
    assert len(list_data) == 2

    # ─────────────────────────────────────────────────────────────────────────────
    # 10. Verify Trainer Can See Student's Workouts
    # ─────────────────────────────────────────────────────────────────────────────
    trainer_list_resp = await client.get(
        f"/api/v1/workouts/?student_id={student_id}",
        headers=trainer_headers
    )
    assert trainer_list_resp.status_code == 200
    trainer_list_data = trainer_list_resp.json()
    assert len(trainer_list_data) == 2


@pytest.mark.asyncio
async def test_trainer_cannot_generate_without_ai_terms(client, db):
    """
    Verify that a trainer without accepted AI terms cannot generate workouts.
    """
    trainer_email = "google.personal@pulsofit.app"
    student_email = "google.aluno@pulsofit.app"

    # Create trainer
    trainer_magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": trainer_email, "desired_role": "TRAINER"}
    )
    assert trainer_magic_resp.status_code == 200, f"Expected 200, got {trainer_magic_resp.status_code}: {trainer_magic_resp.json()}"
    trainer_short_code = trainer_magic_resp.json()["short_code"]
    trainer_verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": trainer_short_code, "email": trainer_email}
    )
    assert trainer_verify_resp.status_code == 200, f"Expected 200, got {trainer_verify_resp.status_code}: {trainer_verify_resp.json()}"
    trainer_token = trainer_verify_resp.json()["access_token"]
    trainer_headers = {"Authorization": f"Bearer {trainer_token}"}

    # Get trainer
    result = await db.execute(select(User).filter(User.email == trainer_email))
    trainer = result.scalars().first()

    # Create student
    student_magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": student_email, "desired_role": "STUDENT"}
    )
    student_short_code = student_magic_resp.json()["short_code"]
    student_verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": student_short_code, "email": student_email}
    )
    assert student_verify_resp.status_code == 200, f"Expected 200, got {student_verify_resp.status_code}: {student_verify_resp.json()}"
    result = await db.execute(select(User).filter(User.email == student_email))
    student = result.scalars().first()

    # Link student to trainer
    student.trainers.append(trainer)
    await db.commit()

    # Try to generate without accepting terms
    generate_resp = await client.post(
        "/api/v1/ai-workouts/generate",
        headers=trainer_headers,
        json={
            "student_ids": [str(student.id)],
            "text": "Any text"
        }
    )
    assert generate_resp.status_code == 403
    assert "Termos de Responsabilidade" in generate_resp.json()["detail"]


@pytest.mark.asyncio
async def test_trainer_cannot_generate_without_feature_flag(client, db):
    """
    Verify that a trainer without the enable_ai_workouts flag cannot generate.
    """
    trainer_email = "apple.personal@pulsofit.app"
    student_email = "apple.aluno@pulsofit.app"

    # Create and authenticate trainer
    trainer_magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": trainer_email, "desired_role": "TRAINER"}
    )
    trainer_short_code = trainer_magic_resp.json()["short_code"]
    trainer_verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": trainer_short_code, "email": trainer_email}
    )
    assert trainer_verify_resp.status_code == 200, f"Expected 200, got {trainer_verify_resp.status_code}: {trainer_verify_resp.json()}"
    trainer_token = trainer_verify_resp.json()["access_token"]
    trainer_headers = {"Authorization": f"Bearer {trainer_token}"}

    # Get trainer and accept terms
    result = await db.execute(select(User).filter(User.email == trainer_email))
    trainer = result.scalars().first()
    from datetime import datetime
    trainer.accepted_ai_terms_at = datetime.utcnow()
    await db.commit()

    # Create student
    student_magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": student_email, "desired_role": "STUDENT"}
    )
    student_short_code = student_magic_resp.json()["short_code"]
    student_verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": student_short_code, "email": student_email}
    )
    assert student_verify_resp.status_code == 200, f"Expected 200, got {student_verify_resp.status_code}: {student_verify_resp.json()}"
    result = await db.execute(select(User).filter(User.email == student_email))
    student = result.scalars().first()

    # Link student
    student.trainers.append(trainer)
    await db.commit()

    # Try to generate without feature flag enabled
    generate_resp = await client.post(
        "/api/v1/ai-workouts/generate",
        headers=trainer_headers,
        json={
            "student_ids": [str(student.id)],
            "text": "Any text"
        }
    )
    assert generate_resp.status_code == 403
    assert "premium" in generate_resp.json()["detail"].lower()
