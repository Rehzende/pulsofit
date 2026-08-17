from typing import Any
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.trainer_profile import TrainerProfile
from app.core.config import settings
import boto3
from botocore.client import Config
import uuid
import os

router = APIRouter()

ALLOWED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".heic", ".heif"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
    ".heif": "image/heif",
}


def _get_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        region_name=settings.S3_REGION,
        aws_access_key_id=settings.S3_ACCESS_KEY_ID,
        aws_secret_access_key=settings.S3_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
    )


def _upload_to_s3(contents: bytes, filename: str, ext: str) -> str:
    s3 = _get_s3_client()
    key = f"uploads/{filename}"
    s3.put_object(
        Bucket=settings.S3_BUCKET_NAME,
        Key=key,
        Body=contents,
        ContentType=CONTENT_TYPES.get(ext, "application/octet-stream"),
    )
    # Return the backend proxy URL — avoids S3 public access configuration issues
    backend_url = settings.BACKEND_URL.rstrip("/")
    return f"{backend_url}/api/v1/files/{key}"


@router.post("/logo")
async def upload_logo(
    type: str = "logo",
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Upload logo or profile photo to object storage."""
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo inválido. Permitidos: {', '.join(ALLOWED_EXTENSIONS)}",
        )

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="Arquivo muito grande. Máximo: 5MB")

    filename = f"{current_user.id}_{type}_{uuid.uuid4().hex}{file_ext}"

    try:
        file_url = _upload_to_s3(contents, filename, file_ext)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no upload: {str(e)}")

    if type == "avatar":
        current_user.photo_url = file_url
        db.add(current_user)
        await db.commit()
        await db.refresh(current_user)

    elif type == "logo":
        if current_user.role != UserRole.TRAINER:
            raise HTTPException(status_code=400, detail="Apenas trainers podem enviar logo")
        result = await db.execute(
            select(TrainerProfile).filter(TrainerProfile.user_id == current_user.id)
        )
        profile = result.scalars().first()
        if not profile:
            profile = TrainerProfile(user_id=current_user.id)
            db.add(profile)
        profile.logo_url = file_url
        await db.commit()
        await db.refresh(profile)

    return {"url": file_url, "logo_url": file_url, "message": "Upload realizado com sucesso"}
