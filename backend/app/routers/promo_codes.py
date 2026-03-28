from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.promo_code import PromoCode
from app.models.user import Profile
from app.schemas.promo_code import PromoValidateRequest, PromoValidateResponse

router = APIRouter()


@router.post("/validate", response_model=PromoValidateResponse)
async def validate_promo(
    body: PromoValidateRequest,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PromoCode).where(
            PromoCode.code == body.code.upper(),
            PromoCode.is_active == True,
        )
    )
    promo = result.scalar_one_or_none()

    if not promo:
        return PromoValidateResponse(valid=False, message="Промокод не найден")

    now = datetime.now(timezone.utc)
    if promo.valid_until and promo.valid_until < now:
        return PromoValidateResponse(valid=False, message="Промокод истёк")

    if promo.max_uses is not None and promo.uses_count >= promo.max_uses:
        return PromoValidateResponse(valid=False, message="Промокод больше не действует")

    if body.order_total < promo.min_order:
        return PromoValidateResponse(
            valid=False,
            message=f"Минимальная сумма заказа: {promo.min_order} сом",
        )

    if promo.discount_type == "percent":
        discount_amount = body.order_total * promo.discount_value / 100
    else:
        discount_amount = min(promo.discount_value, body.order_total)

    return PromoValidateResponse(
        valid=True,
        discount_type=promo.discount_type,
        discount_value=promo.discount_value,
        discount_amount=discount_amount,
        message=f"Скидка {promo.discount_value}{'%' if promo.discount_type == 'percent' else ' сом'}",
    )
