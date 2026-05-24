# ITEM-003 / 10.1-10.2 Test And OpenSpec Validation Report

Date: 2026-05-24
Change: `introduce-study-plan-adjustment`

## Scope

Run the relevant backend and Swift regression checks for the `study-plan-adjustment` OpenSpec change, then run strict OpenSpec validation.

## Backend Verification

Command:

```sh
assistant_backend/.venv/bin/python -m pytest \
  assistant_backend/tests/test_study_plan_adjustment_schema.py \
  assistant_backend/tests/test_study_plan_adjustment_rollover.py \
  assistant_backend/tests/test_study_plan_adjustment_move.py \
  assistant_backend/tests/test_study_plan_adjustment_deadline.py \
  assistant_backend/tests/test_study_plan_adjustment_insert.py \
  assistant_backend/tests/test_study_plan_adjustment_delete.py \
  assistant_backend/tests/test_study_plan_adjustment_rest_days.py \
  assistant_backend/tests/test_study_plan_adjustment_dialogue_preview.py \
  assistant_backend/tests/test_study_plan_adjustment_dialogue_apply.py \
  assistant_backend/tests/test_study_views_today.py \
  assistant_backend/tests/test_study_views_project_overview.py \
  assistant_backend/tests/test_study_views_calendar.py \
  assistant_backend/tests/test_study_views_completion.py \
  -q
```

Result:

- `75 passed, 2 warnings in 12.63s`.
- Warnings were dependency deprecation warnings from `google.genai` and `langgraph`, not test failures.

## Swift Verification

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze \
  -only-testing:MalDazeTests/AssistantModelDecodingTests \
  -only-testing:MalDazeTests/LearningAssistantViewModelTests \
  -only-testing:MalDazeTests/LearningAssistantUISourceTests \
  -quiet
```

Result:

- PASS.
- Covered adjustment API model decoding/client paths, ViewModel mutation/refresh behavior, and SwiftUI source-level wiring for Today, Project Overview, Calendar, Settings, and Adjust Plan.

## OpenSpec Validation

Command:

```sh
openspec validate introduce-study-plan-adjustment --strict
```

Result:

- `Change 'introduce-study-plan-adjustment' is valid`.

## Diff Hygiene

Command:

```sh
git diff --check
```

Result:

- PASS.

## Task State

- 10.1: complete.
- 10.2: complete.
- 10.3: blocked by local desktop lock screen; see `app-verification-blocked.md`.
