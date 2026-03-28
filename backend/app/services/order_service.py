from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy import select

from app.models.cart import CartItem
from app.models.loyalty import LoyaltyAccount
from app.models.order import Order, OrderItem
from app.models.promo_code import PromoCode
from app.services.loyalty_service import award_purchase_points, redeem_points


async def generate_order_number(db: AsyncSession) -> str:
    result = await db.execute(text("SELECT nextval('order_number_seq')"))
    seq = result.scalar()
    year = datetime.now(timezone.utc).strftime("%Y")
    return f"TOOLOR-{year}-{seq:05d}"


async def create_order_from_cart(
    db: AsyncSession,
    user_id,
    payment_method: str,
    delivery_type: str = "pickup",
    delivery_address: str | None = None,
    delivery_notes: str | None = None,
    try_at_home: bool = False,
    points_used: int = 0,
    promo_code: str | None = None,
) -> Order:
    # Fetch cart items with products
    result = await db.execute(
        select(CartItem)
        .options(selectinload(CartItem.product))
        .where(CartItem.user_id == user_id)
    )
    cart_items = result.scalars().all()
    if not cart_items:
        raise ValueError("Cart is empty")

    # Calculate subtotal
    subtotal = Decimal(0)
    order_items = []
    for ci in cart_items:
        line_total = ci.product.price * ci.quantity
        subtotal += line_total
        order_items.append(OrderItem(
            product_id=ci.product_id,
            product_name=ci.product.name,
            product_price=ci.product.price,
            selected_size=ci.selected_size,
            selected_color=ci.selected_color,
            quantity=ci.quantity,
            line_total=line_total,
        ))

    # Apply promo code
    discount_amount = Decimal(0)
    if promo_code:
        promo_result = await db.execute(
            select(PromoCode).where(
                PromoCode.code == promo_code,
                PromoCode.is_active == True,
            )
        )
        promo = promo_result.scalar_one_or_none()
        if promo and subtotal >= promo.min_order:
            if promo.max_uses is None or promo.uses_count < promo.max_uses:
                if promo.discount_type == "percent":
                    discount_amount = subtotal * promo.discount_value / 100
                else:
                    discount_amount = min(promo.discount_value, subtotal)
                promo.uses_count += 1

    # Apply points
    points_discount = Decimal(0)
    loyalty_result = await db.execute(
        select(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id)
    )
    loyalty = loyalty_result.scalar_one_or_none()

    if points_used > 0 and loyalty:
        points_discount = await redeem_points(db, loyalty, points_used)

    total = max(subtotal - discount_amount - points_discount, Decimal(0))

    # Generate order number
    order_number = await generate_order_number(db)

    order = Order(
        user_id=user_id,
        order_number=order_number,
        status="pending",
        subtotal=subtotal,
        discount_amount=discount_amount,
        points_used=points_used,
        points_discount=points_discount,
        total=total,
        payment_method=payment_method,
        delivery_type=delivery_type,
        delivery_address=delivery_address,
        delivery_notes=delivery_notes,
        try_at_home=try_at_home,
    )
    db.add(order)
    await db.flush()

    # Attach items to order
    for item in order_items:
        item.order_id = order.id
        db.add(item)

    # Award loyalty points
    if loyalty:
        await award_purchase_points(db, loyalty, total, order_id=order.id)

    # Clear cart
    for ci in cart_items:
        await db.delete(ci)

    await db.flush()
    order.items = order_items
    return order
