import re
from datetime import date

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, field_validator

from ..db.connection import get_db
from ..db.queries import (
    ResourceDeadlineEditNotAllowedError,
    ResourceNotFoundError,
    ResourceTaskInsertNotAllowedError,
    TaskDeleteNotAllowedError,
    TaskMoveNotAllowedError,
    TaskMovePastDateError,
    TaskNotFoundError,
    delete_active_study_task,
    get_study_rest_day_settings,
    insert_active_study_project_task,
    move_active_study_task,
    preview_active_study_project_shift,
    rollover_unfinished_study_tasks,
    update_study_rest_day_settings,
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


class InsertProjectTaskRequest(BaseModel):
    title: str
    target_minutes: int = Field(gt=0)
    scheduled_date: date

    @field_validator("title")
    @classmethod
    def title_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("title cannot be blank")
        return value.strip()


class RestDaySettingsRequest(BaseModel):
    weekly_weekdays: list[int] = Field(default_factory=list)
    one_off_dates: list[date] = Field(default_factory=list)

    @field_validator("weekly_weekdays")
    @classmethod
    def weekdays_must_be_python_weekday_values(cls, value: list[int]) -> list[int]:
        invalid = [weekday for weekday in value if weekday < 0 or weekday > 6]
        if invalid:
            raise ValueError("weekly_weekdays must contain values from 0 to 6")
        return value


class DialoguePreviewRequest(BaseModel):
    instruction: str = Field(min_length=1, max_length=240)
    project_id: int | None = None

    @field_validator("instruction")
    @classmethod
    def instruction_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("instruction cannot be blank")
        return value.strip()


_NUMBER_WORDS = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "a": 1,
    "an": 1,
}


_PROJECT_SHIFT_PATTERN = re.compile(
    r"^\s*(?:push|delay)\s+(?:(?:this\s+project)|(?:project\s+(?P<project_id>\d+)))\s+"
    r"by\s+(?P<amount>\d+|one|two|three|four|five|six|seven|eight|nine|ten|a|an)\s+"
    r"(?P<unit>days?|weeks?)\s*[.!?]?\s*$",
    re.IGNORECASE,
)


def _parse_project_shift_instruction(
    instruction: str,
    request_project_id: int | None,
) -> tuple[int, int] | None:
    match = _PROJECT_SHIFT_PATTERN.fullmatch(instruction)
    if not match:
        return None

    parsed_project_id = match.group("project_id")
    project_id = int(parsed_project_id) if parsed_project_id is not None else request_project_id
    if project_id is None:
        return None
    if request_project_id is not None and parsed_project_id is not None and request_project_id != project_id:
        return None

    amount_text = match.group("amount").lower()
    amount = int(amount_text) if amount_text.isdigit() else _NUMBER_WORDS[amount_text]
    unit = match.group("unit").lower()
    delta_days = amount * (7 if unit.startswith("week") else 1)
    if delta_days < 1 or delta_days > 365:
        return None
    return project_id, delta_days


@router.post("/study-plan-adjustment/rollover")
async def rollover_study_tasks() -> dict:
    async with get_db() as db:
        return await rollover_unfinished_study_tasks(db, date.today())


@router.get("/study-plan-adjustment/rest-days")
async def get_rest_day_settings() -> dict:
    async with get_db() as db:
        return await get_study_rest_day_settings(db)


@router.put("/study-plan-adjustment/rest-days")
async def update_rest_day_settings(request: RestDaySettingsRequest) -> dict:
    async with get_db() as db:
        return await update_study_rest_day_settings(
            db,
            request.weekly_weekdays,
            request.one_off_dates,
        )


@router.post("/study-plan-adjustment/dialogue/preview")
async def preview_dialogue_adjustment(request: DialoguePreviewRequest) -> dict:
    parsed = _parse_project_shift_instruction(request.instruction, request.project_id)
    if parsed is None:
        return {
            "status": "unsupported",
            "mutates": False,
            "message": "unsupported or ambiguous dialogue adjustment",
        }

    project_id, delta_days = parsed
    async with get_db() as db:
        return await preview_active_study_project_shift(db, project_id, delta_days)


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


@router.post("/study-plan-adjustment/projects/{project_id}/tasks")
async def insert_study_project_task(project_id: int, request: InsertProjectTaskRequest) -> dict:
    async with get_db() as db:
        try:
            return await insert_active_study_project_task(
                db,
                project_id,
                request.title,
                request.target_minutes,
                request.scheduled_date,
            )
        except ResourceNotFoundError as exc:
            raise HTTPException(status_code=404, detail="project not found") from exc
        except ResourceTaskInsertNotAllowedError as exc:
            raise HTTPException(status_code=409, detail="project task cannot be inserted") from exc


@router.delete("/study-plan-adjustment/tasks/{task_id}")
async def delete_study_task(task_id: int) -> dict:
    async with get_db() as db:
        try:
            return await delete_active_study_task(db, task_id)
        except TaskNotFoundError as exc:
            raise HTTPException(status_code=404, detail="task not found") from exc
        except TaskDeleteNotAllowedError as exc:
            raise HTTPException(status_code=409, detail="task cannot be deleted") from exc
