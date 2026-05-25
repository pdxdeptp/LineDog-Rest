"""Study intake data/idempotency tests."""

from datetime import date

import pytest


class _GitHubResponse:
    def __init__(self, status_code: int, payload: dict):
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict:
        return self._payload


class _GitHubClient:
    def __init__(self, responses: dict[str, _GitHubResponse]):
        self.responses = responses
        self.requested_urls: list[str] = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def get(self, url: str, **kwargs):
        self.requested_urls.append(url)
        for marker, response in self.responses.items():
            if marker in url:
                return response
        return _GitHubResponse(404, {})


async def _fetchall(db, sql: str, params: tuple = ()) -> list[dict]:
    async with db.execute(sql, params) as cursor:
        rows = await cursor.fetchall()
        return [dict(row) for row in rows]


@pytest.mark.asyncio
async def test_idempotency_reuses_intake_item_and_non_plan_resource(db):
    from src.study_plan.intake import (
        confirm_non_plan_resource,
        create_intake_item,
    )

    first = await create_intake_item(
        db,
        client_request_id="req-reference-1",
        raw_input="Save the SQLite query planner docs as a reference.",
        source_type="text_goal",
        recommended_role="reference_material",
        confidence="high",
        reason_codes=["explicit_reference"],
    )
    second = await create_intake_item(
        db,
        client_request_id="req-reference-1",
        raw_input="Retried body should not replace the original.",
        source_type="pasted_note",
        recommended_role="later_resource",
        confidence="low",
        reason_codes=["retry"],
    )

    assert second == first

    first_resource = await confirm_non_plan_resource(
        db,
        intake_item_id=first["id"],
        role="reference_material",
        title="SQLite query planner",
        url="https://sqlite.org/queryplanner.html",
    )
    second_resource = await confirm_non_plan_resource(
        db,
        intake_item_id=first["id"],
        role="reference_material",
        title="Duplicate retry",
        url="https://example.com/duplicate",
    )

    assert second_resource == first_resource
    assert await _fetchall(db, "SELECT id FROM study_intake_items") == [{"id": first["id"]}]
    assert await _fetchall(db, "SELECT id FROM study_intake_non_plan_items") == [
        {"id": first_resource["id"]}
    ]


@pytest.mark.asyncio
async def test_non_plan_and_material_only_outcomes_are_excluded_from_today(db):
    from src.db.queries import get_today_study_view_tasks
    from src.study_plan.intake import (
        attach_material_to_plan,
        confirm_non_plan_resource,
        create_intake_item,
    )

    project_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    project_id = int(project_cursor.lastrowid)

    reference = await create_intake_item(
        db,
        client_request_id="req-reference-2",
        raw_input="Reference article for later study.",
        source_type="url",
        recommended_role="reference_material",
        confidence="medium",
    )
    later = await create_intake_item(
        db,
        client_request_id="req-later-1",
        raw_input="https://github.com/example/later-reading",
        source_type="github_repo",
        recommended_role="later_resource",
        confidence="medium",
    )
    material = await create_intake_item(
        db,
        client_request_id="req-material-1",
        raw_input="Paste these notes into the active project context.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    await confirm_non_plan_resource(
        db,
        intake_item_id=reference["id"],
        role="reference_material",
        title="Reference article",
    )
    await confirm_non_plan_resource(
        db,
        intake_item_id=later["id"],
        role="later_resource",
        title="Later GitHub repo",
        url="https://github.com/example/later-reading",
    )
    await attach_material_to_plan(
        db,
        intake_item_id=material["id"],
        target_plan_id=project_id,
        attachment_mode="material_only",
        title="Supporting notes",
    )

    assert await get_today_study_view_tasks(db, date.today()) == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_today_exclusion_for_immediate_one_off_until_explicit_action(db):
    from src.db.queries import get_today_study_view_tasks
    from src.study_plan.intake import create_intake_item

    item = await create_intake_item(
        db,
        client_request_id="req-one-off-1",
        raw_input="Email myself the repo link today.",
        source_type="text_goal",
        recommended_role="immediate_one_off",
        confidence="medium",
        next_action="explicit_user_action",
    )

    assert item["recommended_role"] == "immediate_one_off"
    assert item["next_action"] == "explicit_user_action"
    assert await get_today_study_view_tasks(db, date.today()) == []
    assert await _fetchall(db, "SELECT id FROM tasks") == []


@pytest.mark.asyncio
async def test_confirm_non_plan_resource_preserves_pending_when_child_insert_fails(db):
    from src.study_plan.intake import (
        confirm_non_plan_resource,
        create_intake_item,
    )

    item = await create_intake_item(
        db,
        client_request_id="req-reference-invalid-title",
        raw_input="Save this item, but the confirmation payload is malformed.",
        source_type="text_goal",
        recommended_role="reference_material",
        confidence="high",
    )

    with pytest.raises(Exception):
        await confirm_non_plan_resource(
            db,
            intake_item_id=item["id"],
            role="reference_material",
            title=None,
        )

    assert await _fetchall(
        db,
        "SELECT confirmation_state FROM study_intake_items WHERE id = ?",
        (item["id"],),
    ) == [{"confirmation_state": "pending"}]
    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_non_plan_items WHERE intake_item_id = ?",
        (item["id"],),
    ) == []


@pytest.mark.asyncio
async def test_attach_material_to_plan_preserves_pending_when_child_insert_fails(db):
    from src.study_plan.intake import (
        attach_material_to_plan,
        create_intake_item,
    )

    project_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    project_id = int(project_cursor.lastrowid)
    await db.commit()

    item = await create_intake_item(
        db,
        client_request_id="req-material-invalid-title",
        raw_input="Attach this material, but the confirmation payload is malformed.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    with pytest.raises(Exception):
        await attach_material_to_plan(
            db,
            intake_item_id=item["id"],
            target_plan_id=project_id,
            attachment_mode="material_only",
            title=None,
        )

    assert await _fetchall(
        db,
        "SELECT confirmation_state FROM study_intake_items WHERE id = ?",
        (item["id"],),
    ) == [{"confirmation_state": "pending"}]
    assert await _fetchall(
        db,
        "SELECT id FROM study_intake_plan_attachments WHERE intake_item_id = ?",
        (item["id"],),
    ) == []


@pytest.mark.asyncio
async def test_empty_metadata_round_trips_for_intake_children(db):
    from src.study_plan.intake import (
        attach_material_to_plan,
        confirm_non_plan_resource,
        create_intake_item,
    )

    project_cursor = await db.execute(
        """
        INSERT INTO resources (title, type, tracking_mode, status, total_units)
        VALUES ('Existing Study Project', 'study_project', 'sequential', 'active', 1)
        """
    )
    project_id = int(project_cursor.lastrowid)
    await db.commit()

    reference = await create_intake_item(
        db,
        client_request_id="req-reference-empty-metadata",
        raw_input="Save this reference with empty metadata.",
        source_type="text_goal",
        recommended_role="reference_material",
        confidence="high",
    )
    material = await create_intake_item(
        db,
        client_request_id="req-material-empty-metadata",
        raw_input="Attach this material with empty metadata.",
        source_type="pasted_note",
        recommended_role="attach_to_existing_plan",
        confidence="high",
    )

    resource = await confirm_non_plan_resource(
        db,
        intake_item_id=reference["id"],
        role="reference_material",
        title="Reference with empty metadata",
        metadata={},
    )
    attachment = await attach_material_to_plan(
        db,
        intake_item_id=material["id"],
        target_plan_id=project_id,
        attachment_mode="material_only",
        title="Attachment with empty metadata",
        metadata={},
    )

    assert resource["metadata"] == {}
    assert attachment["metadata"] == {}


@pytest.mark.asyncio
async def test_github_preview_returns_shallow_metadata_without_active_structure(monkeypatch):
    import base64

    from src.study_plan.intake_preview import preview_github_repo

    readme = """# Build a Tiny Compiler

## Overview
Intro material.

## Parser
Parsing notes.

## Code Generation
Backend notes.
"""
    fake_client = _GitHubClient(
        {
            "/repos/acme/compiler-course/readme": _GitHubResponse(
                200,
                {
                    "encoding": "base64",
                    "content": base64.b64encode(readme.encode()).decode(),
                },
            ),
            "/repos/acme/compiler-course/git/trees/HEAD": _GitHubResponse(
                200,
                {
                    "tree": [
                        {"path": "src", "type": "tree"},
                        {"path": "docs", "type": "tree"},
                        {"path": "lessons", "type": "tree"},
                        {"path": "lessons/01-parser", "type": "tree"},
                    ]
                },
            ),
            "/repos/acme/compiler-course": _GitHubResponse(
                200,
                {
                    "full_name": "acme/compiler-course",
                    "description": "Clone and rebuild a tiny compiler workshop",
                    "topics": ["compiler", "workshop"],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo(
        "https://github.com/acme/compiler-course",
        user_hint="I want to clone and rebuild this project",
    )

    assert preview.title == "acme/compiler-course"
    assert preview.description == "Clone and rebuild a tiny compiler workshop"
    assert preview.source_type == "github_repo"
    assert preview.url == "https://github.com/acme/compiler-course"
    assert preview.readme_outline == ["Overview", "Parser", "Code Generation"]
    assert preview.topics == ["compiler", "workshop"]
    assert preview.coarse_directory_signals == ["docs", "lessons", "src"]
    assert preview.fetch_status == "available"
    assert preview.calibration == "medium"
    assert preview.canonical_repo_role == "clone_rebuild_target"
    assert not hasattr(preview, "units")


@pytest.mark.asyncio
async def test_github_preview_fetch_failure_returns_low_calibration_unknowns(monkeypatch):
    from src.study_plan.intake_preview import preview_github_repo

    fake_client = _GitHubClient({})
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo("https://github.com/acme/missing-course")

    assert preview.title == "acme/missing-course"
    assert preview.description is None
    assert preview.readme_outline == []
    assert preview.topics == []
    assert preview.coarse_directory_signals == []
    assert preview.fetch_status == "unavailable"
    assert preview.calibration == "low"
    assert preview.canonical_repo_role is None
    assert not hasattr(preview, "units")


@pytest.mark.asyncio
async def test_github_preview_does_not_fabricate_structure_or_call_llm(monkeypatch):
    from src.study_plan.intake_preview import preview_github_repo

    async def fail_if_called(*args, **kwargs):
        raise AssertionError("preview must not use LLM fallback")

    fake_client = _GitHubClient(
        {
            "/repos/acme/name-only/readme": _GitHubResponse(404, {}),
            "/repos/acme/name-only/git/trees/HEAD": _GitHubResponse(200, {"tree": []}),
            "/repos/acme/name-only": _GitHubResponse(
                200,
                {
                    "full_name": "acme/name-only",
                    "description": None,
                    "topics": [],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )
    monkeypatch.setattr("src.handlers.github_handler._llm_fallback", fail_if_called)
    monkeypatch.setattr("src.handlers.github_handler._llm_parse_readme", fail_if_called)

    preview = await preview_github_repo("https://github.com/acme/name-only")

    assert preview.title == "acme/name-only"
    assert preview.readme_outline == []
    assert preview.coarse_directory_signals == []
    assert preview.calibration == "low"
    assert preview.canonical_repo_role is None
    assert not hasattr(preview, "units")


@pytest.mark.asyncio
async def test_legacy_github_fallback_marks_generated_unit_synthetic(monkeypatch):
    from src.handlers.github_handler import GitHubHandler

    fake_client = _GitHubClient({})
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    structure = await GitHubHandler("https://github.com/acme/name-only").fetch()

    assert len(structure.units) == 1
    assert structure.units[0].title == "name-only"
    assert structure.units[0].is_synthetic is True
    assert structure.units[0].calibration == "low"


@pytest.mark.asyncio
async def test_github_preview_user_hint_takes_precedence_over_metadata_and_readme(monkeypatch):
    import base64

    from src.study_plan.intake_preview import preview_github_repo

    readme = "## Tutorial\nLearn this workshop as a full course."
    fake_client = _GitHubClient(
        {
            "/repos/acme/mixed-signals/readme": _GitHubResponse(
                200,
                {
                    "encoding": "base64",
                    "content": base64.b64encode(readme.encode()).decode(),
                },
            ),
            "/repos/acme/mixed-signals/git/trees/HEAD": _GitHubResponse(200, {"tree": []}),
            "/repos/acme/mixed-signals": _GitHubResponse(
                200,
                {
                    "full_name": "acme/mixed-signals",
                    "description": "Documentation tutorial for learning later",
                    "topics": ["tutorial"],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo(
        "https://github.com/acme/mixed-signals",
        user_hint="Use this as material for my existing project",
    )

    assert preview.canonical_repo_role == "project_material"


@pytest.mark.asyncio
async def test_github_preview_marks_partial_when_only_some_sources_succeed(monkeypatch):
    import base64

    from src.study_plan.intake_preview import preview_github_repo

    readme = "## Notes\nReference material."
    fake_client = _GitHubClient(
        {
            "/repos/acme/partial/readme": _GitHubResponse(
                200,
                {
                    "encoding": "base64",
                    "content": base64.b64encode(readme.encode()).decode(),
                },
            ),
            "/repos/acme/partial/git/trees/HEAD": _GitHubResponse(404, {}),
            "/repos/acme/partial": _GitHubResponse(
                200,
                {
                    "full_name": "acme/partial",
                    "description": "Reference source",
                    "topics": [],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo("https://github.com/acme/partial")

    assert preview.fetch_status == "partial"
    assert preview.description == "Reference source"
    assert preview.readme_outline == ["Notes"]
    assert preview.coarse_directory_signals == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("user_hint", "expected_role"),
    [
        ("This is the main repo I want to learn", "main_learning_object"),
        ("Keep this as API documentation reference", "reference_source"),
        ("I want to clone and rebuild this app", "clone_rebuild_target"),
        ("Attach as material for my existing project", "project_material"),
        ("Bookmark this for later reading", "later_reading"),
    ],
)
async def test_github_preview_covers_all_canonical_repo_roles(
    monkeypatch,
    user_hint,
    expected_role,
):
    from src.study_plan.intake_preview import preview_github_repo

    fake_client = _GitHubClient(
        {
            "/repos/acme/role-case/readme": _GitHubResponse(404, {}),
            "/repos/acme/role-case/git/trees/HEAD": _GitHubResponse(404, {}),
            "/repos/acme/role-case": _GitHubResponse(
                200,
                {
                    "full_name": "acme/role-case",
                    "description": "Generic repository",
                    "topics": [],
                },
            ),
        }
    )
    monkeypatch.setattr(
        "src.handlers.github_handler.httpx.AsyncClient",
        lambda: fake_client,
    )

    preview = await preview_github_repo("https://github.com/acme/role-case", user_hint=user_hint)

    assert preview.canonical_repo_role == expected_role
