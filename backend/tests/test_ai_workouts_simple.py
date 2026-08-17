"""
Simplified AI Workout Integration Tests
These tests verify the complete flow without complex fixture dependencies.
"""
import pytest
from sqlalchemy import select
from app.models.user import User, UserRole
from app.models.trainer_profile import TrainerProfile


@pytest.mark.asyncio
async def test_trainer_auth_flow(client, db):
    """Test 1: Trainer can authenticate with magic link."""
    trainer_email = "simple.test.trainer@pulsofit.app"

    # Request magic link
    magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": trainer_email, "desired_role": "TRAINER"}
    )
    assert magic_resp.status_code == 200
    short_code = magic_resp.json()["short_code"]

    # Verify magic link
    verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": short_code, "email": trainer_email}
    )
    assert verify_resp.status_code == 200
    assert "access_token" in verify_resp.json()

    # Check user was created
    result = await db.execute(select(User).filter(User.email == trainer_email))
    user = result.scalars().first()
    assert user is not None
    assert user.role == UserRole.TRAINER
    print("✅ Test 1 passed: Trainer authentication")


@pytest.mark.asyncio
async def test_student_auth_flow(client, db):
    """Test 2: Student can authenticate with magic link."""
    student_email = "simple.test.student@pulsofit.app"

    # Request magic link
    magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": student_email, "desired_role": "STUDENT"}
    )
    assert magic_resp.status_code == 200
    short_code = magic_resp.json()["short_code"]

    # Verify magic link
    verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": short_code, "email": student_email}
    )
    assert verify_resp.status_code == 200
    assert "access_token" in verify_resp.json()

    # Check user was created
    result = await db.execute(select(User).filter(User.email == student_email))
    user = result.scalars().first()
    assert user is not None
    assert user.role == UserRole.STUDENT
    print("✅ Test 2 passed: Student authentication")


@pytest.mark.asyncio
async def test_trainer_ai_terms_gate(client, db):
    """Test 3: Trainer without AI terms cannot generate workouts."""
    trainer_email = "no.ai.terms@pulsofit.app"
    student_email = "no.ai.terms.student@pulsofit.app"

    # Create and authenticate trainer
    magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": trainer_email, "desired_role": "TRAINER"}
    )
    short_code = magic_resp.json()["short_code"]
    verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": short_code, "email": trainer_email}
    )
    trainer_token = verify_resp.json()["access_token"]
    trainer_headers = {"Authorization": f"Bearer {trainer_token}"}

    # Create student
    student_magic = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": student_email, "desired_role": "STUDENT"}
    )
    student_code = student_magic.json()["short_code"]
    await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": student_code, "email": student_email}
    )

    # Link student to trainer in DB via association table (avoid lazy-loading issue)
    from sqlalchemy import update
    from app.models.user import student_trainer_association
    result = await db.execute(select(User).filter(User.email == trainer_email))
    trainer = result.scalars().first()
    result = await db.execute(select(User).filter(User.email == student_email))
    student = result.scalars().first()

    # Use raw insert instead of lazy-loaded relationship
    await db.execute(
        student_trainer_association.insert().values(
            student_id=student.id,
            trainer_id=trainer.id
        )
    )
    await db.commit()

    # Try to generate without AI terms
    generate_resp = await client.post(
        "/api/v1/ai-workouts/generate",
        headers=trainer_headers,
        json={
            "student_ids": [str(student.id)],
            "text": "Any prompt"
        }
    )

    # Should be blocked
    assert generate_resp.status_code == 403
    assert "Termos" in generate_resp.json()["detail"] or "termos" in generate_resp.json()["detail"].lower()
    print("✅ Test 3 passed: AI terms gate enforcement")
