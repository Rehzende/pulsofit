import pytest
from sqlalchemy import select
from app.models.user import User, UserRole
from app.models.trainer_profile import TrainerProfile

@pytest.mark.asyncio
async def test_magic_link_flow_trainer_integrity(client, db):
    """
    Test the full integrity of the trainer registration flow via Magic Link.
    Ensures that:
    1. A new user is created.
    2. A TrainerProfile is automatically created for test trainers.
    3. Login works and returns a valid JWT.
    """
    email = "testador.personal@pulsofit.app"
    
    # 1. Request Magic Link
    response = await client.post("/api/v1/auth/magic-link", json={"email": email, "desired_role": "TRAINER"})
    assert response.status_code == 200
    assert response.json()["message"] == "Magic link sent. Check your email."

    # 2. Verify integrity in DB: User & Profile created
    result = await db.execute(select(User).filter(User.email == email))
    user = result.scalars().first()
    assert user is not None
    assert user.role == UserRole.TRAINER

    profile_result = await db.execute(select(TrainerProfile).filter(TrainerProfile.user_id == user.id))
    profile = profile_result.scalars().first()
    assert profile is not None
    assert profile.user_id == user.id

    # 3. Verify Magic Link (using the test account short code '123456')
    verify_response = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": "123456", "email": email}
    )
    assert verify_response.status_code == 200
    data = verify_response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

@pytest.mark.asyncio
async def test_auth_protection_integrity(client):
    """Verify that protected endpoints actually require authentication."""
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Not authenticated"
