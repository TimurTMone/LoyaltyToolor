import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_admin
from app.models.promo_code import PromoCode
from app.schemas.promo_code import PromoCodeCreate, PromoCodeOut, PromoCodeUpdate

router = APIRouter(dependencies=[Depends(require_admin)])


@router.get("", response_model=dict)
async def list_promo_codes(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(PromoCode).order_by(PromoCode.created_at.desc())
    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)

    return {
        "items": [PromoCodeOut.model_validate(p) for p in result.scalars().all()],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


@router.post("", response_model=PromoCodeOut, status_code=201)
async def create_promo_code(body: PromoCodeCreate, db: AsyncSession = Depends(get_db)):
    promo = PromoCode(**body.model_dump())
    promo.code = promo.code.upper()
    db.add(promo)
    await db.commit()
    await db.refresh(promo)
    return PromoCodeOut.model_validate(promo)


@router.patch("/{promo_id}", response_model=PromoCodeOut)
async def update_promo_code(
    promo_id: uuid.UUID, body: PromoCodeUpdate, db: AsyncSession = Depends(get_db)
):
    promo = await db.get(PromoCode, promo_id)
    if not promo:
        raise HTTPException(status_code=404, detail="Promo code not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        if field == "code" and value:
            value = value.upper()
        setattr(promo, field, value)
    await db.commit()
    await db.refresh(promo)
    return PromoCodeOut.model_validate(promo)


@router.delete("/{promo_id}", status_code=204)
async def delete_promo_code(promo_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    promo = await db.get(PromoCode, promo_id)
    if not promo:
        raise HTTPException(status_code=404, detail="Promo code not found")
    await db.delete(promo)
    await db.commit()
