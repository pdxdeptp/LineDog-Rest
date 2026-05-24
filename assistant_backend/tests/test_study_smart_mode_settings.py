import os

import aiosqlite
import pytest


@pytest.mark.asyncio
async def test_get_study_smart_mode_settings_defaults_to_disabled(client):
    response = await client.get("/api/study-smart-mode/settings")

    assert response.status_code == 200
    assert response.json() == {"enabled": False}


@pytest.mark.asyncio
async def test_put_study_smart_mode_settings_persists_enabled_preference(client):
    put_response = await client.put(
        "/api/study-smart-mode/settings",
        json={"enabled": True},
    )

    assert put_response.status_code == 200
    assert put_response.json() == {"enabled": True}

    get_response = await client.get("/api/study-smart-mode/settings")
    assert get_response.status_code == 200
    assert get_response.json() == {"enabled": True}

    async with aiosqlite.connect(os.environ["DB_PATH"]) as db:
        async with db.execute(
            "SELECT value FROM system_state WHERE key = ?",
            ("study_smart_mode_enabled",),
        ) as cursor:
            row = await cursor.fetchone()
    assert row == ("true",)


@pytest.mark.asyncio
async def test_disabled_study_smart_mode_suppresses_proposal_options(client):
    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={"trigger": "morning"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "enabled": False,
        "trigger": "morning",
        "options": [],
    }


@pytest.mark.asyncio
async def test_study_smart_mode_proposals_rejects_invalid_trigger(client):
    response = await client.post(
        "/api/study-smart-mode/proposals",
        json={"trigger": "weekly_review"},
    )

    assert response.status_code == 422
