import pytest
from sqlalchemy import select
from app.models.user import User

@pytest.mark.asyncio
async def test_magic_link_auth_flow(client, db):
    """Test basic magic link auth without AI workouts."""
    trainer_email = "test.trainer@pulsofit.app"

    # Request magic link
    print(f"\n1. Requesting magic link for {trainer_email}...")
    magic_resp = await client.post(
        "/api/v1/auth/magic-link",
        json={"email": trainer_email, "desired_role": "TRAINER"}
    )
    print(f"   Status: {magic_resp.status_code}")
    assert magic_resp.status_code == 200, f"Expected 200, got {magic_resp.status_code}: {magic_resp.json()}"

    short_code = magic_resp.json()["short_code"]
    print(f"   Short code: {short_code}")

    # Verify magic link
    print(f"2. Verifying magic link with code {short_code}...")
    verify_resp = await client.post(
        "/api/v1/auth/verify-magic-link",
        json={"token": short_code, "email": trainer_email}
    )
    print(f"   Status: {verify_resp.status_code}")
    assert verify_resp.status_code == 200, f"Expected 200, got {verify_resp.status_code}: {verify_resp.json()}"

    token = verify_resp.json()["access_token"]
    print(f"   Token obtained: {token[:20]}...")

    # Verify user was created
    print(f"3. Checking user in database...")
    result = await db.execute(select(User).filter(User.email == trainer_email))
    user = result.scalars().first()
    assert user is not None, f"User {trainer_email} not found in database"
    print(f"   User found: {user.email}, role: {user.role}")

    print("✅ Test passed!")
