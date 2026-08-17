from datetime import timedelta, datetime
from typing import Any
import random
import string
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.core import security
from app.core.config import settings
from app.db.session import get_db
from app.models.user import User, UserRole, SubscriptionStatus, student_trainer_association
from app.models.magic_link import MagicLink
from app.models.trainer_profile import TrainerProfile
from app.models.invite import StudentInvite, InviteStatus
from app.models.subscription_plan import SubscriptionPlan
from app.schemas.token import (
    Token,
    MagicLinkRequest,
    MagicLinkVerify,
    MagicLinkResponse,
)
from app.services.email import EmailService

router = APIRouter()
email_service = EmailService()

# Determine if we are in production
is_production = settings.ENVIRONMENT.lower() == "production"

# Import rate limiter from main app
from app.main import limiter


# ── Magic Link: Request ────────────────────────────────
@router.post("/magic-link", response_model=MagicLinkResponse)
@limiter.limit("5/minute")
async def request_magic_link(
    request: Request,
    body: MagicLinkRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> Any:
    """
    Send a magic link to the user's email.
    If the user doesn't exist, a valid invite is required to create the account.
    """
    email = body.email.lower().strip()

    # 1. Find or create user
    result = await db.execute(select(User).filter(User.email == email))
    user = result.scalars().first()

    if not user:
        # Test accounts are only allowed in non-production environments
        if not is_production:
            is_test_trainer = email in ["google.personal@pulsofit.app", "apple.personal@pulsofit.app", "testador.personal@pulsofit.app"]
            is_test_student = email in ["google.aluno@pulsofit.app", "apple.aluno@pulsofit.app", "testador.aluno@pulsofit.app"]
        else:
            is_test_trainer = False
            is_test_student = False

        invite = None
        role = UserRole.STUDENT

        if is_test_trainer:
            role = UserRole.TRAINER
        elif is_test_student:
            role = UserRole.STUDENT
        else:
            # Check for a valid pending invite to determine role and trainer link
            invite_result = await db.execute(
                select(StudentInvite).filter(
                    StudentInvite.email == email,
                    StudentInvite.status == InviteStatus.PENDING,
                    StudentInvite.expires_at > datetime.utcnow(),
                )
            )
            invite = invite_result.scalars().first()

            # Priority: admin trainer invite > desired_role from client > default STUDENT
            if invite and invite.trainer_id is None:
                # Admin trainer invite takes priority
                role = UserRole.TRAINER
            elif body.desired_role == "TRAINER":
                # Client requested TRAINER role
                role = UserRole.TRAINER
            else:
                # Default to STUDENT
                role = UserRole.STUDENT

        user = User(
            email=email,
            role=role,
            is_active=True,
            anamnesis_completed=False,
            subscription_status=SubscriptionStatus.TRIAL,
        )
        db.add(user)
        await db.flush()

        # Ensure Trainer test accounts have a TrainerProfile
        if is_test_trainer:
            db.add(TrainerProfile(user_id=user.id))
            await db.flush()

        if invite:
            # Student invite: link to trainer
            if role == UserRole.STUDENT:
                trainer_result = await db.execute(select(User).filter(User.id == invite.trainer_id))
                trainer = trainer_result.scalars().first()
                if trainer:
                    await db.execute(
                        student_trainer_association.insert().values(
                            student_id=user.id,
                            trainer_id=trainer.id,
                        )
                    )

            # Trainer invite: create TrainerProfile
            if role == UserRole.TRAINER:
                db.add(TrainerProfile(user_id=user.id))

            # Mark invite as registered
            invite.status = InviteStatus.REGISTERED
            await db.flush()

    # 2. Invalidate any previous unused magic links for this user
    prev_links = await db.execute(
        select(MagicLink).filter(
            MagicLink.user_id == user.id,
            MagicLink.is_used == False,  # noqa: E712
        )
    )
    for link in prev_links.scalars().all():
        link.is_used = True

    # 3. Generate & store new magic link token
    # Test accounts are only allowed in non-production environments
    if not is_production:
        test_accounts = {
            "apple.aluno@pulsofit.app": settings.TEST_APPLE_CODE,
            "apple.personal@pulsofit.app": settings.TEST_APPLE_CODE,
            "google.aluno@pulsofit.app": settings.TEST_GOOGLE_CODE,
            "google.personal@pulsofit.app": settings.TEST_GOOGLE_CODE,
            "testador.aluno@pulsofit.app": settings.TEST_TESTER_CODE,
            "testador.personal@pulsofit.app": settings.TEST_TESTER_CODE,
        }
    else:
        test_accounts = {}

    if email in test_accounts:
        plain_token = f"tester_{test_accounts[email]}_test"  # dummy plain token
        hashed_token = security.hash_magic_link_token(plain_token)
        short_code = test_accounts[email]
    else:
        plain_token, hashed_token = security.generate_magic_link_token()
        short_code = "".join(random.choices(string.digits, k=6))

    magic_link = MagicLink(
        user_id=user.id,
        token_hash=hashed_token,
        short_code=short_code,
        expires_at=datetime.utcnow()
        + timedelta(minutes=settings.MAGIC_LINK_EXPIRE_MINUTES),
    )
    db.add(magic_link)
    await db.commit()

    # 4. Send email in background
    # The link points to your app's deep link / universal link handler
    if email not in test_accounts:
        magic_link_url = f"pulso://auth/verify?token={plain_token}"

        background_tasks.add_task(
            email_service.send_magic_link_email,
            email_to=email,
            magic_link_url=magic_link_url,
            plain_token=plain_token,
            short_code=short_code,
        )

    return {"message": "Magic link sent. Check your email."}


# ── Magic Link: Verify ─────────────────────────────────
@router.post("/verify-magic-link", response_model=Token)
@limiter.limit("10/minute")
async def verify_magic_link(
    request: Request,
    body: MagicLinkVerify,
    db: AsyncSession = Depends(get_db),
) -> Any:
    """
    Verify a magic link token and return access + refresh tokens.
    Accepts either the full token or the 6-char short code shown in the email.
    """
    # 1. Look up by short code (6 chars) or full token hash
    submitted = body.token.strip().upper()

    if len(submitted) == 6:
        if not body.email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required when using a short code.",
            )
        result = await db.execute(
            select(MagicLink)
            .join(User, MagicLink.user_id == User.id)
            .filter(
                MagicLink.short_code == submitted,
                User.email == body.email.lower().strip()
            )
        )
    else:
        token_hash = security.hash_magic_link_token(body.token.strip())
        result = await db.execute(
            select(MagicLink).filter(MagicLink.token_hash == token_hash)
        )
    magic_link = result.scalars().first()

    if not magic_link:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired magic link",
        )

    if magic_link.is_used:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This magic link has already been used",
        )

    if magic_link.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This magic link has expired",
        )

    # 2. Load user first to check if it's a test account
    user_result = await db.execute(
        select(User).filter(User.id == magic_link.user_id)
    )
    user = user_result.scalars().first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Check if it's a test account - don't mark test codes as used (only in non-production)
    if not is_production:
        test_accounts = [
            "apple.aluno@pulsofit.app",
            "apple.personal@pulsofit.app",
            "google.aluno@pulsofit.app",
            "google.personal@pulsofit.app",
            "testador.aluno@pulsofit.app",
            "testador.personal@pulsofit.app",
        ]
    else:
        test_accounts = []

    is_test_account = user.email in test_accounts
    if not is_test_account:
        # Mark token as used (only for production accounts)
        magic_link.is_used = True

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )

    # 4. Update last login
    user.last_login_at = datetime.utcnow()
    await db.commit()

    # 5. Generate JWT tokens
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(
        user.id, expires_delta=access_token_expires
    )
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token,
    }


# ── Refresh Token (kept as-is) ─────────────────────────
from fastapi import Query
import sys

@router.post("/refresh-token", response_model=Token)
@limiter.limit("30/minute")
async def refresh_token(
    request: Request,
    refresh_token: str = Query(...),
    db: AsyncSession = Depends(get_db),
) -> Any:
    """
    Refresh access token using a valid refresh token.
    """
    try:
        from jose import jwt, JWTError

        # Debug logging removed for production - commented out for reduced verbosity
        # print(f"🔄 [REFRESH] Attempting to refresh token. Token preview: {refresh_token[:20]}...", file=sys.stderr)

        payload = jwt.decode(
            refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")

        # print(f"🔄 [REFRESH] Decoded payload - user_id: {user_id}, type: {token_type}", file=sys.stderr)

        if user_id is None or token_type != "refresh":  # nosec
            # print(f"❌ [REFRESH] Invalid token type or missing user_id", file=sys.stderr)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
                headers={"WWW-Authenticate": "Bearer"},
            )

    except JWTError as e:
        # print(f"❌ [REFRESH] JWT decode failed: {str(e)}", file=sys.stderr)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_result = await db.execute(select(User).filter(User.id == user_id))
    user = user_result.scalars().first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Inactive user"
        )

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(
        user.id, expires_delta=access_token_expires
    )

    # Rotate refresh token
    new_refresh_token = security.create_refresh_token(user.id)

    # Debug logging removed for production - commented out for reduced verbosity
    # print(f"✅ [REFRESH] SUCCESS - Generated tokens for user {user_id}", file=sys.stderr)
    # print(f"   - Access token length: {len(access_token)}", file=sys.stderr)
    # print(f"   - Refresh token length: {len(new_refresh_token)}", file=sys.stderr)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": new_refresh_token,
    }


# ── Google Sign-In ─────────────────────────────────────
from pydantic import BaseModel
from typing import Optional

class GoogleAuthRequest(BaseModel):
    id_token: str
    desired_role: Optional[str] = None  # 'TRAINER' or 'STUDENT'; ignored if user exists

@router.post("/google", response_model=Token)
@limiter.limit("10/minute")
async def google_auth(
    request: Request,
    body: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
) -> Any:
    """
    Authenticate with Google ID token.
    Finds or creates the user and returns JWT tokens.
    """
    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests

    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=500, detail="Google OAuth not configured")

    try:
        idinfo = google_id_token.verify_oauth2_token(
            body.id_token,
            google_requests.Request(),
            audience=None,  # accepts any configured client
        )
        # Ensure it's a valid Google token
        if idinfo.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
            raise ValueError("Wrong issuer")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Google token")

    email = idinfo.get("email", "").lower().strip()
    full_name = idinfo.get("name")
    photo_url = idinfo.get("picture")

    if not email:
        raise HTTPException(status_code=400, detail="Email not provided by Google")

    # Find or create user
    result = await db.execute(select(User).filter(User.email == email))
    user = result.scalars().first()

    if not user:
        # Use desired_role if specified, otherwise default to STUDENT
        role = UserRole.TRAINER if body.desired_role == "TRAINER" else UserRole.STUDENT

        user = User(
            email=email,
            full_name=full_name,
            photo_url=photo_url,
            role=role,
            is_active=True,
            anamnesis_completed=False,
            subscription_status=SubscriptionStatus.TRIAL,
        )
        db.add(user)
        await db.flush()

        # If new trainer, create TrainerProfile
        if role == UserRole.TRAINER:
            db.add(TrainerProfile(user_id=user.id))
            await db.flush()
    else:
        # Update name/photo if missing
        if not user.full_name and full_name:
            user.full_name = full_name
        if not user.photo_url and photo_url:
            user.photo_url = photo_url

    user.last_login_at = datetime.utcnow()
    await db.commit()

    access_token = security.create_access_token(
        user.id, expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    refresh_token = security.create_refresh_token(user.id)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token,
    }
