from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from typing import Any
from datetime import datetime, timedelta
import secrets

from app import models
from app.schemas.invite import InviteCreate, InviteResponse, InvitePublicInfo
from app.api import deps
from app.core.config import settings
from app.services.email import EmailService

router = APIRouter()

@router.post("/", response_model=InviteResponse)
async def create_invite(
    *,
    db: AsyncSession = Depends(deps.get_db),
    invite_in: InviteCreate,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create a new student invite.
    """
    # 0. Check if user already exists
    existing_user_result = await db.execute(select(models.User).filter(models.User.email == invite_in.email))
    if existing_user_result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists",
        )

    # Check if invite already exists and is pending
    result = await db.execute(
        select(models.StudentInvite).filter(
            models.StudentInvite.email == invite_in.email,
            models.StudentInvite.status == models.InviteStatus.PENDING
        )
    )
    existing_invite = result.scalars().first()

    if existing_invite:
        # If expired, delete and create new? Or just return existing?
        # Let's return existing but refresh token/expiry if needed?
        # For simplicity, let's just return it if valid, or update it.
        if existing_invite.expires_at > datetime.utcnow():
             invite_link = f"{settings.FRONTEND_URL.rstrip('/')}/register?token={existing_invite.token}"
             return InviteResponse(
                 id=existing_invite.id,
                 email=existing_invite.email,
                 token=existing_invite.token,
                 status=existing_invite.status,
                 expires_at=existing_invite.expires_at,
                 invite_link=invite_link
             )
        else:
            # Expired, delete it
            await db.delete(existing_invite)
            await db.commit()

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=48)
    
    invite = models.StudentInvite(
        trainer_id=current_user.id,
        email=invite_in.email,
        token=token,
        status=models.InviteStatus.PENDING,
        expires_at=expires_at
    )
    db.add(invite)
    await db.commit()
    await db.refresh(invite)

    invite_link = f"{settings.FRONTEND_URL.rstrip('/')}/register?token={invite.token}"
    
    # Send email
    try:
        email_service = EmailService()
        await email_service.send_invite_email(
            email_to=invite.email, 
            invite_link=invite_link,
            trainer_name=current_user.full_name
        )
    except Exception as e:
        print(f"Failed to send invite email: {e}")
    
    # We construct the response manually to include the link
    return InviteResponse(
        id=invite.id,
        email=invite.email,
        token=invite.token,
        status=invite.status,
        expires_at=invite.expires_at,
        invite_link=invite_link
    )

@router.get("/{token}", response_model=InvitePublicInfo)
async def get_invite(
    token: str,
    db: AsyncSession = Depends(deps.get_db),
) -> Any:
    """
    Get invite details by token. Public endpoint.
    """
    result = await db.execute(
        select(models.StudentInvite)
        .options(selectinload(models.StudentInvite.trainer))
        .filter(models.StudentInvite.token == token)
    )
    invite = result.scalars().first()
    
    if not invite:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid invitation token",
        )
    
    if invite.status != models.InviteStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invitation already used",
        )

    if invite.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invitation expired",
        )

    trainer_name = None
    trainer_id = None
    
    if invite.trainer:
        trainer_name = invite.trainer.full_name or invite.trainer.email
        trainer_id = invite.trainer.id

    return InvitePublicInfo(
        email=invite.email,
        trainer_name=trainer_name,
        trainer_id=trainer_id
    )

@router.delete("/{invite_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_invite(
    invite_id: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: models.User = Depends(deps.get_current_active_user),
) -> None:
    """
    Delete an invite.
    """
    # Check if invite exists
    result = await db.execute(select(models.StudentInvite).filter(models.StudentInvite.id == invite_id))
    invite = result.scalars().first()

    if not invite:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invite not found",
        )

    # Check permissions (Trainer can delete their own invites, Admin can delete any)
    if current_user.role != models.UserRole.SUPER_ADMIN and invite.trainer_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    await db.delete(invite)
    await db.commit()

from app.schemas.invite import TrainerInviteCreate

@router.post("/admin/trainer", response_model=InviteResponse)
async def create_trainer_invite(
    *,
    db: AsyncSession = Depends(deps.get_db),
    invite_in: TrainerInviteCreate,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create a new trainer invite (Admin only).
    """
    if current_user.role != models.UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    # Check if user already exists
    existing_user_result = await db.execute(select(models.User).filter(models.User.email == invite_in.email))
    if existing_user_result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists",
        )

    # Check if any invite already exists for this email (any status)
    result = await db.execute(
        select(models.StudentInvite).filter(
            models.StudentInvite.email == invite_in.email,
        )
    )
    existing_invite = result.scalars().first()

    if existing_invite:
        if existing_invite.status == models.InviteStatus.PENDING and existing_invite.expires_at > datetime.utcnow():
             invite_link = f"{settings.FRONTEND_URL.rstrip('/')}/register?type=trainer&token={existing_invite.token}"
             return InviteResponse(
                 id=existing_invite.id,
                 email=existing_invite.email,
                 token=existing_invite.token,
                 status=existing_invite.status,
                 expires_at=existing_invite.expires_at,
                 invite_link=invite_link
             )
        else:
            await db.delete(existing_invite)
            await db.commit()

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(days=7)
    
    invite = models.StudentInvite(
        trainer_id=None, # System invite for trainer
        email=invite_in.email,
        token=token,
        status=models.InviteStatus.PENDING,
        expires_at=expires_at
    )
    db.add(invite)
    await db.commit()
    await db.refresh(invite)
    
    invite_link = f"{settings.FRONTEND_URL.rstrip('/')}/register?type=trainer&token={invite.token}"
    
    # Send email
    try:
        email_service = EmailService()
        await email_service.send_invite_email(
            email_to=invite.email, 
            invite_link=invite_link,
            trainer_name="Equipe PULSO"
        )
    except Exception as e:
        print(f"Failed to send invite email: {e}")
    
    return InviteResponse(
        id=invite.id,
        email=invite.email,
        token=invite.token,
        status=invite.status,
        expires_at=invite.expires_at,
        invite_link=invite_link
    )
