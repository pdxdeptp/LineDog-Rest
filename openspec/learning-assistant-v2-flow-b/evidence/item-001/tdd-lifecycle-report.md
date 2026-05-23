# ITEM-001 TDD Report · Draft Lifecycle

## Scope

Tasks:

- 2.1 Write failing backend tests for draft study project lifecycle.
- 2.2 Implement minimal draft study project persistence and activation path.

Files changed:

- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/study_plan/__init__.py`
- `assistant_backend/src/study_plan/lifecycle.py`

## RED

Initial RED command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_lifecycle.py -q
```

Initial result:

```text
3 failed
ModuleNotFoundError: No module named 'src.study_plan.lifecycle'
```

Review-driven RED command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_lifecycle.py -q
```

Review-driven result:

```text
1 failed, 4 passed
target failure: duplicate/stale confirm path did not raise ValueError
```

## GREEN

Command:

```bash
cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_lifecycle.py tests/test_resource_management.py -q
```

Result:

```text
18 passed, 2 warnings
```

Warnings are existing dependency deprecation warnings from Google GenAI/LangGraph packages.

## Reviews

Spec compliance review:

```text
APPROVED
```

Code quality review initially requested changes for confirm transaction safety. The worker added failing regression tests and changed `confirm_draft_study_project()` to claim the draft inside `BEGIN IMMEDIATE` with a conditional `review -> activating` transition before creating active data.

Second spec compliance review:

```text
APPROVED
```

Second code quality review:

```text
APPROVED
```

## Notes

The implementation intentionally does not include D24 scheduling, D29 decomposition, D30 guided clarification, Swift API, or UI work. Those remain separate tasks.
