from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import (
    ResourceNotActiveError,
    ResourceNotFoundError,
    archive_active_resource,
    mark_active_resource_complete,
)

router = APIRouter()


class ResourceManagementRequest(BaseModel):
    source: str = "user_action"


def _source_from_request(body: ResourceManagementRequest | None) -> str:
    if body is None:
        return "user_action"
    source = body.source.strip()
    return source or "user_action"


@router.post("/resources/{resource_id}/complete")
async def mark_resource_complete(
    resource_id: int,
    body: ResourceManagementRequest | None = None,
) -> dict:
    async with get_db() as db:
        try:
            return await mark_active_resource_complete(db, resource_id, _source_from_request(body))
        except ResourceNotFoundError:
            raise HTTPException(status_code=404, detail="Resource not found")
        except ResourceNotActiveError:
            raise HTTPException(status_code=409, detail="Resource is not active")


@router.post("/resources/{resource_id}/archive")
async def archive_resource(
    resource_id: int,
    body: ResourceManagementRequest | None = None,
) -> dict:
    async with get_db() as db:
        try:
            return await archive_active_resource(db, resource_id, _source_from_request(body))
        except ResourceNotFoundError:
            raise HTTPException(status_code=404, detail="Resource not found")
        except ResourceNotActiveError:
            raise HTTPException(status_code=409, detail="Resource is not active")
