# ITEM-004 TDD Report: Backend Smart Mode Setting

## Scope

- Change: `introduce-study-smart-mode`
- OpenSpec tasks: 2.1, 2.2
- Worker: backend smart-mode setting implementation
- Review time: 2026-05-24T14:32:16Z

## RED

- Command: `uv run pytest tests/test_study_smart_mode_settings.py`
- Expected failure: new tests failed with 404 before the smart-mode backend routes existed.
- Review-fix RED: after code quality review requested trigger validation, added invalid-trigger coverage.
- Command: `uv run pytest tests/test_study_smart_mode_settings.py`
- Expected failure: `weekly_review` trigger returned 200 before trigger validation, while the test expected 422.

## GREEN

- Added `assistant_backend/src/routers/study_smart_mode.py`.
- Registered `study_smart_mode.router` in `assistant_backend/src/main.py`.
- Implemented:
  - `GET /api/study-smart-mode/settings`
  - `PUT /api/study-smart-mode/settings`
  - minimal disabled no-op `POST /api/study-smart-mode/proposals`
- Stored the preference in `system_state.study_smart_mode_enabled`, defaulting to disabled when absent.
- Constrained proposal trigger input to `morning` or `after_adjustment`.
- Command: `uv run pytest tests/test_study_smart_mode_settings.py`
- Result: 4 passed, 2 existing third-party dependency warnings.

## REFACTOR / Verification

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_integration.py -q`
- Result: 20 passed, 2 existing third-party dependency warnings.
- Command: `openspec validate introduce-study-smart-mode --strict`
- Result: PASS.
- Command: `git diff --check`
- Result: PASS.

## Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: initially CHANGES_REQUESTED for accepting arbitrary proposal trigger strings.
- Review fix: added invalid-trigger 422 test and changed trigger type to `Literal["morning", "after_adjustment"]`.
- Code Quality Re-review: APPROVED.

## Files Changed

- `assistant_backend/tests/test_study_smart_mode_settings.py`
- `assistant_backend/src/routers/study_smart_mode.py`
- `assistant_backend/src/main.py`
- `openspec/changes/introduce-study-smart-mode/tasks.md`

## Remaining Risk

- The `/api/study-smart-mode/proposals` route intentionally returns empty options for this slice. Fact snapshot, briefing, proposal generation, and proposal apply remain future tasks in the same OpenSpec change.
