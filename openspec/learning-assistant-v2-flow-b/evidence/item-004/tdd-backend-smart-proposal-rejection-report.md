# ITEM-004 5.3-5.4 TDD Report: Backend Smart Proposal Rejection

## Scope

- Change: `introduce-study-smart-mode`
- Tasks: 5.3 and 5.4
- Files:
  - `assistant_backend/tests/test_study_smart_mode_proposals.py`
  - `assistant_backend/src/routers/study_smart_mode.py`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q`
- Result: `1 failed, 22 passed`
- Expected failure: a signed unsupported command returned `stale_proposal`; the new test expected `unsupported` and no mutation.

## GREEN / REFACTOR

- Implemented explicit supported apply command validation before current option recomputation.
- Covered rejection paths for:
  - stale proposal after current facts drift;
  - disabled smart-mode apply;
  - signed unsupported command;
  - missing or unrecognized selected proposal;
  - tampered preview or `signature_payload`.
- Confirmed no mutation by snapshotting `tasks`, `resources`, and `events` across rejected apply requests.
- Marked OpenSpec tasks 5.3 and 5.4 complete.

## Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: APPROVED.
- Review notes:
  - Supported apply commands cover current production apply commands.
  - Unsupported command rejection happens before recompute, while valid requests still require later fresh signature and payload matching.
  - Rejection paths rollback and return no-op responses.
  - No v1 Morning Agent, `/api/today-briefing`, `/api/chat`, `/api/chat/confirm`, or legacy broad proposal state was introduced.

## Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q`: PASS, 23 passed, 2 existing dependency warnings.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_study_smart_mode_briefing.py tests/test_study_smart_mode_proposals.py tests/test_study_plan_adjustment_dialogue_preview.py tests/test_study_plan_adjustment_dialogue_apply.py -q`: PASS, 52 passed, 2 existing dependency warnings.
- `openspec validate introduce-study-smart-mode --strict`: PASS.
- `git diff --check`: PASS.

## Remaining Risk

- This backend rejection slice does not include Swift client/ViewModel/UI wiring. Those remain tasks 6.x and 7.x.
