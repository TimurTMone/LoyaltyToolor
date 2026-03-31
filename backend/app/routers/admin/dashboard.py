from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, distinct, case
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_admin
from app.models.chat import ChatSession
from app.models.order import Order
from app.models.user import Profile

router = APIRouter()


@router.get("/dashboard", dependencies=[Depends(require_admin)])
async def get_dashboard(db: AsyncSession = Depends(get_db)):
    total_users = (await db.execute(select(func.count(Profile.id)))).scalar() or 0
    total_orders = (await db.execute(select(func.count(Order.id)))).scalar() or 0
    total_revenue = (
        await db.execute(
            select(func.coalesce(func.sum(Order.total), 0)).where(
                Order.status.in_(["payment_confirmed", "processing", "shipped", "delivered"])
            )
        )
    ).scalar()
    pending_orders = (
        await db.execute(
            select(func.count(Order.id)).where(
                Order.status.in_(["pending"])
            )
        )
    ).scalar() or 0

    # Recent orders
    recent_result = await db.execute(
        select(Order).order_by(Order.created_at.desc()).limit(10)
    )
    recent_orders = [
        {
            "id": str(o.id),
            "order_number": o.order_number,
            "status": o.status,
            "total": float(o.total),
            "created_at": o.created_at.isoformat(),
        }
        for o in recent_result.scalars().all()
    ]

    return {
        "total_users": total_users,
        "total_orders": total_orders,
        "total_revenue": float(total_revenue),
        "pending_orders": pending_orders,
        "recent_orders": recent_orders,
    }


@router.get("/metrics", dependencies=[Depends(require_admin)])
async def get_metrics(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
):
    """Analytics metrics: DAU, conversion rate, AOV, repeat purchase rate."""
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=days)
    paid_statuses = ["payment_confirmed", "processing", "shipped", "delivered", "ready_for_pickup"]

    # DAU — average daily active users (users who placed an order or chatted)
    # Using orders + chat sessions as proxy for "active"
    order_users_q = (
        select(
            func.date_trunc("day", Order.created_at).label("day"),
            func.count(distinct(Order.user_id)).label("users"),
        )
        .where(Order.created_at >= since)
        .group_by("day")
    )
    chat_users_q = (
        select(
            func.date_trunc("day", ChatSession.created_at).label("day"),
            func.count(distinct(ChatSession.user_id)).label("users"),
        )
        .where(ChatSession.created_at >= since)
        .group_by("day")
    )

    order_result = await db.execute(order_users_q)
    chat_result = await db.execute(chat_users_q)

    daily_users: dict[str, set] = {}
    # We can't merge sets from SQL, so we approximate: max of the two per day
    order_days = {str(r.day.date()): r.users for r in order_result}
    chat_days = {str(r.day.date()): r.users for r in chat_result}
    all_days = set(order_days.keys()) | set(chat_days.keys())
    dau_values = [max(order_days.get(d, 0), chat_days.get(d, 0)) for d in all_days]
    avg_dau = round(sum(dau_values) / len(dau_values), 1) if dau_values else 0

    # Conversion rate — users with at least 1 paid order / total users (in period)
    total_users = (await db.execute(
        select(func.count(Profile.id)).where(Profile.created_at >= since)
    )).scalar() or 0

    buyers = (await db.execute(
        select(func.count(distinct(Order.user_id))).where(
            Order.created_at >= since,
            Order.status.in_(paid_statuses),
        )
    )).scalar() or 0

    conversion_rate = round((buyers / total_users * 100), 1) if total_users > 0 else 0

    # Average Order Value (AOV)
    aov_result = (await db.execute(
        select(func.avg(Order.total)).where(
            Order.created_at >= since,
            Order.status.in_(paid_statuses),
        )
    )).scalar()
    aov = round(float(aov_result), 0) if aov_result else 0

    # Repeat purchase rate — buyers with 2+ paid orders / all buyers
    repeat_q = (
        select(func.count()).select_from(
            select(Order.user_id)
            .where(Order.created_at >= since, Order.status.in_(paid_statuses))
            .group_by(Order.user_id)
            .having(func.count(Order.id) >= 2)
            .subquery()
        )
    )
    repeat_buyers = (await db.execute(repeat_q)).scalar() or 0
    repeat_rate = round((repeat_buyers / buyers * 100), 1) if buyers > 0 else 0

    # Total paid orders in period
    paid_orders = (await db.execute(
        select(func.count(Order.id)).where(
            Order.created_at >= since,
            Order.status.in_(paid_statuses),
        )
    )).scalar() or 0

    # Revenue in period
    revenue = (await db.execute(
        select(func.coalesce(func.sum(Order.total), 0)).where(
            Order.created_at >= since,
            Order.status.in_(paid_statuses),
        )
    )).scalar()

    return {
        "period_days": days,
        "avg_dau": avg_dau,
        "conversion_rate_pct": conversion_rate,
        "aov": aov,
        "repeat_purchase_rate_pct": repeat_rate,
        "total_users_period": total_users,
        "total_buyers_period": buyers,
        "repeat_buyers": repeat_buyers,
        "paid_orders": paid_orders,
        "revenue": float(revenue),
    }
