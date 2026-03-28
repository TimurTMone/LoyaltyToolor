import uuid
import math

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db
from app.models.product import Category, Product, Subcategory
from app.schemas.product import CategoryOut, ProductOut

router = APIRouter()


def _product_to_out(p: Product) -> ProductOut:
    return ProductOut(
        id=p.id,
        sku=p.sku,
        name=p.name,
        slug=p.slug,
        description=p.description,
        price=p.price,
        original_price=p.original_price,
        category_id=p.category_id,
        subcategory_id=p.subcategory_id,
        category_name=p.category.name if p.category else "",
        subcategory_name=p.subcategory.name if p.subcategory else "",
        image_url=p.image_url,
        images=p.images,
        sizes=p.sizes,
        colors=p.colors,
        stock=p.stock,
        is_active=p.is_active,
        is_featured=p.is_featured,
        sort_order=p.sort_order,
        created_at=p.created_at,
    )


@router.get("", response_model=dict)
async def list_products(
    category_id: uuid.UUID | None = None,
    subcategory_id: uuid.UUID | None = None,
    search: str | None = None,
    on_sale: bool | None = None,
    is_featured: bool | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.subcategory))
        .where(Product.is_active == True)
    )

    if category_id:
        query = query.where(Product.category_id == category_id)
    if subcategory_id:
        query = query.where(Product.subcategory_id == subcategory_id)
    if search:
        query = query.where(
            or_(
                Product.name.ilike(f"%{search}%"),
                Product.description.ilike(f"%{search}%"),
            )
        )
    if on_sale:
        query = query.where(Product.original_price.isnot(None))
    if is_featured:
        query = query.where(Product.is_featured == True)
    if min_price is not None:
        query = query.where(Product.price >= min_price)
    if max_price is not None:
        query = query.where(Product.price <= max_price)

    # Count
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    # Paginate
    query = query.order_by(Product.sort_order, Product.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    products = result.scalars().all()

    return {
        "items": [_product_to_out(p) for p in products],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.subcategories))
        .order_by(Category.sort_order)
    )
    return [CategoryOut.model_validate(c) for c in result.scalars().all()]


@router.get("/{product_id}", response_model=ProductOut)
async def get_product(product_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.subcategory))
        .where(Product.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return _product_to_out(product)
