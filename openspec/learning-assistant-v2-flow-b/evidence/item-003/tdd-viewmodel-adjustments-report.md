# ITEM-003 ViewModel Adjustments TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 8.3: failing ViewModel tests for rollover refresh, manual move cascade refresh, deadline edit, add/delete task, rest-day changes, and dialogue preview/apply state.
- Task 8.4: ViewModel adjustment state and refresh sequencing.

Out of scope:
- SwiftUI controls, backend routes/services, API client/protocol changes, smart-mode suggestions, old v1 agent behavior, worktree, commit, or automation state/progress edits by the implementation worker.

## RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
```

Expected failure observed:

```text
Build failed because LearningAssistantViewModel did not yet expose adjustment methods/state:
- rolloverStudyTasks()
- moveStudyTask(id:scheduledDate:)
- updateStudyProjectDeadline(projectId:deadline:)
- insertStudyProjectTask(projectId:title:targetMinutes:scheduledDate:)
- deleteStudyTask(id:)
- fetchStudyRestDaySettings()
- updateStudyRestDaySettings(_:)
- previewStudyDialogueAdjustment(instruction:projectId:)
- applyStudyDialogueAdjustment(instruction:projectId:)
- studyRestDaySettings
- studyDialogueAdjustmentPreview
- studyDialogueAdjustmentResult
- studyPlanAdjustmentError
- isAdjustingStudyPlan
```

The failing tests covered:
- rollover endpoint call plus dashboard and currently loaded calendar refresh;
- manual move endpoint call plus persisted-facts refresh without local cascade;
- deadline edit endpoint call plus refresh without local task date mutation;
- task insert/delete endpoint calls plus refresh;
- rest-day fetch/update state and update refresh;
- dialogue preview state without mutation or refresh;
- dialogue apply using stored typed preview, clearing preview on success, and refreshing;
- failure paths that set adjustment error/offline state and avoid refresh;
- default-mode silence by asserting old chat/confirm paths are not called.

## GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
```

Result:

```text
Exit code: 0
```

Implementation summary:
- Added published ViewModel state for rest-day settings, typed dialogue preview/apply result, adjustment errors, and busy state.
- Added ViewModel adjustment methods for rollover, manual move, deadline edit, task insert/delete, rest-day fetch/update, dialogue preview, and dialogue apply.
- Reused the existing dashboard refresh queue so mutation success refreshes Today, Project Overview, and resources from backend facts.
- Refreshed the currently loaded calendar range after mutations when a calendar load is present.
- Kept dialogue preview non-mutating and non-refreshing.
- Kept dialogue apply typed-preview based, clears preview only after successful apply, and preserves preview on failure.
- Did not call old chat, confirm, LLM, smart-mode, or automatic repair paths.

## REFACTOR

Refactor after GREEN was limited to keeping refresh behavior behind small private helpers:
- `performStudyPlanAdjustment(_:)`
- `refreshAfterStudyPlanAdjustment()`

Verification after refactor:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
```

Result:

```text
Exit code: 0
```

Notes:
- The focused test run emits existing Swift concurrency and XCTest deployment warnings outside this slice.
- No SwiftUI, backend, API client, or protocol code was changed.

## Review

Spec compliance review: PASS.
- ViewModel surface covers tasks 8.3 and 8.4.
- Mutations refresh backend facts rather than locally mutating task dates.
- Dialogue preview is non-mutating and dialogue apply uses a stored typed preview.
- No smart-mode, LLM, old v1 chat, or automatic repair behavior was introduced.

Code quality review: PASS.
- Busy/error state follows the existing ViewModel style and resets with `defer`.
- Calendar refresh preserves the current loaded range.
- Full dashboard refresh is consistent with the existing atomic dashboard refresh pattern.
- Non-blocking minor risk: a previous dialogue apply result can remain visible after a later preview/apply failure.
- Non-blocking minor risk: duplicate in-flight adjustment guard exists but does not yet have a dedicated concurrent test.

## Final Verification

Command:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
```

Result:

```text
Exit code: 0
```

Command:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantTests -quiet
```

Result:

```text
Exit code: 0
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
