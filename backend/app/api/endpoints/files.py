from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
import boto3
from botocore.client import Config
from app.core.config import settings

router = APIRouter()


def _get_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        region_name=settings.S3_REGION,
        aws_access_key_id=settings.S3_ACCESS_KEY_ID,
        aws_secret_access_key=settings.S3_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
    )


@router.get("/{key:path}")
async def serve_file(key: str):
    """
    Proxy endpoint for private S3/Tigris files.
    Generates a short-lived presigned URL and redirects to it.
    No authentication required — suitable for public assets like logos.
    """
    if not settings.S3_BUCKET_NAME:
        raise HTTPException(status_code=503, detail="Storage not configured")

    try:
        s3 = _get_s3_client()
        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.S3_BUCKET_NAME, "Key": key},
            ExpiresIn=3600,  # 1 hour
        )
        return RedirectResponse(url=url, status_code=302)
    except Exception:
        raise HTTPException(status_code=404, detail="File not found")
