from datetime import date

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator

from ..db.connection import get_db
from ..db.queries import (
    ResourceDeadlineEditNotAllowedError,
    ResourceNotFoundError,
    TaskMoveNotAllowedError,
    TaskMovePastDateError,
    TaskNotFoundError,
    move_active_study_task,
    rollover_unfinished_study_tasks,
    update_active_study_project_deadline,
)

router = APIRouter()


class MoveTaskRequest(BaseModel):
    scheduled_date: date


class UpdateProjectDeadlineRequest(BaseModel):
    deadline: date | None = None

    @field_validator("deadline", mode="before")
    @classmethod
    def empty_deadline_is_missing(cls, value):
        if value == "":
            return None
        return value


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


@router.post("/study-plan-adjustment/projects/{project_id}/deadline")
async def update_study_project_deadline(
    project_id: int,
    request: UpdateProjectDeadlineRequest,
) -> dict:
    if request.deadline is None:
        raise HTTPException(
            status_code=422,
            detail="v2 active plans require deadlines for late-state detection",
        )

    async with get_db() as db:
        try:
            return await update_active_study_project_deadline(db, project_id, request.deadline)
        except ResourceNotFoundError as exc:
            raise HTTPException(status_code=404, detail="project not found") from exc
        except ResourceDeadlineEditNotAllowedError as exc:
            raise HTTPException(status_code=409, detail="project deadline cannot be edited") from exc
