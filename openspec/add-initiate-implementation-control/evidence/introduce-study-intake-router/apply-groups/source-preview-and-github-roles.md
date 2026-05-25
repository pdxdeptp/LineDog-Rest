# Apply Group Evidence: source-preview-and-github-roles

- Automation: add-initiate-changes
- Change: introduce-study-intake-router
- Checkpoint: introduce-study-intake-router:apply:source-preview-and-github-roles
- Completed at: 2026-05-25T05:03:10Z
- Functional commit: 4bff7cf5847dd9de6d6965dc9612e04f5831b410

## Scope

Completed tasks:

- 2.1 Refactor material preview so Add / Initiate preview does not write active resources, units, or tasks.
- 2.2 Add shallow GitHub preview with title, description, README outline, topics, coarse directory signals, and fetch-failure fallback.
- 2.3 Add canonical repo role signals: `main_learning_object`, `reference_source`, `clone_rebuild_target`, `project_material`, and `later_reading`.
- 2.4 Ensure unavailable repo/source facts remain unknown and do not become fabricated units.
- 4.4 Add GitHub preview tests for successful metadata, fetch failure, and no fabricated structure.

## TDD Evidence

Initial RED worker result:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'github or preview or fabricated'`
- Expected failure: 3 new tests failed because `src.study_plan.intake_preview` did not exist.

First GREEN worker result:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'github or preview or fabricated'`
- Result: 3 passed, 6 deselected.

Review-driven RED result:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'github or preview or fabricated or role or synthetic or partial'`
- Expected failure: 3 failures for missing synthetic/low-calibration unit marking, user hint being overridden by metadata/readme, and partial fetch status being reported as available.

Review-driven GREEN results:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'github or preview or fabricated or role or synthetic or partial'`
- Result: 11 passed, 6 deselected.
- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`
- Result: 17 passed.

## Implementation Summary

- Added `GitHubPreview` and preview metadata literals while preserving existing `ResourceStructure` compatibility.
- Added `preview_github_repo()` as the Add / Initiate-safe GitHub preview entry point.
- Added `GitHubHandler.preview()` for shallow metadata, README outline, topics, coarse directory signals, fetch status, calibration, and canonical repo role signal.
- Kept preview separate from legacy `fetch()` and from LLM parsing/fallback paths.
- Marked legacy fallback-generated GitHub units as `is_synthetic=True` and `calibration="low"`.
- Ensured preview returns unknown/empty fields when facts are unavailable instead of fabricating units from repository names.

## Review

Spec compliance review:

- Initial result: CHANGES_REQUIRED.
- Issues: legacy fallback units lacked synthetic/low-calibration marking; user hint role precedence was unreliable; canonical role tests did not cover all five roles.
- Final result after fixes: APPROVED.

Code quality review:

- Initial result: CHANGES_REQUIRED.
- Issues: `fetch_status` did not distinguish partial results; no-LLM test did not protect `_llm_parse_readme`; role inference was too eager.
- Final result after fixes: APPROVED.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`: 17 passed.
- `cd assistant_backend && uv run pytest tests/test_study_plan_router.py tests/test_study_views_today.py`: 12 passed, 2 warnings.
- `cd assistant_backend && uv run pytest tests/test_integration.py -q`: 16 passed, 2 warnings.
- `openspec validate introduce-study-intake-router --strict`: valid.
- `openspec instructions apply --change introduce-study-intake-router --json`: 11/21 tasks complete.

## Protected Unrelated Dirty Paths

The following paths were present before this checkpoint or outside this checkpoint scope and were not edited or staged:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Next Checkpoint

introduce-study-intake-router:apply:routing-contracts-and-confirmation
