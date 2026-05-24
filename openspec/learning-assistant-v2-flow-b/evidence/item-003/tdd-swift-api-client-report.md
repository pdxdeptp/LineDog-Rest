# ITEM-003 Swift API Client TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 8.1: failing Swift model/client tests for adjustment endpoints and enriched study-view payloads.
- Task 8.2: Swift API models, protocol methods, and concrete client calls.

Out of scope:
- ViewModel state machine, SwiftUI UI, backend code, worktree, commit, or state/progress file edits.

## RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantTests -quiet
```

Expected failure observed:

```text
Testing failed:
Value of type 'StudyViewTask' has no member 'rolledDayCount'
Value of type 'StudyViewTask' has no member 'showRolledBadge'
Value of type 'StudyProjectSummary' has no member 'expectedLate'
Value of type 'StudyCalendarDay' has no member 'restDay'
Value of type 'StudyCalendarDay' has no member 'availableCapacityMinutes'
Cannot find 'StudyTaskMoveRequest' in scope
Cannot find 'StudyProjectDeadlineUpdateRequest' in scope
Cannot find 'StudyTaskInsertRequest' in scope
Cannot find 'StudyRestDaySettings' in scope
Cannot find 'StudyDialogueAdjustmentRequest' in scope
Cannot find 'StudyRolloverResult' in scope
Value of type 'AssistantAPIClient' has no member 'rolloverStudyTasks'
Value of type 'AssistantAPIClient' has no member 'moveStudyTask'
Value of type 'AssistantAPIClient' has no member 'updateStudyProjectDeadline'
Value of type 'AssistantAPIClient' has no member 'insertStudyProjectTask'
Value of type 'AssistantAPIClient' has no member 'deleteStudyTask'
Value of type 'AssistantAPIClient' has no member 'fetchStudyRestDaySettings'
Value of type 'AssistantAPIClient' has no member 'updateStudyRestDaySettings'
Value of type 'AssistantAPIClient' has no member 'previewStudyDialogueAdjustment'
Value of type 'AssistantAPIClient' has no member 'applyStudyDialogueAdjustment'
Testing cancelled because the build failed.
```

The failing tests covered:
- decoding Today rolled-day count and badge facts;
- decoding Project Overview `expected_late`;
- decoding Calendar `rest_day`, `available_capacity_minutes`, and `over_capacity`;
- snake_case request bodies for move, deadline, insert, rest days, dialogue preview, and dialogue apply;
- decoding rollover, move, rest-day update, dialogue preview, and dialogue apply payloads;
- sending a typed dialogue preview object in the apply body;
- concrete client HTTP method/path/body coverage for all adjustment endpoints.

## GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantTests -quiet
```

Result:

```text
Exit code: 0
```

Implementation summary:
- Extended study-view models with `rolledDayCount`, `showRolledBadge`, `expectedLate`, `restDay`, and `availableCapacityMinutes`.
- Added typed Swift Codable models for rollover, manual move, deadline update, task insert/delete, rest-day settings/update, dialogue preview/apply, red-state impact, over-capacity impact, and refresh contract.
- Added `AssistantAPIClientProtocol` methods for all adjustment endpoints, with offline default implementations.
- Added concrete `AssistantAPIClient` calls for all adjustment endpoints using existing `get`, `post`, `put`, and a new generic `delete<T: Decodable>` helper.
- Dialogue apply sends a typed `StudyDialogueAdjustmentPreview` inside `StudyDialogueAdjustmentApplyRequest`.

## REFACTOR

Refactor after GREEN was limited to protocol signature formatting/readability. No behavior changed.

Verification after refactor:

```bash
cd /Users/cpt/Public/MalDaze
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantTests -quiet
```

Result:

```text
Exit code: 0
```

Notes:
- The focused test run emits existing Swift concurrency warnings in unrelated app/test files.
- No ViewModel, SwiftUI, or backend code was changed.

## Review

Spec compliance review: PASS.
- Client/model layer now represents all enriched study-view fields listed for Task 8.1.
- Client/model layer now covers every adjustment endpoint listed for Task 8.2.
- Dialogue apply uses a typed preview model instead of an untyped `[String: Any]` payload.
- Independent controller review confirmed no ViewModel, SwiftUI, backend, smart-mode, or LLM behavior was implemented in this slice.

Code quality review: PASS.
- Models remain local to the existing API client file, matching current project style.
- Request/response models use explicit snake_case coding keys where needed.
- Protocol defaults preserve offline/mock compatibility for non-adjustment call sites.
- Non-blocking minor note: existing legacy payload tests prove backward-compatible decoding, while explicit missing-field default assertions can be strengthened later if adjacent tests change.

## Final Verification

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
