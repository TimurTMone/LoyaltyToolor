import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.product import ProductOut


class FavoriteOut(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    product: ProductOut
    created_at: datetime

    model_config = {"from_attributes": True}
