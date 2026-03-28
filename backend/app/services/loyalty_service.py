from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction

TIER_THRESHOLDS = [
    (Decimal("300000"), "platinum"),
    (Decimal("150000"), "gold"),
    (Decimal("50000"), "silver"),
    (Decimal("0"), "bronze"),
]

TIER_CASHBACK = {
    "bronze": Decimal("0.03"),
    "silver": Decimal("0.05"),
    "gold": Decimal("0.08"),
    "platinum": Decimal("0.12"),
}


def calculate_tier(total_spent: Decimal) -> str:
    for threshold, tier in TIER_THRESHOLDS:
        if total_spent >= threshold:
            return tier
    return "bronze"


def get_cashback_rate(tier: str) -> Decimal:
    return TIER_CASHBACK.get(tier, Decimal("0.03"))


async def award_purchase_points(
    db: AsyncSession,
    loyalty: LoyaltyAccount,
    order_total: Decimal,
    order_id=None,
) -> int:
    rate = get_cashback_rate(loyalty.tier)
    points_earned = int(order_total * rate)

    loyalty.points += points_earned
    loyalty.total_spent += order_total
    loyalty.tier = calculate_tier(loyalty.total_spent)

    txn = LoyaltyTransaction(
        loyalty_id=loyalty.id,
        user_id=loyalty.user_id,
        order_id=order_id,
        type="purchase",
        amount=order_total,
        points_change=points_earned,
        description=f"Кэшбэк {int(rate * 100)}% за покупку",
    )
    db.add(txn)
    return points_earned


async def redeem_points(
    db: AsyncSession,
    loyalty: LoyaltyAccount,
    points: int,
    order_id=None,
) -> Decimal:
    if points > loyalty.points:
        points = loyalty.points
    # 1 point = 1 KGS
    discount = Decimal(points)
    loyalty.points -= points

    txn = LoyaltyTransaction(
        loyalty_id=loyalty.id,
        user_id=loyalty.user_id,
        order_id=order_id,
        type="points_redeemed",
        amount=discount,
        points_change=-points,
        description=f"Списание {points} баллов",
    )
    db.add(txn)
    return discount
