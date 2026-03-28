from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_admin
from app.models.notification import Notification
from app.models.user import Profile
from app.schemas.notification import NotificationCreate, NotificationOut

router = APIRouter(dependencies=[Depends(require_admin)])


@router.post("/send", response_model=NotificationOut | list[NotificationOut])
async def send_notification(
    body: NotificationCreate,
    db: AsyncSession = Depends(get_db),
):
    if body.user_id:
        # Send to specific user
        notification = Notification(
            user_id=body.user_id,
            type=body.type,
            title=body.title,
            body=body.body,
        )
        db.add(notification)
        await db.commit()
        await db.refresh(notification)
        return NotificationOut.model_validate(notification)
    else:
        # Send to all users
        result = await db.execute(select(Profile.id))
        user_ids = result.scalars().all()

        notifications = []
        for uid in user_ids:
            n = Notification(
                user_id=uid,
                type=body.type,
                title=body.title,
                body=body.body,
            )
            db.add(n)
            notifications.append(n)

        await db.commit()
        for n in notifications:
            await db.refresh(n)
        return [NotificationOut.model_validate(n) for n in notifications]
