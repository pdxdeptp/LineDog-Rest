from datetime import date

from fastapi import APIRouter

from ..db.connection import get_db
from ..db.queries import rollover_unfinished_study_tasks

router = APIRouter()


@router.post("/study-plan-adjustment/rollover")
async def rollover_study_tasks() -> dict:
    async with get_db() as db:
        return await rollover_unfinished_study_tasks(db, date.today())
