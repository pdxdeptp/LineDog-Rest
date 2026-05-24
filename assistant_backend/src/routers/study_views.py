from datetime import date

from fastapi import APIRouter, HTTPException

from ..db.connection import get_db
from ..db.queries import (
    get_study_calendar_load,
    get_study_project_overview,
    get_today_study_view_tasks,
    rollover_unfinished_study_tasks,
)

router = APIRouter()


@router.get("/study-views/today")
async def get_today_study_view() -> dict:
    today = date.today()
    async with get_db() as db:
        await rollover_unfinished_study_tasks(db, today)
        tasks = await get_today_study_view_tasks(db, today)

    return {
        "date": today.isoformat(),
        "tasks": tasks,
    }


@router.get("/study-views/projects")
async def get_study_project_overview_view() -> dict:
    async with get_db() as db:
        return await get_study_project_overview(db)


@router.get("/study-views/calendar")
async def get_study_calendar_load_view(start: date, end: date) -> dict:
    if end < start:
        raise HTTPException(status_code=400, detail="end must be on or after start")

    async with get_db() as db:
        return await get_study_calendar_load(db, start, end)
