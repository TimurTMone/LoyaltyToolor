import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_current_user, get_db
from app.models.favorite import Favorite
from app.models.product import Product
from app.models.user import Profile
from app.routers.products import _product_to_out
from app.schemas.product import ProductOut

router = APIRouter()


@router.get("", response_model=list[ProductOut])
async def get_favorites(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Favorite)
        .options(
            selectinload(Favorite.product).selectinload(Product.category),
            selectinload(Favorite.product).selectinload(Product.subcategory),
        )
        .where(Favorite.user_id == user.id)
    )
    favorites = result.scalars().all()
    return [_product_to_out(f.product) for f in favorites if f.product]


@router.post("/{product_id}", status_code=201)
async def add_favorite(
    product_id: uuid.UUID,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Favorite).where(
            Favorite.user_id == user.id, Favorite.product_id == product_id
        )
    )
    if existing.scalar_one_or_none():
        return {"detail": "Already in favorites"}

    db.add(Favorite(user_id=user.id, product_id=product_id))
    await db.commit()
    return {"detail": "Added to favorites"}


@router.delete("/{product_id}", status_code=204)
async def remove_favorite(
    product_id: uuid.UUID,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Favorite).where(
            Favorite.user_id == user.id, Favorite.product_id == product_id
        )
    )
    fav = result.scalar_one_or_none()
    if not fav:
        raise HTTPException(status_code=404, detail="Not in favorites")
    await db.delete(fav)
    await db.commit()
