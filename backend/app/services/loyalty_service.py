from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.loyalty import LoyaltyAccount, LoyaltyTransaction
from app.models.notification import Notification

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

TIER_NAMES_RU = {
    "bronze": "Бронза",
    "silver": "Серебро",
    "gold": "Золото",
    "platinum": "Платина",
}

TIER_ORDER = ["bronze", "silver", "gold", "platinum"]

BIRTHDAY_BONUS_POINTS = 1000


def calculate_tier(total_spent: Decimal) -> str:
    for threshold, tier in TIER_THRESHOLDS:
        if total_spent >= threshold:
            return tier
    return "bronze"


def get_cashback_rate(tier: str) -> Decimal:
    return TIER_CASHBACK.get(tier, Decimal("0.03"))


def get_next_tier(current_tier: str) -> tuple[str | None, Decimal | None]:
    """Return the next tier and its threshold, or (None, None) if already at max."""
    idx = TIER_ORDER.index(current_tier) if current_tier in TIER_ORDER else 0
    if idx >= len(TIER_ORDER) - 1:
        return None, None
    next_tier = TIER_ORDER[idx + 1]
    for threshold, tier in TIER_THRESHOLDS:
        if tier == next_tier:
            return next_tier, threshold
    return None, None


async def check_milestones(db: AsyncSession, user_id, loyalty: LoyaltyAccount) -> None:
    """Check if user crossed a tier threshold and update + notify."""
    old_tier = loyalty.tier
    new_tier = calculate_tier(loyalty.total_spent)
    if new_tier != old_tier and TIER_ORDER.index(new_tier) > TIER_ORDER.index(old_tier):
        loyalty.tier = new_tier
        cashback = int(get_cashback_rate(new_tier) * 100)
        tier_name = TIER_NAMES_RU.get(new_tier, new_tier)
        notification = Notification(
            user_id=user_id,
            type="milestone",
            title=f"Новый уровень: {tier_name}!",
            body=f"Поздравляем! Вы достигли уровня {tier_name}! Теперь ваш кешбэк {cashback}%",
        )
        db.add(notification)


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

    # Check milestones after purchase
    await check_milestones(db, loyalty.user_id, loyalty)

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


async def check_birthday_reward(db: AsyncSession, user, loyalty: LoyaltyAccount) -> None:
    """Award birthday bonus if today is user's birthday and not yet awarded this year."""
    if not user.birth_date:
        return

    today = date.today()
    if user.birth_date.month != today.month or user.birth_date.day != today.day:
        return

    # Check if birthday reward was already given this year
    year_start = datetime(today.year, 1, 1, tzinfo=timezone.utc)
    result = await db.execute(
        select(LoyaltyTransaction).where(
            LoyaltyTransaction.loyalty_id == loyalty.id,
            LoyaltyTransaction.type == "bonus",
            LoyaltyTransaction.description.contains("С днём рождения"),
            LoyaltyTransaction.created_at >= year_start,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        return

    # Award birthday points
    loyalty.points += BIRTHDAY_BONUS_POINTS
    txn = LoyaltyTransaction(
        loyalty_id=loyalty.id,
        user_id=user.id,
        type="bonus",
        amount=0,
        points_change=BIRTHDAY_BONUS_POINTS,
        description="\U0001f382 С днём рождения! +1000 баллов",
    )
    db.add(txn)

    notification = Notification(
        user_id=user.id,
        type="birthday",
        title="С днём рождения! \U0001f389",
        body=f"Поздравляем с днём рождения! Мы начислили вам {BIRTHDAY_BONUS_POINTS} бонусных баллов!",
    )
    db.add(notification)
