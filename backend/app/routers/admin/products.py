import math
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db, require_admin
from app.models.product import Product
from app.routers.products import _product_to_out
from app.schemas.product import ProductCreate, ProductOut, ProductUpdate
from app.services.excel_import_service import parse_excel_bytes, import_to_db

router = APIRouter(dependencies=[Depends(require_admin)])


@router.post("/import-excel", response_model=dict)
async def import_excel(
    file: UploadFile = File(...),
    replace_all: bool = True,
    db: AsyncSession = Depends(get_db),
):
    """Upload a TOOLOR-format Excel file and bulk-import products.

    Parses sheet structure, groups variants by SKU, extracts sizes/colors/images,
    auto-creates categories and subcategories, and seeds per-size inventory for Asia Mall.
    """
    if not file.filename or not file.filename.lower().endswith((".xlsx", ".xlsm")):
        raise HTTPException(status_code=400, detail="Upload a .xlsx file")

    contents = await file.read()
    if len(contents) > 50 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 50MB)")

    try:
        products = parse_excel_bytes(contents)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to parse Excel: {e}")

    if not products:
        raise HTTPException(status_code=400, detail="No valid products found in Excel")

    try:
        summary = await import_to_db(db, products, replace_all=replace_all)
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Import failed: {e}")

    return {
        "ok": True,
        "filename": file.filename,
        "products_parsed": len(products),
        **summary,
    }


@router.get("", response_model=dict)
async def list_all_products(
    search: str | None = None,
    category_id: uuid.UUID | None = None,
    is_active: bool | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(Product).options(
        selectinload(Product.category), selectinload(Product.subcategory)
    )
    if search:
        query = query.where(Product.name.ilike(f"%{search}%"))
    if category_id:
        query = query.where(Product.category_id == category_id)
    if is_active is not None:
        query = query.where(Product.is_active == is_active)

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(Product.sort_order, Product.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)

    return {
        "items": [_product_to_out(p) for p in result.scalars().all()],
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": math.ceil(total / per_page) if per_page else 0,
    }


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


@router.post("", response_model=ProductOut, status_code=201)
async def create_product(body: ProductCreate, db: AsyncSession = Depends(get_db)):
    product = Product(**body.model_dump())
    db.add(product)
    await db.commit()
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.subcategory))
        .where(Product.id == product.id)
    )
    return _product_to_out(result.scalar_one())


@router.patch("/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: uuid.UUID, body: ProductUpdate, db: AsyncSession = Depends(get_db)
):
    product = await db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(product, field, value)
    await db.commit()
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.subcategory))
        .where(Product.id == product.id)
    )
    return _product_to_out(result.scalar_one())


@router.delete("/{product_id}", status_code=204)
async def delete_product(product_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    product = await db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    product.is_active = False
    await db.commit()
