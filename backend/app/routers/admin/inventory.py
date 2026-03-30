import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db, require_admin
from app.models.location import Location
from app.models.product import Product, StoreInventory
from app.schemas.product import (
    AssignProductRequest,
    BulkInventoryUpdate,
    StoreInventoryOut,
    StoreInventoryUpdate,
)

router = APIRouter(dependencies=[Depends(require_admin)])


@router.get("", response_model=list[StoreInventoryOut])
async def list_inventory(
    location_id: uuid.UUID | None = None,
    product_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(StoreInventory)
    if location_id:
        query = query.where(StoreInventory.location_id == location_id)
    if product_id:
        query = query.where(StoreInventory.product_id == product_id)
    query = query.order_by(StoreInventory.product_id, StoreInventory.size)
    result = await db.execute(query)
    return [StoreInventoryOut.model_validate(r) for r in result.scalars().all()]


@router.get("/by-location/{location_id}")
async def inventory_by_location(
    location_id: uuid.UUID,
    search: str | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    """All inventory at a specific store, grouped by product."""
    query = (
        select(StoreInventory)
        .options(selectinload(StoreInventory.product))
        .where(StoreInventory.location_id == location_id)
    )
    if search:
        query = query.join(Product).where(Product.name.ilike(f"%{search}%"))

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(StoreInventory.product_id, StoreInventory.size)
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    rows = result.scalars().all()

    items = []
    for row in rows:
        items.append({
            "id": str(row.id),
            "location_id": str(row.location_id),
            "product_id": str(row.product_id),
            "product_name": row.product.name if row.product else "",
            "product_image": row.product.image_url if row.product else "",
            "size": row.size,
            "quantity": row.quantity,
        })

    return {"items": items, "total": total, "page": page, "per_page": per_page}


@router.get("/by-product/{product_id}")
async def inventory_by_product(product_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Inventory across all stores for a given product."""
    result = await db.execute(
        select(StoreInventory)
        .options(selectinload(StoreInventory.location))
        .where(StoreInventory.product_id == product_id)
        .order_by(StoreInventory.location_id, StoreInventory.size)
    )
    rows = result.scalars().all()

    items = []
    for row in rows:
        items.append({
            "id": str(row.id),
            "location_id": str(row.location_id),
            "location_name": row.location.name if row.location else "",
            "product_id": str(row.product_id),
            "size": row.size,
            "quantity": row.quantity,
        })
    return items


@router.put("")
async def bulk_upsert_inventory(body: BulkInventoryUpdate, db: AsyncSession = Depends(get_db)):
    """Bulk upsert inventory rows. Creates or updates based on (location, product, size)."""
    results = []
    for item in body.items:
        existing = await db.execute(
            select(StoreInventory).where(
                StoreInventory.location_id == item.location_id,
                StoreInventory.product_id == item.product_id,
                StoreInventory.size == item.size,
            )
        )
        row = existing.scalar_one_or_none()
        if row:
            row.quantity = item.quantity
        else:
            row = StoreInventory(
                location_id=item.location_id,
                product_id=item.product_id,
                size=item.size,
                quantity=item.quantity,
            )
            db.add(row)
        results.append({"product_id": str(item.product_id), "size": item.size, "quantity": item.quantity})

    await db.commit()
    return {"updated": len(results), "items": results}


@router.patch("/{inventory_id}", response_model=StoreInventoryOut)
async def update_inventory_item(
    inventory_id: uuid.UUID,
    body: StoreInventoryUpdate,
    db: AsyncSession = Depends(get_db),
):
    row = await db.get(StoreInventory, inventory_id)
    if not row:
        raise HTTPException(status_code=404, detail="Inventory row not found")
    row.quantity = body.quantity
    await db.commit()
    await db.refresh(row)
    return StoreInventoryOut.model_validate(row)


@router.post("/assign-product", status_code=201)
async def assign_product_to_store(body: AssignProductRequest, db: AsyncSession = Depends(get_db)):
    """Assign a product to a store — creates inventory rows for all its sizes (qty=0)."""
    product = await db.get(Product, body.product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    location = await db.get(Location, body.location_id)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")

    sizes = product.sizes if product.sizes else [None]
    created = 0
    for size in sizes:
        existing = await db.execute(
            select(StoreInventory).where(
                StoreInventory.location_id == body.location_id,
                StoreInventory.product_id == body.product_id,
                StoreInventory.size == size,
            )
        )
        if not existing.scalar_one_or_none():
            db.add(StoreInventory(
                location_id=body.location_id,
                product_id=body.product_id,
                size=size,
                quantity=0,
            ))
            created += 1

    await db.commit()
    return {"created": created, "sizes": sizes}
