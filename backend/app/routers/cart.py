import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_current_user, get_db
from app.models.cart import CartItem
from app.models.user import Profile
from app.schemas.cart import CartItemCreate, CartItemOut, CartItemUpdate

router = APIRouter()


def _cart_item_to_out(ci: CartItem) -> CartItemOut:
    return CartItemOut(
        id=ci.id,
        product_id=ci.product_id,
        product_name=ci.product.name if ci.product else "",
        product_price=ci.product.price if ci.product else 0,
        product_image_url=ci.product.image_url if ci.product else "",
        selected_size=ci.selected_size,
        selected_color=ci.selected_color,
        quantity=ci.quantity,
    )


@router.get("", response_model=list[CartItemOut])
async def get_cart(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem)
        .options(selectinload(CartItem.product))
        .where(CartItem.user_id == user.id)
    )
    return [_cart_item_to_out(ci) for ci in result.scalars().all()]


@router.post("", response_model=CartItemOut)
async def add_to_cart(
    body: CartItemCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Upsert: if same product+size+color exists, increment quantity
    result = await db.execute(
        select(CartItem)
        .options(selectinload(CartItem.product))
        .where(
            CartItem.user_id == user.id,
            CartItem.product_id == body.product_id,
            CartItem.selected_size == body.selected_size,
            CartItem.selected_color == body.selected_color,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        existing.quantity += body.quantity
        await db.commit()
        await db.refresh(existing, ["product"])
        return _cart_item_to_out(existing)

    item = CartItem(
        user_id=user.id,
        product_id=body.product_id,
        selected_size=body.selected_size,
        selected_color=body.selected_color,
        quantity=body.quantity,
    )
    db.add(item)
    await db.commit()

    result = await db.execute(
        select(CartItem).options(selectinload(CartItem.product)).where(CartItem.id == item.id)
    )
    item = result.scalar_one()
    return _cart_item_to_out(item)


@router.patch("/{item_id}", response_model=CartItemOut)
async def update_cart_item(
    item_id: uuid.UUID,
    body: CartItemUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem)
        .options(selectinload(CartItem.product))
        .where(CartItem.id == item_id, CartItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")
    if body.quantity <= 0:
        await db.delete(item)
        await db.commit()
        raise HTTPException(status_code=204)
    item.quantity = body.quantity
    await db.commit()
    await db.refresh(item, ["product"])
    return _cart_item_to_out(item)


@router.delete("/{item_id}", status_code=204)
async def remove_cart_item(
    item_id: uuid.UUID,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")
    await db.delete(item)
    await db.commit()


@router.delete("", status_code=204)
async def clear_cart(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CartItem).where(CartItem.user_id == user.id)
    )
    for item in result.scalars().all():
        await db.delete(item)
    await db.commit()
