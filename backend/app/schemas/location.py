import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class LocationOut(BaseModel):
    id: uuid.UUID
    name: str
    address: str
    type: str
    hours: str | None = None
    note: str | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    is_active: bool
    sort_order: int
    created_at: datetime

    model_config = {"from_attributes": True}


class LocationCreate(BaseModel):
    name: str
    address: str
    type: str
    hours: str | None = None
    note: str | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    is_active: bool = True
    sort_order: int = 0


class LocationUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    type: str | None = None
    hours: str | None = None
    note: str | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    is_active: bool | None = None
    sort_order: int | None = None
