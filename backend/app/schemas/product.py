import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class SubcategoryOut(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    sort_order: int

    model_config = {"from_attributes": True}


class CategoryOut(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    sort_order: int
    subcategories: list[SubcategoryOut] = []

    model_config = {"from_attributes": True}


class StoreAvailabilityOut(BaseModel):
    location_id: uuid.UUID
    location_name: str
    sizes_in_stock: list[str] = []
    total_quantity: int = 0


class ProductOut(BaseModel):
    id: uuid.UUID
    sku: str | None = None
    name: str
    slug: str
    description: str
    price: Decimal
    original_price: Decimal | None = None
    category_id: uuid.UUID
    subcategory_id: uuid.UUID
    category_name: str = ""
    subcategory_name: str = ""
    image_url: str
    images: list = []
    sizes: list = []
    colors: list = []
    stock: int | None = None
    is_active: bool
    is_featured: bool
    sort_order: int
    created_at: datetime
    store_availability: list[StoreAvailabilityOut] | None = None

    model_config = {"from_attributes": True}


class ProductCreate(BaseModel):
    sku: str | None = None
    name: str
    slug: str
    description: str = ""
    price: Decimal
    original_price: Decimal | None = None
    category_id: uuid.UUID
    subcategory_id: uuid.UUID
    image_url: str
    images: list = []
    sizes: list = []
    colors: list = []
    stock: int | None = None
    is_active: bool = True
    is_featured: bool = False
    sort_order: int = 0


class ProductUpdate(BaseModel):
    name: str | None = None
    slug: str | None = None
    description: str | None = None
    price: Decimal | None = None
    original_price: Decimal | None = None
    category_id: uuid.UUID | None = None
    subcategory_id: uuid.UUID | None = None
    image_url: str | None = None
    images: list | None = None
    sizes: list | None = None
    colors: list | None = None
    stock: int | None = None
    is_active: bool | None = None
    is_featured: bool | None = None
    sort_order: int | None = None


class CategoryCreate(BaseModel):
    name: str
    slug: str
    sort_order: int = 0


class SubcategoryCreate(BaseModel):
    category_id: uuid.UUID
    name: str
    slug: str
    sort_order: int = 0


# ── Store Inventory Schemas ──────────────────────────────────────────────

class StoreInventoryOut(BaseModel):
    id: uuid.UUID
    location_id: uuid.UUID
    product_id: uuid.UUID
    size: str | None = None
    quantity: int

    model_config = {"from_attributes": True}


class StoreInventoryUpdate(BaseModel):
    quantity: int


class BulkInventoryItem(BaseModel):
    location_id: uuid.UUID
    product_id: uuid.UUID
    size: str | None = None
    quantity: int


class BulkInventoryUpdate(BaseModel):
    items: list[BulkInventoryItem]


class AssignProductRequest(BaseModel):
    location_id: uuid.UUID
    product_id: uuid.UUID
