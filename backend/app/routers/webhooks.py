import hashlib
import hmac
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.dependencies import get_db
from app.models.notification import Notification
from app.models.order import Order

logger = logging.getLogger(__name__)

router = APIRouter()


def _verify_finik_signature(body_bytes: bytes, signature: str | None) -> bool:
    """Verify webhook signature if FINIK_WEBHOOK_SECRET is configured."""
    secret = settings.FINIK_WEBHOOK_SECRET
    if not secret:
        # No secret configured — accept but log warning
        logger.warning("FINIK_WEBHOOK_SECRET not set — skipping signature check")
        return True
    if not signature:
        return False
    expected = hmac.new(secret.encode(), body_bytes, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


@router.post("/finik")
async def finik_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """Server-to-server webhook called by Finik after payment completes."""
    body_bytes = await request.body()
    signature = request.headers.get("x-finik-signature")

    if not _verify_finik_signature(body_bytes, signature):
        logger.warning("Finik webhook: invalid signature")
        raise HTTPException(status_code=403, detail="Invalid signature")

    body = await request.json()
    logger.info("Finik webhook received: %s", body)

    status_val = body.get("status")
    fields = body.get("fields", {})
    order_id = fields.get("order_id")
    transaction_id = body.get("transactionId")

    if not order_id or status_val != "SUCCEEDED":
        return {"ok": True, "action": "ignored"}

    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        logger.warning("Finik webhook: order %s not found", order_id)
        return {"ok": True, "action": "order_not_found"}

    if order.status in ("payment_confirmed", "processing", "shipped", "delivered"):
        return {"ok": True, "action": "already_confirmed"}

    # Prevent duplicate transaction IDs
    if transaction_id:
        dup = await db.execute(
            select(Order).where(Order.payment_transaction_id == transaction_id)
        )
        if dup.scalar_one_or_none():
            logger.warning("Finik webhook: duplicate transaction %s", transaction_id)
            return {"ok": True, "action": "duplicate_transaction"}

    order.status = "payment_confirmed"
    order.payment_transaction_id = transaction_id
    order.payment_provider = "finik"
    order.confirmed_at = datetime.now(timezone.utc)

    notification = Notification(
        user_id=order.user_id,
        type="order_status",
        title=f"Заказ #{order.order_number}",
        body="Оплата подтверждена",
        data={"order_id": str(order.id), "status": "payment_confirmed"},
    )
    db.add(notification)

    await db.commit()
    logger.info("Finik webhook: order %s confirmed via webhook", order_id)
    return {"ok": True, "action": "confirmed"}
