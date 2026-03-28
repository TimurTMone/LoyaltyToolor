import uuid
from pathlib import Path

from fastapi import UploadFile

from app.config import settings

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


async def save_upload(file: UploadFile, subdirectory: str) -> str:
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise ValueError(f"File type {file.content_type} not allowed")

    ext = file.filename.rsplit(".", 1)[-1] if file.filename and "." in file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    upload_dir = Path(settings.UPLOAD_DIR) / subdirectory
    upload_dir.mkdir(parents=True, exist_ok=True)
    file_path = upload_dir / filename

    content = await file.read()
    file_path.write_bytes(content)

    return f"/uploads/{subdirectory}/{filename}"
