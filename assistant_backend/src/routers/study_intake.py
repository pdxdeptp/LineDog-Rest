"""HTTP surface for study intake routing and confirmation."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from ..db.connection import get_db
from ..study_plan.add_initiate import (
    activate_add_initiate_draft,
    apply_add_initiate_option_effect,
    confirm_add_initiate_anchors,
    confirm_add_initiate_role,
    start_add_initiate_session,
)
from ..study_plan.intake import confirm_intake_route, route_intake_submission

router = APIRouter()


def _add_initiate_error_status(exc: ValueError) -> int:
    text = str(exc).lower()
    if "session mismatch" in text or "stale draft" in text:
        return 409
    return 400


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


class AddInitiateStartSessionRequest(BaseModel):
    client_request_id: str = Field(alias="clientRequestId", min_length=1)
    raw_input: str = Field(alias="rawInput", min_length=1)
    source_type: str = Field(alias="sourceType", min_length=1)
    user_hint: str | None = Field(default=None, alias="userHint")
    existing_plan_id: int | None = Field(default=None, alias="existingPlanId")


class AddInitiateRoleConfirmationRequest(BaseModel):
    session_id: str = Field(alias="sessionId", min_length=1)
    intake_item_id: int = Field(alias="intakeItemId", gt=0)
    confirmed_role: str = Field(alias="confirmedRole", min_length=1)
    title: str = Field(min_length=1)
    url: str | None = None
    existing_plan_id: int | None = Field(default=None, alias="existingPlanId")
    attachment_mode: str | None = Field(default=None, alias="attachmentMode")
    canonical_repo_role: str | None = Field(default=None, alias="canonicalRepoRole")
    metadata: dict[str, Any] | None = None


class AddInitiateAnchorConfirmationRequest(BaseModel):
    session_id: str = Field(alias="sessionId", min_length=1)
    draft_id: int = Field(alias="draftId", gt=0)
    intake_item_id: int | None = Field(default=None, alias="intakeItemId", gt=0)
    deadline: str = Field(min_length=1)
    deadline_type: str = Field(alias="deadlineType", min_length=1)
    capacity_minutes: int = Field(alias="capacityMinutes", gt=0)
    target_output: str = Field(alias="targetOutput", min_length=1)
    target_depth: str = Field(alias="targetDepth", min_length=1)
    assumptions: dict[str, Any] | None = None
    rest_weekdays: list[int] | None = Field(default=None, alias="restWeekdays")
    unavailable_dates: list[str] | None = Field(default=None, alias="unavailableDates")
    buffer_policy: str | None = Field(default=None, alias="bufferPolicy")
    load_shape: str | None = Field(default=None, alias="loadShape")


class AddInitiateOptionEffectRequest(BaseModel):
    session_id: str = Field(alias="sessionId", min_length=1)
    draft_id: int = Field(alias="draftId", gt=0)
    draft_version: int = Field(alias="draftVersion", gt=0)
    option_id: str = Field(alias="optionId", min_length=1)
    parameters: dict[str, Any] | None = None


class AddInitiateActivationRequest(BaseModel):
    session_id: str = Field(alias="sessionId", min_length=1)
    draft_id: int = Field(alias="draftId", gt=0)
    draft_version: int = Field(alias="draftVersion", gt=0)


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


@router.post("/study-intake/add-initiate/sessions")
async def start_add_initiate(body: AddInitiateStartSessionRequest) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await start_add_initiate_session(
                db,
                client_request_id=body.client_request_id,
                raw_input=body.raw_input,
                source_type=body.source_type,
                user_hint=body.user_hint,
                existing_plan_id=body.existing_plan_id,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/study-intake/add-initiate/role")
async def confirm_add_initiate_role_endpoint(
    body: AddInitiateRoleConfirmationRequest,
) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await confirm_add_initiate_role(
                db,
                session_id=body.session_id,
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
            raise HTTPException(
                status_code=_add_initiate_error_status(exc),
                detail=str(exc),
            ) from exc


@router.post("/study-intake/add-initiate/anchors")
async def confirm_add_initiate_anchors_endpoint(
    body: AddInitiateAnchorConfirmationRequest,
) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await confirm_add_initiate_anchors(
                db,
                session_id=body.session_id,
                draft_id=body.draft_id,
                intake_item_id=body.intake_item_id,
                deadline=body.deadline,
                deadline_type=body.deadline_type,
                capacity_minutes=body.capacity_minutes,
                target_output=body.target_output,
                target_depth=body.target_depth,
                assumptions=body.assumptions,
                rest_weekdays=body.rest_weekdays,
                unavailable_dates=body.unavailable_dates,
                buffer_policy=body.buffer_policy,
                load_shape=body.load_shape,
            )
        except ValueError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.post("/study-intake/add-initiate/options")
async def apply_add_initiate_option_endpoint(
    body: AddInitiateOptionEffectRequest,
) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await apply_add_initiate_option_effect(
                db,
                session_id=body.session_id,
                draft_id=body.draft_id,
                draft_version=body.draft_version,
                option_id=body.option_id,
                parameters=body.parameters,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=_add_initiate_error_status(exc),
                detail=str(exc),
            ) from exc


@router.post("/study-intake/add-initiate/activate")
async def activate_add_initiate_endpoint(
    body: AddInitiateActivationRequest,
) -> dict[str, Any]:
    async with get_db() as db:
        try:
            return await activate_add_initiate_draft(
                db,
                session_id=body.session_id,
                draft_id=body.draft_id,
                draft_version=body.draft_version,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=_add_initiate_error_status(exc),
                detail=str(exc),
            ) from exc


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
