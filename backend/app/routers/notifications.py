import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.notification import Notification
from app.models.user import Profile
from app.schemas.notification import DeviceRegister, NotificationOut, UnreadCount

router = APIRouter()


@router.post("/register-device")
async def register_device(
    body: DeviceRegister,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user.fcm_token = body.fcm_token
    await db.commit()
    return {"status": "ok"}


@router.get("", response_model=dict)
async def list_notifications(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base = select(Notification).where(Notification.user_id == user.id)
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = (
        base.order_by(Notification.created_at.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
    )
    result = await db.execute(query)
    items = result.scalars().all()

    return {
        "items": [NotificationOut.model_validate(n) for n in items],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


@router.patch("/{notification_id}/read", response_model=NotificationOut)
async def mark_notification_read(
    notification_id: uuid.UUID,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.read = True
    await db.commit()
    await db.refresh(notification)
    return NotificationOut.model_validate(notification)


@router.get("/unread-count", response_model=UnreadCount)
async def get_unread_count(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    count_q = select(func.count()).select_from(
        select(Notification)
        .where(Notification.user_id == user.id, Notification.read == False)
        .subquery()
    )
    count = (await db.execute(count_q)).scalar() or 0
    return UnreadCount(count=count)
