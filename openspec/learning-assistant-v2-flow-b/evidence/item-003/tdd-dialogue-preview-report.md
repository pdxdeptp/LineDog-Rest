# ITEM-003 Dialogue Preview TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 7.1: failing backend tests for supported dialogue adjustment preview without mutation.
- Task 7.2: bounded dialogue preview for project-level date shifts.

Out of scope:
- Dialogue apply route and event persistence.
- Swift client/ViewModel/UI.
- Design document changes.

## RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_preview.py -q
```

Expected failure observed:

```text
2 failed
AssertionError: {"detail":"Not Found"}
assert 404 == 200
```

The failing tests covered:
- `POST /api/study-plan-adjustment/dialogue/preview`;
- explicit bounded command `push project 6101 by one week`;
- contextual bounded command `delay this project by 3 days` with request `project_id`;
- structured preview payload with affected task ids, old dates, new dates, `delta_days`, and expected-late before/after;
- no mutation of tasks, resources, events, or system_state.

## GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_preview.py -q
```

Result:

```text
2 passed, 2 warnings
```

Implementation summary:
- Added deterministic bounded parser for `push|delay` plus `project <id>` or `this project` plus `by <N|one..ten|a|an> day(s)|week(s)`.
- Added `preview_active_study_project_shift` read-only query that returns unfinished active study-project tasks shifted by `delta_days`.
- Added `POST /api/study-plan-adjustment/dialogue/preview`.
- Unsupported or ambiguous instructions return a no-op `unsupported` response with `mutates: false`.

## REFACTOR

No behavioral refactor was needed after GREEN. The implementation stayed scoped to parser, router, and read-only query helpers.

## Review

Spec compliance:
- Matches the Dialogue Adjustment Preview scenario for supported project shifts.
- Preview returns structured changes and expected-late red-state impact.
- Preview does not write task dates or events and does not touch the v1 conversational agent or any LLM path.

Code quality:
- Uses deterministic regex parsing and existing DB/router patterns.
- Keeps apply semantics out of this slice.
- Leaves unsupported/ambiguous handling deliberately small for tasks 7.3/7.4.

## Regression

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
```

Result:

```text
37 passed, 2 warnings
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

## Review Fix: Red-State Day Load And Bounded Parser

CHANGES_REQUESTED addressed:
- P1: `red_state_impact` now includes over-capacity day-load impact in addition to expected-late.
- P1: parser no longer accepts partial sentence matches, negated commands, compound commands, `ago`, conflicting project ids, or out-of-range amounts.
- P2: amount is bounded to 1..365 days after week conversion, and instruction length is capped at 240 characters.

### RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_preview.py -q
```

Expected failure observed:

```text
10 failed, 2 passed
KeyError: 'over_capacity'
AssertionError: assert 'preview' == 'unsupported'
```

The failing tests covered:
- happy-path previews missing empty over-capacity impact;
- a shift that lands one task on a crowded date and another on a rest day;
- no mutation while computing capacity/rest-day impact;
- rejection of negated, compound, trailing `ago`, zero, too-large, and conflicting-project-id commands.

### GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_preview.py -q
```

Result:

```text
12 passed, 2 warnings
```

Implementation summary:
- Parser now uses anchored `fullmatch` with optional final punctuation only.
- Parser rejects unsupported/no-op commands when the converted delta is outside 1..365 days.
- Preview computes `over_capacity.before_dates`, `after_dates`, and `new_over_capacity_dates`.
- Day-load impact includes other active study-project tasks on affected dates and treats weekly/one-off rest days as zero capacity.
- Preview still does not mutate tasks, resources, events, or system_state.

Verification:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_dialogue_preview.py -q
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
openspec validate introduce-study-plan-adjustment --strict
git diff --check
```

Result:

- Dialogue preview tests: `12 passed`.
- Backend study-plan adjustment suite: `47 passed`.
- OpenSpec strict validation: PASS.
- `git diff --check`: PASS.

Re-review:

- Spec Compliance Re-review: PASS.
- Code Quality Re-review: PASS with one non-blocking P3 note about a past-boundary test name being broader than its route-level coverage.
