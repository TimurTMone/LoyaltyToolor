import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db, require_admin
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.user import Profile
from app.schemas.loyalty import AdminLoyaltyAdjust, LoyaltyAccountOut
from app.schemas.user import AdminUserUpdate, UserOut
from app.services.loyalty_service import calculate_tier

router = APIRouter(dependencies=[Depends(require_admin)])


@router.get("", response_model=dict)
async def list_users(
    search: str | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(Profile)
    if search:
        query = query.where(
            Profile.full_name.ilike(f"%{search}%") | Profile.phone.ilike(f"%{search}%")
        )

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(Profile.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)

    return {
        "items": [UserOut.model_validate(u) for u in result.scalars().all()],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


@router.get("/{user_id}", response_model=dict)
async def get_user_detail(user_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    user = await db.get(Profile, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    loyalty_result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id)
    )
    loyalty = loyalty_result.scalar_one_or_none()

    return {
        "user": UserOut.model_validate(user),
        "loyalty": LoyaltyAccountOut.model_validate(loyalty) if loyalty else None,
    }


@router.patch("/{user_id}", response_model=UserOut)
async def update_user(
    user_id: uuid.UUID, body: AdminUserUpdate, db: AsyncSession = Depends(get_db)
):
    user = await db.get(Profile, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.post("/{user_id}/loyalty/adjust", response_model=LoyaltyAccountOut)
async def adjust_loyalty(
    user_id: uuid.UUID,
    body: AdminLoyaltyAdjust,
    db: AsyncSession = Depends(get_db),
):
    loyalty_result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id)
    )
    loyalty = loyalty_result.scalar_one_or_none()
    if not loyalty:
        raise HTTPException(status_code=404, detail="Loyalty account not found")

    loyalty.points += body.points_change
    if loyalty.points < 0:
        loyalty.points = 0
    loyalty.tier = calculate_tier(loyalty.total_spent)

    txn = LoyaltyTransaction(
        loyalty_id=loyalty.id,
        user_id=user_id,
        type="admin_adjustment",
        amount=0,
        points_change=body.points_change,
        description=body.description,
    )
    db.add(txn)
    await db.commit()
    await db.refresh(loyalty)
    return LoyaltyAccountOut.model_validate(loyalty)
