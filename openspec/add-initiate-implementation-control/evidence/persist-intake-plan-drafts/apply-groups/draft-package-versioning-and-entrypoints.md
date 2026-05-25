# Apply Group Evidence: draft-package-versioning-and-entrypoints

## Timestamp

2026-05-25T07:42:50Z

## Change

`persist-intake-plan-drafts`

## Checkpoint

`persist-intake-plan-drafts:apply:draft-package-versioning-and-entrypoints`

## Task Group

- Group id: `draft-package-versioning-and-entrypoints`
- Task ids: `1.3`, `1.4`, `1.5`, `1.6`, `1.8`, `1.9`, `4.2`, `4.3`, `4.11`

## Files Changed

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/study_plan/lifecycle.py`
- `assistant_backend/src/study_plan/intake.py`
- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `assistant_backend/tests/test_study_intake_router.py`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`

## Implementation Commit

- `dd01c193c6690dd70b47f85df332100fac825425`

## TDD Evidence

Initial RED:

- `tests/test_study_plan_lifecycle.py -k 'version or package or assumptions or target_plan or draft_kind'` failed because draft package/versioning helpers did not exist.
- `tests/test_study_intake_router.py -k 'handoff or scheduled_work or draft_phase'` failed because plan-generating handoff responses did not persist or return draft shells.

Review-fix RED:

- Stale latest-version test failed before `save_draft_compiler_package_shell()` reloaded draft header inside the transaction.
- Target-plan idempotency test failed before draft shell lookup included `target_plan_id`.
- Unknown-deadline handoff test failed while missing metadata deadline was treated as the current date.
- Invalid package status tests failed before status whitelist validation.
- Legacy latest-fetch test failed before legacy headers without version rows could synthesize recoverable packages.
- Legacy fetch transaction test failed while synthesized package writes left `db.in_transaction` true.
- Closed-draft write tests failed before package/edit entrypoints rejected `cancelled`, `confirmed`, `active_plan`, and `discarded` drafts.

Final GREEN:

- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'version or package or assumptions or target_plan or draft_kind'`: passed, 13 selected tests.
- `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'handoff or scheduled_work or draft_phase'`: passed, 8 selected tests.
- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py tests/test_study_intake_router.py`: passed, 83 tests, 2 third-party warnings.
- `cd assistant_backend && uv run pytest tests/test_study_plan_router.py -k 'start_endpoint or clarification_without_active_resources'`: passed, 1 selected test, 2 third-party warnings.
- `openspec validate persist-intake-plan-drafts --strict`: valid.
- `openspec instructions apply --change persist-intake-plan-drafts --json`: 16/35 tasks complete.
- `git diff --check` for the apply-group file set: passed.

## Implementation Summary

- Added `study_project_draft_versions` snapshot storage for V1 draft package shells.
- Added storage helpers for create/load draft shell, save compiler package shell, fetch latest/versioned package, create meaningful edit version, and update display-only metadata.
- Persisted assumptions and provenance as JSON package data, including deadline, capacity, target output, target depth, buffer policy, rest days, and source roles.
- Preserved package shells for `needs_input`, `compile_failed`, `infeasible_review`, and `draft_review` without requiring complete phases, tasks, schedule, or risk reports.
- Ensured meaningful edits create a new draft version while prior versions remain fetchable.
- Ensured display-only metadata updates do not create new draft versions.
- Persisted `draft_kind` and `target_plan_id` for `new_plan`, `existing_plan_phase`, and `existing_plan_scheduled_work` handoffs, with target-plan validation against active study projects.
- Preserved unknown deadline semantics by using a stable placeholder in the non-null header and marking the assumption as `unknown` / `needs_input` instead of fabricating today's date.
- Added status whitelist and closed-draft guards so package/edit helpers cannot reopen closed drafts.
- Added legacy latest-fetch recovery for draft headers without version rows, with unknown provenance and no lingering transaction.
- Clarified task `1.8` so this group owns package/versioning entrypoints while discard, activation, and fallback progress stay in later 2.* / 3.* groups.

## Reviews

Spec compliance review:

- First verdict: changes required.
- P1 findings: task `1.8` overclaimed discard/activation/fallback entrypoints; legacy headers without version rows could not be fetched by logical package helpers.
- Fixes: narrowed task `1.8`; added legacy package synthesis and tests.
- Final verdict: approved.

Code quality review:

- First verdict: changes required.
- P1 findings: stale latest-version read, target-plan idempotency mismatch, fabricated current-date deadline, missing status validation, and legacy latest-fetch failure.
- Re-review verdict: changes required.
- P1 findings: synthesized legacy fetch left an open transaction; package/edit helpers could reopen closed drafts.
- Fixes: moved draft header reload into transaction, included `target_plan_id` in shell reuse, added unknown deadline provenance, added package status whitelist, committed synthesized legacy package writes, and added closed-draft write guards.
- Final verdict: approved.

## Scope Notes

This group did not implement activation events, stale activation rejection, activation-ready schedule enforcement, fallback completion, scheduler placement, compiler generation, or UI behavior. Those remain in later apply groups and downstream changes.

## Result

Completed. The `draft-package-versioning-and-entrypoints` group is verified and can be marked complete.

## Next Checkpoint

`persist-intake-plan-drafts:apply:activation-boundary-and-events`
