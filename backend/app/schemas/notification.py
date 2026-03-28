import uuid
from datetime import datetime

from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str | None = None
    data: dict = {}
    read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class NotificationCreate(BaseModel):
    user_id: uuid.UUID | None = None
    title: str
    body: str
    type: str = "general"


class DeviceRegister(BaseModel):
    fcm_token: str


class UnreadCount(BaseModel):
    count: int
