from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

from ..db.connection import get_db
from ..db.queries import get_system_state, upsert_system_state

router = APIRouter()

SMART_MODE_KEY = "study_smart_mode_enabled"


class SmartModeSettingsUpdate(BaseModel):
    enabled: bool


class SmartModeProposalRequest(BaseModel):
    trigger: Literal["morning", "after_adjustment"]


async def _is_smart_mode_enabled() -> bool:
    async with get_db() as db:
        raw = await get_system_state(db, SMART_MODE_KEY)
    return raw == "true"


@router.get("/study-smart-mode/settings")
async def get_study_smart_mode_settings() -> dict:
    return {"enabled": await _is_smart_mode_enabled()}


@router.put("/study-smart-mode/settings")
async def update_study_smart_mode_settings(request: SmartModeSettingsUpdate) -> dict:
    async with get_db() as db:
        await upsert_system_state(
            db,
            SMART_MODE_KEY,
            "true" if request.enabled else "false",
        )
    return {"enabled": request.enabled}


@router.post("/study-smart-mode/proposals")
async def generate_study_smart_mode_proposals(request: SmartModeProposalRequest) -> dict:
    enabled = await _is_smart_mode_enabled()
    return {
        "enabled": enabled,
        "trigger": request.trigger,
        "options": [],
    }
