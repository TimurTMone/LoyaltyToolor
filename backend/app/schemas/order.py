import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel


class OrderItemOut(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    product_price: Decimal
    selected_size: str | None = None
    selected_color: str | None = None
    quantity: int
    line_total: Decimal

    model_config = {"from_attributes": True}


class OrderOut(BaseModel):
    id: uuid.UUID
    order_number: str
    status: str
    subtotal: Decimal
    discount_amount: Decimal
    points_used: int
    points_discount: Decimal
    total: Decimal
    currency: str
    payment_method: str | None = None
    payment_transaction_id: str | None = None
    payment_provider: str | None = None
    delivery_address: str | None = None
    delivery_type: str
    delivery_notes: str | None = None
    try_at_home: bool
    admin_notes: str | None = None
    confirmed_at: datetime | None = None
    shipped_at: datetime | None = None
    delivered_at: datetime | None = None
    pickup_location_id: uuid.UUID | None = None
    ready_for_pickup_at: datetime | None = None
    created_at: datetime
    items: list[OrderItemOut] = []

    model_config = {"from_attributes": True}


class OrderCreate(BaseModel):
    payment_method: str
    delivery_address: str | None = None
    delivery_type: Literal["pickup", "delivery"] = "pickup"
    delivery_notes: str | None = None
    try_at_home: bool = False
    points_used: int = 0
    promo_code: str | None = None
    pickup_location_id: uuid.UUID | None = None


class OrderStatusUpdate(BaseModel):
    status: Literal[
        "pending",
        "payment_confirmed",
        "processing",
        "ready_for_pickup",
        "shipped",
        "delivered",
        "cancelled",
    ]
    admin_notes: str | None = None


class TimelineEntry(BaseModel):
    status: str
    timestamp: datetime
    note: str


class OrderTrackOut(BaseModel):
    order: OrderOut
    timeline: list[TimelineEntry]


class AdminOrderOut(OrderOut):
    user_id: uuid.UUID
    user_phone: str = ""
    user_name: str = ""
