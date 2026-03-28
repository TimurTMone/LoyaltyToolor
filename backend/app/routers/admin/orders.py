import math
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db, require_admin
from app.models.order import Order
from app.models.user import Profile
from app.schemas.order import AdminOrderOut, OrderStatusUpdate

router = APIRouter(dependencies=[Depends(require_admin)])


@router.get("", response_model=dict)
async def list_all_orders(
    status: str | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(Order).options(selectinload(Order.items), selectinload(Order.user))
    if status:
        query = query.where(Order.status == status)

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(Order.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    orders = result.scalars().all()

    items = []
    for o in orders:
        out = AdminOrderOut.model_validate(o)
        out.user_id = o.user_id
        out.user_phone = o.user.phone if o.user else ""
        out.user_name = o.user.full_name if o.user else ""
        items.append(out)

    return {
        "items": items,
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


@router.get("/{order_id}", response_model=AdminOrderOut)
async def get_order(order_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items), selectinload(Order.user))
        .where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    out = AdminOrderOut.model_validate(order)
    out.user_id = order.user_id
    out.user_phone = order.user.phone if order.user else ""
    out.user_name = order.user.full_name if order.user else ""
    return out


@router.patch("/{order_id}/status", response_model=AdminOrderOut)
async def update_order_status(
    order_id: uuid.UUID,
    body: OrderStatusUpdate,
    admin: Profile = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items), selectinload(Order.user))
        .where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order.status = body.status
    if body.admin_notes:
        order.admin_notes = body.admin_notes

    now = datetime.now(timezone.utc)
    if body.status == "payment_confirmed":
        order.confirmed_by = admin.id
        order.confirmed_at = now
    elif body.status == "shipped":
        order.shipped_at = now
    elif body.status == "delivered":
        order.delivered_at = now

    await db.commit()
    await db.refresh(order)

    out = AdminOrderOut.model_validate(order)
    out.user_id = order.user_id
    out.user_phone = order.user.phone if order.user else ""
    out.user_name = order.user.full_name if order.user else ""
    return out
