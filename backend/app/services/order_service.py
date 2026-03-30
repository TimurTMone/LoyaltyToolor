from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy import select

from app.models.cart import CartItem
from app.models.location import Location
from app.models.loyalty import LoyaltyAccount
from app.models.order import Order, OrderItem
from app.models.product import StoreInventory
from app.models.promo_code import PromoCode
from app.services.loyalty_service import award_purchase_points, redeem_points


async def generate_order_number(db: AsyncSession) -> str:
    result = await db.execute(text("SELECT nextval('order_number_seq')"))
    seq = result.scalar()
    year = datetime.now(timezone.utc).strftime("%Y")
    return f"TOOLOR-{year}-{seq:05d}"


async def _resolve_source_location(
    db: AsyncSession,
    delivery_type: str,
    pickup_location_id=None,
):
    """Determine which store to decrement stock from."""
    if delivery_type == "pickup" and pickup_location_id:
        return pickup_location_id

    # For delivery orders, use the first active store as fulfillment center
    result = await db.execute(
        select(Location.id)
        .where(Location.type == "store", Location.is_active == True)
        .order_by(Location.sort_order)
        .limit(1)
    )
    return result.scalar_one_or_none()


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
    pickup_location_id=None,
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

    # Determine which store fulfills this order
    source_location_id = await _resolve_source_location(db, delivery_type, pickup_location_id)

    # Check per-store stock availability
    for ci in cart_items:
        if source_location_id:
            inv_result = await db.execute(
                select(StoreInventory).where(
                    StoreInventory.location_id == source_location_id,
                    StoreInventory.product_id == ci.product_id,
                    StoreInventory.size == ci.selected_size,
                )
            )
            inv = inv_result.scalar_one_or_none()
            if inv is not None and inv.quantity < ci.quantity:
                size_label = f" размер {ci.selected_size}" if ci.selected_size else ""
                raise ValueError(
                    f"Товар '{ci.product.name}'{size_label} нет в наличии "
                    f"в выбранном магазине (осталось {inv.quantity})"
                )
        else:
            # Fallback to global stock if no store resolved
            if ci.product.stock is not None and ci.product.stock < ci.quantity:
                raise ValueError(
                    f"Товар '{ci.product.name}' нет в наличии (осталось {ci.product.stock})"
                )

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
        # Validate: can't redeem more points than available
        if points_used > loyalty.points:
            raise ValueError(f"Недостаточно баллов. Доступно: {loyalty.points}")
        # Validate: can't redeem more points than the order total after promo discount
        max_redeemable = int(subtotal - discount_amount)
        if points_used > max_redeemable:
            raise ValueError(f"Нельзя списать больше баллов, чем сумма заказа ({max_redeemable})")
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
        pickup_location_id=pickup_location_id,
    )
    db.add(order)
    await db.flush()

    # Attach items to order
    for item in order_items:
        item.order_id = order.id
        db.add(item)

    # Decrement per-store inventory (with row lock for concurrency)
    for ci in cart_items:
        if source_location_id:
            inv_result = await db.execute(
                select(StoreInventory)
                .where(
                    StoreInventory.location_id == source_location_id,
                    StoreInventory.product_id == ci.product_id,
                    StoreInventory.size == ci.selected_size,
                )
                .with_for_update()
            )
            inv = inv_result.scalar_one_or_none()
            if inv:
                inv.quantity = max(inv.quantity - ci.quantity, 0)
        else:
            # Fallback: decrement global stock
            if ci.product.stock is not None:
                ci.product.stock -= ci.quantity

    # Award loyalty points
    if loyalty:
        await award_purchase_points(db, loyalty, total, order_id=order.id)

    # Clear cart
    for ci in cart_items:
        await db.delete(ci)

    await db.flush()
    await db.refresh(order, ["items"])
    return order
