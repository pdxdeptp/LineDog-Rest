from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import TaskNotFoundError, complete_task

router = APIRouter()


class CompleteTaskRequest(BaseModel):
    actual_minutes: int | None = None


@router.post("/tasks/{task_id}/complete")
async def mark_task_complete(task_id: int, body: CompleteTaskRequest = CompleteTaskRequest()):
    async with get_db() as db:
        try:
            result = await complete_task(db, task_id, body.actual_minutes)
        except TaskNotFoundError as exc:
            raise HTTPException(status_code=404, detail="Task not found") from exc
    return result
