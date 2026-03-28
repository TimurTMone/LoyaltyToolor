import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class PromoCodeOut(BaseModel):
    id: uuid.UUID
    code: str
    discount_type: str | None = None
    discount_value: Decimal
    min_order: Decimal
    max_uses: int | None = None
    uses_count: int
    valid_from: datetime
    valid_until: datetime | None = None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class PromoCodeCreate(BaseModel):
    code: str
    discount_type: str
    discount_value: Decimal
    min_order: Decimal = Decimal(0)
    max_uses: int | None = None
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool = True


class PromoCodeUpdate(BaseModel):
    code: str | None = None
    discount_type: str | None = None
    discount_value: Decimal | None = None
    min_order: Decimal | None = None
    max_uses: int | None = None
    valid_until: datetime | None = None
    is_active: bool | None = None


class PromoValidateRequest(BaseModel):
    code: str
    order_total: Decimal


class PromoValidateResponse(BaseModel):
    valid: bool
    discount_type: str | None = None
    discount_value: Decimal | None = None
    discount_amount: Decimal | None = None
    message: str = ""
