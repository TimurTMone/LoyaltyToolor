from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.location import Location
from app.schemas.location import LocationOut

router = APIRouter()


@router.get("", response_model=list[LocationOut])
async def list_locations(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Location)
        .where(Location.is_active == True)
        .order_by(Location.sort_order)
    )
    return [LocationOut.model_validate(loc) for loc in result.scalars().all()]
