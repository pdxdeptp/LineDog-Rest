from datetime import date

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import (
    TaskMoveNotAllowedError,
    TaskMovePastDateError,
    TaskNotFoundError,
    move_active_study_task,
    rollover_unfinished_study_tasks,
)

router = APIRouter()


class MoveTaskRequest(BaseModel):
    scheduled_date: date


@router.post("/study-plan-adjustment/rollover")
async def rollover_study_tasks() -> dict:
    async with get_db() as db:
        return await rollover_unfinished_study_tasks(db, date.today())


@router.post("/study-plan-adjustment/tasks/{task_id}/move")
async def move_study_task(task_id: int, request: MoveTaskRequest) -> dict:
    async with get_db() as db:
        try:
            return await move_active_study_task(db, task_id, request.scheduled_date, date.today())
        except TaskMovePastDateError as exc:
            raise HTTPException(status_code=400, detail="scheduled_date cannot be before today") from exc
        except TaskNotFoundError as exc:
            raise HTTPException(status_code=404, detail="task not found") from exc
        except TaskMoveNotAllowedError as exc:
            raise HTTPException(status_code=409, detail="task cannot be moved") from exc
