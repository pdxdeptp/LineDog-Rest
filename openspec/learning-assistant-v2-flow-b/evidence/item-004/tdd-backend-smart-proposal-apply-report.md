# TDD Report: ITEM-004 Backend Smart Proposal Apply

## Scope

- OpenSpec change: `introduce-study-smart-mode`
- Tasks: 5.1, 5.2
- Files:
  - `assistant_backend/src/routers/study_smart_mode.py`
  - `assistant_backend/tests/test_study_smart_mode_proposals.py`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

Command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

Result:

- Failed as expected: `3 failed, 12 passed`
- Key failure: `POST /api/study-smart-mode/proposals/apply` returned `404 Not Found`.

Review-driven RED:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

- Failed as expected after event evidence expectations were tightened.
- Key failure: `study_smart_mode_proposal_applied` payload did not include `signature_payload`, `reason`, `red_state_impact`, and `selected_preview`.

## GREEN

Command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

Result:

- PASS: `15 passed, 2 warnings`

Implementation summary:

- Added `POST /api/study-smart-mode/proposals/apply`.
- Apply now runs smart-mode enabled check, current v2 fact reads, current proposal regeneration, signature matching, mutation, event insert, and commit/rollback inside one `BEGIN IMMEDIATE` transaction.
- Apply mutates only the selected current proposal:
  - `extend_project_deadline` updates the matching active study project deadline.
  - `make_room_after_lag` and `move_task_from_over_capacity_day` update only `previewed_changes` task dates and reset rollover/user-adjustment metadata.
- Event evidence records `source`, proposal id/signature, `signature_payload`, trigger, command, reason, affected ids, red-state impact, selected preview, and applied changes.
- Response includes `refresh: {"today": true, "project_overview": true, "calendar": true}`.

## Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: initially CHANGES_REQUESTED for transaction boundary and thin event evidence.
- Review fixes completed:
  - moved current proposal recomputation and matching inside the apply transaction;
  - expanded event payload for auditability.
- Code Quality Re-review: APPROVED.

## Verification

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

- PASS: `15 passed, 2 warnings`

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_study_smart_mode_briefing.py tests/test_study_smart_mode_proposals.py tests/test_study_plan_adjustment_dialogue_preview.py tests/test_study_plan_adjustment_dialogue_apply.py -q
```

- PASS: `44 passed, 2 warnings`

```bash
openspec validate introduce-study-smart-mode --strict
```

- PASS

```bash
git diff --check
```

- PASS

## Remaining Risk

- Full stale, unsupported, and disabled apply test matrix remains tasks 5.3 and 5.4. This slice includes no-mutation guard responses but does not mark those tasks complete.
