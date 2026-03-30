import uuid
import math
from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db
from app.models.product import Category, Product, StoreInventory, Subcategory
from app.schemas.product import CategoryOut, ProductOut, StoreAvailabilityOut

router = APIRouter()


def _product_to_out(p: Product, availability: list[StoreAvailabilityOut] | None = None) -> ProductOut:
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
        store_availability=availability,
    )


async def _build_availability(
    db: AsyncSession,
    product_ids: list[uuid.UUID],
    location_id: uuid.UUID | None = None,
) -> dict[uuid.UUID, list[StoreAvailabilityOut]]:
    """Build per-store availability for a list of products."""
    query = (
        select(StoreInventory)
        .options(selectinload(StoreInventory.location))
        .where(StoreInventory.product_id.in_(product_ids))
    )
    if location_id:
        query = query.where(StoreInventory.location_id == location_id)

    result = await db.execute(query)
    rows = result.scalars().all()

    # Group by (product_id, location_id)
    grouped: dict[uuid.UUID, dict[uuid.UUID, list]] = defaultdict(lambda: defaultdict(list))
    loc_names: dict[uuid.UUID, str] = {}

    for row in rows:
        grouped[row.product_id][row.location_id].append(row)
        if row.location:
            loc_names[row.location_id] = row.location.name

    avail_map: dict[uuid.UUID, list[StoreAvailabilityOut]] = {}
    for pid, stores in grouped.items():
        avail_list = []
        for lid, inv_rows in stores.items():
            sizes_in_stock = [r.size for r in inv_rows if r.quantity > 0 and r.size is not None]
            total_qty = sum(r.quantity for r in inv_rows)
            avail_list.append(StoreAvailabilityOut(
                location_id=lid,
                location_name=loc_names.get(lid, ""),
                sizes_in_stock=sizes_in_stock,
                total_quantity=total_qty,
            ))
        avail_map[pid] = avail_list

    return avail_map


@router.get("", response_model=dict)
async def list_products(
    category_id: uuid.UUID | None = None,
    subcategory_id: uuid.UUID | None = None,
    search: str | None = None,
    on_sale: bool | None = None,
    is_featured: bool | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
    location_id: uuid.UUID | None = None,
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

    # Filter to products available at a specific store
    if location_id:
        available_product_ids = (
            select(StoreInventory.product_id)
            .where(
                StoreInventory.location_id == location_id,
                StoreInventory.quantity > 0,
            )
            .distinct()
        )
        query = query.where(Product.id.in_(available_product_ids))

    # Count
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    # Paginate
    query = query.order_by(Product.sort_order, Product.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    products = result.scalars().all()

    # Build availability data when location_id is provided
    avail_map = {}
    if location_id and products:
        avail_map = await _build_availability(db, [p.id for p in products], location_id)

    items = []
    for p in products:
        avail = avail_map.get(p.id) if location_id else None
        items.append(_product_to_out(p, availability=avail))

    return {
        "items": items,
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
async def get_product(
    product_id: uuid.UUID,
    location_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.subcategory))
        .where(Product.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    avail = None
    if location_id:
        avail_map = await _build_availability(db, [product.id], location_id)
        avail = avail_map.get(product.id)

    return _product_to_out(product, availability=avail)


@router.get("/{product_id}/availability")
async def get_product_availability(
    product_id: uuid.UUID,
    location_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_db),
):
    """Per-store availability for a product. Optionally filter to one store."""
    avail_map = await _build_availability(db, [product_id], location_id)
    return avail_map.get(product_id, [])
