"""HTTP surface for study intake routing and confirmation."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from ..db.connection import get_db
from ..study_plan.intake import confirm_intake_route, route_intake_submission

router = APIRouter()


class RouteIntakeRequest(BaseModel):
    client_request_id: str = Field(alias="clientRequestId", min_length=1)
    raw_input: str = Field(alias="rawInput", min_length=1)
    source_type: str = Field(alias="sourceType", min_length=1)
    user_hint: str | None = Field(default=None, alias="userHint")
    existing_plan_id: int | None = Field(default=None, alias="existingPlanId")


class ConfirmIntakeRequest(BaseModel):
    intake_item_id: int = Field(alias="intakeItemId", gt=0)
    confirmed_role: str = Field(alias="confirmedRole", min_length=1)
    title: str = Field(min_length=1)
    url: str | None = None
    existing_plan_id: int | None = Field(default=None, alias="existingPlanId")
    attachment_mode: str | None = Field(default=None, alias="attachmentMode")
    canonical_repo_role: str | None = Field(default=None, alias="canonicalRepoRole")
    metadata: dict[str, Any] | None = None


@router.post("/study-intake/route")
async def route_intake(body: RouteIntakeRequest) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await route_intake_submission(
                db,
                client_request_id=body.client_request_id,
                raw_input=body.raw_input,
                source_type=body.source_type,
                user_hint=body.user_hint,
                existing_plan_id=body.existing_plan_id,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))


@router.post("/study-intake/confirm")
async def confirm_intake(body: ConfirmIntakeRequest) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await confirm_intake_route(
                db,
                intake_item_id=body.intake_item_id,
                confirmed_role=body.confirmed_role,
                title=body.title,
                url=body.url,
                existing_plan_id=body.existing_plan_id,
                attachment_mode=body.attachment_mode,
                canonical_repo_role=body.canonical_repo_role,
                metadata=body.metadata,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
