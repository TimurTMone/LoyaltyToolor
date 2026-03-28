import uuid
from datetime import datetime

from pydantic import BaseModel


class ChatSessionOut(BaseModel):
    id: uuid.UUID
    title: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChatMessageCreate(BaseModel):
    content: str


class ChatMessageOut(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    role: str
    content: str
    products: list = []
    created_at: datetime

    model_config = {"from_attributes": True}
