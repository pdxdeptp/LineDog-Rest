# ITEM-004 TDD Report: Backend Smart Snapshot And Morning Briefing

## Scope

- Change: `introduce-study-smart-mode`
- OpenSpec tasks: 3.1, 3.2, 3.3, 3.4
- Worker: backend smart snapshot and morning briefing implementation
- Review time: 2026-05-24T14:52:01Z

## RED

- Initial command: `uv run pytest tests/test_study_smart_mode_briefing.py -q`
- Expected failure: the new smart briefing route did not exist yet and returned 404.
- Review-fix command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_briefing.py -q`
- Expected failures:
  - `trigger_eligible` was missing from the briefing payload.
  - single-task summary used `tasks` instead of `task`.
  - disabled empty briefing reused a shared nested snapshot object.

## GREEN

- Added `GET /api/study-smart-mode/morning-briefing`.
- Built the briefing snapshot from existing v2 facts:
  - `rollover_unfinished_study_tasks`
  - `get_today_study_view_tasks`
  - `get_study_project_overview`
  - `get_study_calendar_load`
- Added deterministic issue extraction for rolled-task lag, expected-late projects, and over-capacity days.
- Added deterministic summary text and `trigger_eligible` while keeping `options` empty for the later proposal-generation slice.
- Added a fresh empty snapshot for disabled mode.
- Hardened tests so smart-mode routes do not depend on the v1 `run_morning_agent` flow or `/api/today-briefing`.

## REFACTOR / Verification

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_briefing.py -q`
- Result: 5 passed, 2 existing third-party dependency warnings.
- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_study_smart_mode_briefing.py -q`
- Result: 9 passed, 2 existing third-party dependency warnings.
- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_study_smart_mode_briefing.py tests/test_study_plan_adjustment_rollover.py tests/test_study_views_today.py tests/test_study_views_calendar.py -q`
- Result: 18 passed, 2 existing third-party dependency warnings.
- Command: `openspec validate introduce-study-smart-mode --strict`
- Result: PASS.
- Command: `git diff --check`
- Result: PASS.

## Review Gates

- Spec Compliance Review: initially BLOCKED because issue detection had no matching task status and v1 isolation tests were too narrow.
- Review fix: completed tasks 3.3 and 3.4 in this same backend briefing slice, added quiet no-issue coverage, `trigger_eligible`, and a source-level v1 dependency guard.
- Spec Compliance Re-review: PASS.
- Code Quality Review: initially BLOCKED because the test data depended on default Saturday rest-day behavior and disabled empty briefing reused a shared nested dict.
- Review fix: set `study_rest_weekdays=[]` in briefing tests and return fresh empty snapshots.
- Code Quality Re-review: PASS.

## Files Changed

- `assistant_backend/src/routers/study_smart_mode.py`
- `assistant_backend/tests/test_study_smart_mode_briefing.py`
- `openspec/changes/introduce-study-smart-mode/tasks.md`

## Remaining Risk

- The route intentionally returns empty `options`; proposal generation begins in tasks 4.1-4.2.
- The route runs already-defined v2 rollover as part of fact refresh, matching existing Today view semantics.
- Later proposal/apply work should introduce typed response models before the payload grows further.
