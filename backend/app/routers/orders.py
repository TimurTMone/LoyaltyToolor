import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_current_user, get_db
from app.models.order import Order
from app.models.user import Profile
from app.schemas.order import OrderCreate, OrderOut
from app.services.order_service import create_order_from_cart
from app.services.upload_service import save_upload

router = APIRouter()


@router.post("", response_model=OrderOut)
async def create_order(
    body: OrderCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        order = await create_order_from_cart(
            db=db,
            user_id=user.id,
            payment_method=body.payment_method,
            delivery_type=body.delivery_type,
            delivery_address=body.delivery_address,
            delivery_notes=body.delivery_notes,
            try_at_home=body.try_at_home,
            points_used=body.points_used,
            promo_code=body.promo_code,
        )
        await db.commit()
        return OrderOut.model_validate(order)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/me", response_model=dict)
async def get_my_orders(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base = select(Order).where(Order.user_id == user.id)
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


@router.get("/{order_id}", response_model=OrderOut)
async def get_order(
    order_id: uuid.UUID,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.id == order_id, Order.user_id == user.id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return OrderOut.model_validate(order)


@router.post("/{order_id}/payment-proof", response_model=OrderOut)
async def upload_payment_proof(
    order_id: uuid.UUID,
    file: UploadFile = File(...),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.id == order_id, Order.user_id == user.id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    url = await save_upload(file, "payment-proofs")
    order.payment_proof_url = url
    order.status = "payment_uploaded"
    await db.commit()
    await db.refresh(order)
    return OrderOut.model_validate(order)
