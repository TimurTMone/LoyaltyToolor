import math

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.user import Profile
from app.schemas.loyalty import LoyaltyAccountOut, LoyaltyTransactionOut

router = APIRouter()


@router.get("/me", response_model=LoyaltyAccountOut)
async def get_my_loyalty(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
    )
    loyalty = result.scalar_one_or_none()
    if not loyalty:
        raise HTTPException(status_code=404, detail="Loyalty account not found")
    return LoyaltyAccountOut.model_validate(loyalty)


@router.get("/me/transactions", response_model=dict)
async def get_my_transactions(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base = select(LoyaltyTransaction).where(LoyaltyTransaction.user_id == user.id)
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = base.order_by(LoyaltyTransaction.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    items = result.scalars().all()

    return {
        "items": [LoyaltyTransactionOut.model_validate(t) for t in items],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }
