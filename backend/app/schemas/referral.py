import uuid
from datetime import datetime

from pydantic import BaseModel


class ReferralCodeOut(BaseModel):
    referral_code: str
    total_referrals: int
    total_points_earned: int


class ReferredUserOut(BaseModel):
    id: uuid.UUID
    full_name: str
    points_awarded: int
    created_at: datetime


class ReferralListOut(BaseModel):
    referrals: list[ReferredUserOut]
    total: int


class ApplyReferralRequest(BaseModel):
    referral_code: str
