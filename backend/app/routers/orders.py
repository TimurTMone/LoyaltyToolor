import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_current_user, get_db
from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.notification import Notification
from app.models.order import Order
from app.models.user import Profile
from app.schemas.order import OrderCreate, OrderOut, OrderTrackOut, TimelineEntry
from app.services.order_service import create_order_from_cart
from app.services.analytics_service import track_purchase
from app.services.event_logger import log_event

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
            pickup_location_id=body.pickup_location_id,
        )
        await db.commit()
        track_purchase(
            user_id=str(user.id),
            order_id=str(order.id),
            total=float(order.total),
            items_count=len(order.items),
            payment_method=body.payment_method or "unknown",
            points_used=body.points_used or 0,
        )
        await log_event(db, user.id, "purchase", {
            "order_id": str(order.id),
            "total": float(order.total),
            "items_count": len(order.items),
        })
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


@router.get("/{order_id}/track", response_model=OrderTrackOut)
async def track_order(
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

    # Build timeline from timestamp fields
    timeline = []
    timeline.append(TimelineEntry(
        status="pending",
        timestamp=order.created_at,
        note="Заказ создан",
    ))
    if order.confirmed_at:
        timeline.append(TimelineEntry(
            status="payment_confirmed",
            timestamp=order.confirmed_at,
            note="Оплата подтверждена",
        ))
    if order.ready_for_pickup_at:
        timeline.append(TimelineEntry(
            status="ready_for_pickup",
            timestamp=order.ready_for_pickup_at,
            note="Готов к выдаче",
        ))
    if order.shipped_at:
        timeline.append(TimelineEntry(
            status="shipped",
            timestamp=order.shipped_at,
            note="Отправлен",
        ))
    if order.delivered_at:
        timeline.append(TimelineEntry(
            status="delivered",
            timestamp=order.delivered_at,
            note="Доставлен",
        ))

    return OrderTrackOut(
        order=OrderOut.model_validate(order),
        timeline=timeline,
    )


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


@router.post("/{order_id}/confirm-payment", response_model=OrderOut)
async def confirm_finik_payment(
    order_id: uuid.UUID,
    body: dict,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Called by Flutter app after Finik SDK reports payment success."""
    from datetime import datetime, timezone

    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.id == order_id, Order.user_id == user.id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.status in ("payment_confirmed", "processing", "shipped", "delivered"):
        return OrderOut.model_validate(order)

    transaction_id = body.get("transactionId")
    status = body.get("status")

    if status != "SUCCEEDED":
        raise HTTPException(status_code=400, detail="Payment not successful")

    order.status = "payment_confirmed"
    order.payment_transaction_id = transaction_id
    order.payment_provider = "finik"
    order.confirmed_at = datetime.now(timezone.utc)

    notification = Notification(
        user_id=user.id,
        type="order_status",
        title=f"Заказ #{order.order_number}",
        body="Оплата подтверждена",
        data={"order_id": str(order.id), "status": "payment_confirmed"},
    )
    db.add(notification)

    await db.commit()
    await db.refresh(order)
    return OrderOut.model_validate(order)


@router.post("/{order_id}/cancel", response_model=OrderOut)
async def cancel_order(
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

    if order.status not in ("pending",):
        raise HTTPException(
            status_code=400,
            detail=f"Нельзя отменить заказ в статусе '{order.status}'",
        )

    # Restore loyalty points if any were redeemed
    if order.points_used > 0:
        loyalty_result = await db.execute(
            select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
        )
        loyalty = loyalty_result.scalar_one_or_none()
        if loyalty:
            loyalty.points += order.points_used
            txn = LoyaltyTransaction(
                loyalty_id=loyalty.id,
                user_id=user.id,
                order_id=order.id,
                type="points_refund",
                amount=0,
                points_change=order.points_used,
                description=f"Возврат {order.points_used} баллов за отмену заказа #{order.order_number}",
            )
            db.add(txn)

    order.status = "cancelled"

    notification = Notification(
        user_id=user.id,
        type="order_status",
        title=f"Заказ #{order.order_number} отменён",
        body=f"Заказ #{order.order_number} отменён",
        data={"order_id": str(order.id), "status": "cancelled"},
    )
    db.add(notification)

    await db.commit()
    await db.refresh(order)
    return OrderOut.model_validate(order)
