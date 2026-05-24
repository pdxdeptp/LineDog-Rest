# TDD Report: ITEM-004 Backend Smart After-Adjustment Proposals

## Scope

- OpenSpec change: `introduce-study-smart-mode`
- Tasks: 4.3, 4.4
- Files:
  - `assistant_backend/src/routers/study_smart_mode.py`
  - `assistant_backend/tests/test_study_smart_mode_proposals.py`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

### Newly Created Red-State Options

Command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

Result:

- Failed as expected: `1 failed, 8 passed`
- Key failure: `trigger="after_adjustment"` expected newly created expected-late and over-capacity preview options, but the route returned `options == []`.

### Partial Previous Context Guard

Command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

Result:

- Failed as expected after code-quality review added the missing case: `2 failed, 10 passed`
- Key failures:
  - partial expected-late previous context incorrectly returned capacity options;
  - partial capacity previous context incorrectly returned expected-late options.

## GREEN

Command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

Result:

- PASS: `12 passed, 2 warnings`

Implementation summary:

- Added optional previous red-state context to `SmartModeProposalRequest`.
- Added after-adjustment proposal generation from read-only v2 fact snapshots.
- Generated after-adjustment preview options only for newly created expected-late projects or over-capacity days.
- Kept both previous-context categories independently gated, so missing context for one category does not imply that category was previously empty.
- Ensured lag/rolled-task facts do not trigger after-adjustment options.
- Preserved morning proposal behavior and preview-only semantics.

## Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: initially CHANGES_REQUESTED for partial previous-context false positives.
- Review fix completed with partial-context RED tests and independent category gating.
- Code Quality Re-review: APPROVED.

## Verification

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_proposals.py -q
```

- PASS: `12 passed, 2 warnings`

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_smart_mode_settings.py tests/test_study_smart_mode_briefing.py tests/test_study_smart_mode_proposals.py tests/test_study_plan_adjustment_dialogue_preview.py tests/test_study_plan_adjustment_dialogue_apply.py -q
```

- PASS: `41 passed, 2 warnings`

```bash
openspec validate introduce-study-smart-mode --strict
```

- PASS

```bash
git diff --check
```

- PASS

## Remaining Risk

- Swift tasks 6.x must pass previous red-state context when requesting `after_adjustment` proposals. If the client omits both context fields, the backend conservatively returns no options.
- Proposal apply/revalidation remains tasks 5.x and was not implemented in this slice.
