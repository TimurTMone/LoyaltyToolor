from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_admin
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
                Order.status.in_(["pending", "payment_uploaded"])
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
