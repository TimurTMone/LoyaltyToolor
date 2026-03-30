import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db, require_admin
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.order import Order
from app.models.user import Profile
from app.schemas.loyalty import AdminLoyaltyAdjust, LoyaltyAccountOut
from app.schemas.order import OrderOut
from app.schemas.user import AdminUserUpdate, UserOut
from app.services.loyalty_service import calculate_tier, check_milestones

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
    user_id: uuid.UUID,
    body: AdminUserUpdate,
    current_user: Profile = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(Profile, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Prevent removing your own admin access
    if user.id == current_user.id and body.is_admin is False:
        raise HTTPException(status_code=400, detail="Нельзя снять админ-права с себя")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.delete("/{user_id}", status_code=204)
async def delete_user(user_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    user = await db.get(Profile, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_admin:
        raise HTTPException(status_code=400, detail="Cannot delete admin users")
    await db.delete(user)
    await db.commit()


@router.get("/{user_id}/orders", response_model=dict)
async def get_user_orders(
    user_id: uuid.UUID,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    base = select(Order).where(Order.user_id == user_id)
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = (
        base.options(selectinload(Order.items))
        .order_by(Order.created_at.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
    )
    result = await db.execute(query)
    orders = result.scalars().all()

    return {
        "items": [OrderOut.model_validate(o) for o in orders],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


@router.post("/{user_id}/loyalty/adjust", response_model=LoyaltyAccountOut)
async def adjust_loyalty(
    user_id: uuid.UUID,
    body: AdminLoyaltyAdjust,
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(Profile, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    loyalty_result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id)
    )
    loyalty = loyalty_result.scalar_one_or_none()
    if not loyalty:
        raise HTTPException(status_code=404, detail="Loyalty account not found")

    loyalty.points += body.points_change
    if loyalty.points < 0:
        loyalty.points = 0

    txn = LoyaltyTransaction(
        loyalty_id=loyalty.id,
        user_id=user_id,
        type="admin_adjustment",
        amount=0,
        points_change=body.points_change,
        description=body.description,
    )
    db.add(txn)

    # Check if tier should be upgraded based on total_spent
    await check_milestones(db, user_id, loyalty)

    await db.commit()
    await db.refresh(loyalty)
    return LoyaltyAccountOut.model_validate(loyalty)
