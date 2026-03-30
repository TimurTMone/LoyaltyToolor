from datetime import date

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.notification import Notification
from app.models.user import Profile
from app.schemas.user import UserOut, UserUpdate
from app.services.loyalty_service import BIRTHDAY_BONUS_POINTS
from app.services.upload_service import save_upload

router = APIRouter()


class BirthdayUpdate(BaseModel):
    birth_date: date


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


@router.patch("/me/birthday", response_model=UserOut)
async def set_birthday(
    body: BirthdayUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.birth_date is not None:
        raise HTTPException(status_code=400, detail="Дата рождения уже установлена и не может быть изменена")
    user.birth_date = body.birth_date

    # Award 1000 bonus points for setting birthday
    result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
    )
    loyalty = result.scalar_one_or_none()
    if loyalty:
        loyalty.points += BIRTHDAY_BONUS_POINTS
        txn = LoyaltyTransaction(
            loyalty_id=loyalty.id,
            user_id=user.id,
            type="bonus",
            amount=0,
            points_change=BIRTHDAY_BONUS_POINTS,
            description="\U0001f382 Бонус за указание даты рождения",
        )
        db.add(txn)
        notification = Notification(
            user_id=user.id,
            type="bonus",
            title="Бонус +1000 баллов! \U0001f389",
            body="Спасибо, что указали дату рождения! Мы начислили вам 1000 бонусных баллов.",
        )
        db.add(notification)

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
