import uuid
from decimal import Decimal

from pydantic import BaseModel


class CartItemCreate(BaseModel):
    product_id: uuid.UUID
    selected_size: str | None = None
    selected_color: str | None = None
    quantity: int = 1


class CartItemUpdate(BaseModel):
    quantity: int


class CartItemOut(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str = ""
    product_price: Decimal = Decimal(0)
    product_image_url: str = ""
    selected_size: str | None = None
    selected_color: str | None = None
    quantity: int

    model_config = {"from_attributes": True}
