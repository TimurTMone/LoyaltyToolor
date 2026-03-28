from fastapi import APIRouter, Depends, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.user import Profile
from app.schemas.user import UserOut, UserUpdate
from app.services.upload_service import save_upload

router = APIRouter()


@router.get("/me", response_model=UserOut)
async def get_me(user: Profile = Depends(get_current_user)):
    return UserOut.model_validate(user)


@router.patch("/me", response_model=UserOut)
async def update_me(
    body: UserUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.post("/me/avatar", response_model=UserOut)
async def upload_avatar(
    file: UploadFile = File(...),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    url = await save_upload(file, "avatars")
    user.avatar_url = url
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)
