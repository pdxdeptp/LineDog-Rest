# ITEM-004 TDD Report: Backend Morning Proposal Options

## Scope

- Change: `introduce-study-smart-mode`
- OpenSpec tasks: 4.1, 4.2
- Worker: backend smart-mode morning proposal generation
- Review time: 2026-05-24T15:22:53Z

## RED

- Initial command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q`
- Expected failure: morning proposal options were still empty while tests expected structured previews for rolled-task lag, expected-late project, and over-capacity day facts.
- Review-fix command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q`
- Expected failures after code-quality review:
  - `POST /api/study-smart-mode/proposals` could still run rollover via the shared snapshot builder.
  - proposal signatures hashed display copy instead of canonical action payload.
  - the router imported a private capacity-preview helper.
  - over-capacity task selection did not expose a reviewable policy and candidate comparison.
- Final review-fix command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py::test_over_capacity_option_selects_latest_overloaded_task_and_names_cascade -q`
- Expected failure: old selection policy name and payload lacked candidate evaluations and selection reason.

## GREEN

- Implemented deterministic `morning` proposal previews for:
  - rolled-task lag;
  - expected-late project;
  - over-capacity day.
- Kept `after_adjustment` returning empty options for this slice.
- Kept disabled smart mode returning empty options.
- Added a read-only proposal snapshot path so proposal generation can project pending rollover facts without mutating `tasks` or `events`.
- Added canonical `signature_payload`, `signature_version`, and stable SHA-256 signatures.
- Promoted the capacity-impact helper to public `preview_over_capacity_impact`.
- Added an explicit over-capacity `selection_policy` with candidate evaluations and `selection_reason`.

## REFACTOR / Verification

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q`
- Result: 6 passed, 2 existing third-party dependency warnings.
- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_study_smart_mode_briefing.py tests/test_study_smart_mode_proposals.py tests/test_study_plan_adjustment_dialogue_preview.py tests/test_study_plan_adjustment_dialogue_apply.py -q`
- Result: 35 passed, 2 existing third-party dependency warnings.
- Command: `openspec validate introduce-study-smart-mode --strict`
- Result: PASS.
- Command: `git diff --check`
- Result: PASS.

## Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: initially BLOCKED because proposal generation was not purely read-only and because option signatures/over-capacity selection needed stronger reviewability.
- Review fixes:
  - separated read-only proposal snapshots from rollover-running briefing snapshots;
  - added non-mutation coverage for pending rollover facts;
  - canonicalized signatures;
  - removed private helper import;
  - made over-capacity selection policy explicit.
- Code Quality Re-review: PASS.

## Files Changed

- `assistant_backend/src/routers/study_smart_mode.py`
- `assistant_backend/src/db/queries.py`
- `assistant_backend/tests/test_study_smart_mode_proposals.py`
- `assistant_backend/tests/test_study_smart_mode_briefing.py`
- `openspec/changes/introduce-study-smart-mode/tasks.md`

## Remaining Risk

- This slice generates morning preview options only. After-adjustment proposals remain tasks 4.3-4.4.
- Applying, stale proposal rejection, smart-mode event recording, and mutation remain tasks 5.1-5.4.
- Future Swift/API work should introduce typed response models before using these payloads broadly.
