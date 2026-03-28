import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class LoyaltyAccountOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    qr_code: str
    tier: str
    points: int
    total_spent: Decimal
    created_at: datetime

    model_config = {"from_attributes": True}


class LoyaltyTransactionOut(BaseModel):
    id: uuid.UUID
    type: str
    amount: Decimal
    points_change: int
    description: str
    order_id: uuid.UUID | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AdminLoyaltyAdjust(BaseModel):
    points_change: int
    description: str


class QrScanRequest(BaseModel):
    qr_token: str


class QrScanCustomer(BaseModel):
    name: str
    phone: str
    tier: str
    points: int
    total_spent: Decimal
    cashback_percent: int


class QrScanResponse(BaseModel):
    valid: bool
    reason: str | None = None
    customer: QrScanCustomer | None = None


class MilestonesOut(BaseModel):
    current_tier: str
    current_spent: float
    next_tier: str | None = None
    next_tier_threshold: float | None = None
    remaining: float
    progress_percent: float
