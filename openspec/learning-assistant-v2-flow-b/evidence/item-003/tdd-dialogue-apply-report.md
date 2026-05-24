# ITEM-003 Dialogue Apply TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 7.3: failing backend tests for applying exactly the previewed changes and rejecting unsupported/ambiguous instructions safely.
- Task 7.4: dialogue apply route, event persistence, and view refresh contract.

Out of scope:
- LLM parsing, old conversational agent/chat agent, smart suggestions, automatic repair, or default-mode recommendation behavior.
- Swift client/ViewModel/UI.
- Worktree, commit, or state/progress file edits.

## RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_apply.py -q
```

Expected failure observed:

```text
5 failed
AssertionError: {"detail":"Not Found"}
assert 404 == 200
```

The failing tests covered:
- `POST /api/study-plan-adjustment/dialogue/apply`;
- applying the exact client-submitted previewed project shift;
- updating only unfinished active study tasks in the target project;
- preserving completed tasks and other projects;
- resetting `auto_roll_days`, clearing `last_auto_rolled_at`, and setting `user_adjusted_at` for affected tasks;
- writing one auditable `study_dialogue_adjustment_applied` event with `source: dialogue_apply`, command, delta, project id, affected task ids, and original/new dates;
- returning a view refresh contract for Today, Project Overview, and Calendar;
- no mutation and no event for unsupported, ambiguous, tampered-preview, or stale-preview apply requests.

## GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_apply.py -q
```

Result:

```text
5 passed, 2 warnings
```

Implementation summary:
- Added `POST /api/study-plan-adjustment/dialogue/apply`.
- Reused the bounded deterministic preview parser; unsupported or ambiguous instructions return `status: unsupported`, `mutates: false`.
- Added `apply_active_study_project_shift`, which normalizes the submitted preview signature and recomputes the current DB preview before any mutation.
- Rejects missing, malformed, tampered, or stale previews with `status: stale_preview`, `mutates: false`.
- Applies only matching preview changes inside a transaction, with per-row guards on task id, project id, unfinished status, and original scheduled date.
- Records `study_dialogue_adjustment_applied` with auditable `dialogue_apply` payload and returns the refresh contract.

## REFACTOR

Refactor after GREEN was limited to formatting and import/readability cleanup. No behavior changed.

Verification after refactor:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_apply.py -q
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
```

Result:

```text
Dialogue apply tests: 5 passed, 2 warnings
Backend study-plan adjustment suite: 52 passed, 2 warnings
```

## Review

Spec compliance review: PASS.
- Satisfies the Dialogue Adjustment Preview And Apply scenario for applying a preview.
- Uses source `dialogue_apply`, event evidence, and active view refresh contract.
- Keeps unsupported, ambiguous, stale, and mismatch requests safe and non-mutating.
- Does not connect to LLM, v1 chat/conversational agent, smart suggestions, automatic repair, or default-mode recommendations.

Code quality review: PASS.
- Transaction boundaries prevent partial application.
- Preview signature comparison covers command, project id, delta days, affected task ids, and old/new dates.
- Row-level update guards add a second stale-data check before mutation.
- Event payload uses explicit original/new dates for auditability.

## Regression

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
```

Result:

```text
52 passed, 2 warnings
```

Command:

```bash
cd /Users/cpt/Public/MalDaze
openspec validate introduce-study-plan-adjustment --strict
```

Result:

```text
Change 'introduce-study-plan-adjustment' is valid
```

Command:

```bash
cd /Users/cpt/Public/MalDaze
git diff --check
```

Result: passed with no whitespace errors.

## Review Fix: Red-State Drift And Empty Preview Safety

Review items addressed:
- P2: apply must reject a submitted preview when the current `red_state_impact` no longer matches what the user saw, even if task ids and date changes still match.
- P3: a project shift with no unfinished tasks must not be presented or applied as a mutating preview.
- Additional guard: duplicate/tampered `affected_task_ids` remain stale/no-op.

### RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_apply.py -q
```

Expected failure observed:

```text
2 failed, 6 passed, 2 warnings
AssertionError: assert 'applied' == 'stale_preview'
AssertionError: assert 'preview' == 'unsupported'
```

The failing tests covered:
- daily-capacity drift after preview, causing the current over-capacity summary to differ while date changes remained unchanged;
- active study project with only completed tasks returning a mutating preview;
- stale/no-op apply behavior and no event/no task mutation expectations.

### GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_apply.py -q
```

Result:

```text
8 passed, 2 warnings
```

Implementation summary:
- Preview now returns `unsupported`, `mutates: false` when a supported project-shift command has no unfinished tasks to move.
- Apply preview signature now includes normalized `red_state_impact.expected_late` and `red_state_impact.over_capacity` facts.
- Apply rejects empty or malformed preview signatures before mutation.
- Apply still recomputes the current preview inside the transaction and rejects stale/mismatched previews without writing events.

### Regression

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
```

Result:

```text
55 passed, 2 warnings
```
