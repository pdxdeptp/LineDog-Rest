from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import get_system_state, upsert_system_state

router = APIRouter()


@router.get("/settings/learning-preferences")
async def get_learning_preferences() -> dict:
    async with get_db() as db:
        raw = await get_system_state(db, "daily_capacity_min")
    daily_capacity_min = int(raw) if raw else 60
    return {"daily_capacity_min": daily_capacity_min}


class LearningPreferencesUpdate(BaseModel):
    daily_capacity_min: int


@router.put("/settings/learning-preferences")
async def update_learning_preferences(req: LearningPreferencesUpdate) -> dict:
    if not (1 <= req.daily_capacity_min <= 1440):
        raise HTTPException(
            status_code=422,
            detail="daily_capacity_min must be between 1 and 1440",
        )
    async with get_db() as db:
        await upsert_system_state(db, "daily_capacity_min", str(req.daily_capacity_min))
    return {"daily_capacity_min": req.daily_capacity_min}
