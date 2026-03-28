import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db, require_admin
from app.models.product import Category, Subcategory
from app.schemas.product import CategoryCreate, CategoryOut, SubcategoryCreate, SubcategoryOut

router = APIRouter(dependencies=[Depends(require_admin)])


@router.get("", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.subcategories))
        .order_by(Category.sort_order)
    )
    return [CategoryOut.model_validate(c) for c in result.scalars().all()]


@router.post("", response_model=CategoryOut, status_code=201)
async def create_category(body: CategoryCreate, db: AsyncSession = Depends(get_db)):
    cat = Category(**body.model_dump())
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return CategoryOut(
        id=cat.id, name=cat.name, slug=cat.slug,
        sort_order=cat.sort_order, subcategories=[],
    )


@router.patch("/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: uuid.UUID, body: CategoryCreate, db: AsyncSession = Depends(get_db)
):
    cat = await db.get(Category, category_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    await db.commit()
    result = await db.execute(
        select(Category).options(selectinload(Category.subcategories)).where(Category.id == cat.id)
    )
    return CategoryOut.model_validate(result.scalar_one())


@router.delete("/{category_id}", status_code=204)
async def delete_category(category_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    cat = await db.get(Category, category_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await db.delete(cat)
    await db.commit()


# --- Subcategories ---

@router.post("/subcategories", response_model=SubcategoryOut, status_code=201)
async def create_subcategory(body: SubcategoryCreate, db: AsyncSession = Depends(get_db)):
    sub = Subcategory(**body.model_dump())
    db.add(sub)
    await db.commit()
    await db.refresh(sub)
    return SubcategoryOut.model_validate(sub)


@router.patch("/subcategories/{subcategory_id}", response_model=SubcategoryOut)
async def update_subcategory(
    subcategory_id: uuid.UUID, body: SubcategoryCreate, db: AsyncSession = Depends(get_db)
):
    sub = await db.get(Subcategory, subcategory_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subcategory not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(sub, field, value)
    await db.commit()
    await db.refresh(sub)
    return SubcategoryOut.model_validate(sub)


@router.delete("/subcategories/{subcategory_id}", status_code=204)
async def delete_subcategory(subcategory_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    sub = await db.get(Subcategory, subcategory_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subcategory not found")
    await db.delete(sub)
    await db.commit()
