# Apply Group Evidence: draft-schema-migration-and-defaults

## Timestamp

2026-05-25T06:56:39Z

## Change

`persist-intake-plan-drafts`

## Checkpoint

`persist-intake-plan-drafts:apply:draft-schema-migration-and-defaults`

## Task Group

- Group id: `draft-schema-migration-and-defaults`
- Task ids: `1.1`, `1.2`, `1.7`, `3.4`, `4.1`, `4.8`, `4.10`

## Files Changed

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/db/init.py`
- `assistant_backend/src/study_plan/lifecycle.py`
- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `assistant_backend/tests/test_study_plan_router.py`
- `assistant_backend/tests/test_integration.py`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`

## Implementation Commit

- `d521f5440a84274e3ef90dfa4e0e38b708be2e9f`

## TDD Evidence

Initial RED:

- `test_create_draft_study_project_links_intake_item_idempotently_without_active_tasks` failed because `create_draft_study_project()` did not accept or persist `intake_item_id`.
- `test_init_db_migrates_legacy_draft_storage_idempotently_without_touching_active_rows` failed because legacy draft tables lacked the new draft header/task contract fields.
- The router start endpoint regression failed because the persisted draft header did not expose the default draft contract columns.
- The capacity-default regression failed because `reduced_capacity_min` with legacy value `300` was not migrated to `60`.

Final GREEN:

- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'draft or migration or active_daily_tasks'`: passed, 7 tests.
- `cd assistant_backend && uv run pytest tests/test_integration.py -k 'daily_capacity_min'`: passed, 1 selected test.
- `cd assistant_backend && uv run pytest tests/test_study_plan_router.py -k 'start_endpoint or clarification_without_active_resources'`: passed, 1 selected test, 2 third-party warnings.
- `openspec validate persist-intake-plan-drafts --strict`: valid.
- `git diff --check -- assistant_backend/src/db/schema.py assistant_backend/src/db/init.py assistant_backend/src/study_plan/lifecycle.py assistant_backend/tests/test_study_plan_lifecycle.py assistant_backend/tests/test_study_plan_router.py assistant_backend/tests/test_integration.py`: passed.

## Implementation Summary

- Extended `study_project_drafts` with intake linkage, schema/draft/latest version fields, calibration level, draft kind, target plan id, and `updated_at`.
- Extended `study_project_draft_tasks` with stable task id, phase id, draft task status, metadata, and schedule slices.
- Added idempotent startup migration that upgrades legacy draft tables without dropping existing draft rows or changing active resources/units/tasks.
- Added an intake-linked draft shell path that reuses the existing reviewable draft for the same `intake_item_id + draft_kind` instead of duplicating draft headers or draft tasks.
- Preserved draft/active separation: creating or reloading a draft does not create active resources or active tasks.
- Normalized both `daily_capacity_min` and `reduced_capacity_min` from legacy `300` to `60`.

## Reviews

Spec compliance review:

- Verdict: approved for this apply group.
- Covered requirements: draft state separate from active state, intake-linked draft headers, legacy migration/idempotency, 60-minute capacity defaults, and draft/active test coverage.
- Deferred by design: package shell persistence, meaningful version edits, activation events, target-plan activation behavior, and fallback progress remain in later apply groups.

Code quality review:

- Verdict: approved.
- Migration is re-runnable and additive, using `ALTER TABLE ... ADD COLUMN` only for missing columns.
- Current idempotency behavior is deliberately limited to intake-linked draft shells and does not change legacy `/api/study-plan/start` behavior.
- No broad staging, no runtime artifacts, and no unrelated dirty files were touched.

## Scope Notes

This group establishes the physical persistence baseline needed by later draft package and activation groups. It does not implement the compiler, scheduler, UI, full draft package schema, or activation readiness enforcement.

## Result

Completed. The `draft-schema-migration-and-defaults` group is verified and can be marked complete.

## Next Checkpoint

`persist-intake-plan-drafts:apply:draft-package-versioning-and-entrypoints`
