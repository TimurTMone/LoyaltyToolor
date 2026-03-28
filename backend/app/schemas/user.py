import uuid
from datetime import date, datetime

from pydantic import BaseModel


class UserOut(BaseModel):
    id: uuid.UUID
    phone: str
    full_name: str
    email: str | None = None
    avatar_url: str | None = None
    birth_date: date | None = None
    language: str
    is_admin: bool
    referral_code: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    full_name: str | None = None
    email: str | None = None
    birth_date: date | None = None
    language: str | None = None


class AdminUserUpdate(BaseModel):
    full_name: str | None = None
    email: str | None = None
    is_admin: bool | None = None
    language: str | None = None
