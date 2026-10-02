"""
Object storage service (S3 / MinIO compatible).
Per SRS §37: never store binary image data in PostgreSQL -- only the
object_key/URL is persisted in DB. Enforces file-size and MIME-type
checks so someone can't upload an executable disguised as an image.
"""
import uuid

import boto3
from botocore.client import Config
from fastapi import HTTPException, UploadFile, status

from app.core.config import settings

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB


def _client():
    return boto3.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        region_name=settings.S3_REGION,
        config=Config(signature_version="s3v4"),
    )


async def upload_image(file: UploadFile, *, folder: str) -> str:
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="نوع الملف غير مسموح. الأنواع المسموحة: JPEG, PNG, WEBP",
        )

    contents = await file.read()
    if len(contents) > _MAX_FILE_SIZE_BYTES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="حجم الملف يتجاوز الحد الأقصى (5 ميجابايت)")

    extension = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "bin"
    object_key = f"{folder}/{uuid.uuid4()}.{extension}"

    client = _client()
    client.put_object(
        Bucket=settings.S3_BUCKET_NAME,
        Key=object_key,
        Body=contents,
        ContentType=file.content_type,
    )
    return object_key


def get_public_url(object_key: str) -> str:
    return f"{settings.S3_ENDPOINT_URL}/{settings.S3_BUCKET_NAME}/{object_key}"
