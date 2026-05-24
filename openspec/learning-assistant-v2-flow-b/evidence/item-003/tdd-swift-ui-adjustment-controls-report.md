# TDD Report: Swift UI Adjustment Controls

## Scope

- Flow B / ITEM-003 / OpenSpec change `introduce-study-plan-adjustment`
- Tasks: 9.1, 9.2
- Slice: Swift UI source tests and minimal controls in `AssistantPanelView.swift`

## RED

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: failed as expected on the old UI.

Expected failing coverage:

- Today lacked `showRolledBadge` / `rolledDayCount` display and `vm.moveStudyTask` wiring.
- Project Overview lacked `expectedLate` red fact display and `vm.updateStudyProjectDeadline` wiring.
- Calendar still asserted no mutation wiring and lacked rest day / available capacity facts plus add/delete/move controls.
- Settings still routed directly to `LearningPreferencesView` instead of a rest-day capable settings view.
- Adjust Plan still routed to `ChatView(vm: vm)` instead of preview/apply UI.

## GREEN

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: passed after implementing the minimal UI.

Implementation summary:

- Today rows now show rolled facts near tasks and include a compact date text field plus move button wired to `vm.moveStudyTask`.
- Project Overview now shows `expectedLate` as a red factual state and exposes deadline editing only for active projects.
- Calendar now shows rest day, available capacity, and red over-capacity facts, plus compact add/delete/move controls wired to the existing ViewModel methods.
- Settings now routes through `StudySettingsView`, preserving the daily capacity entry and adding rest-day fetch/update controls.
- Adjust Plan now routes through `StudyPlanAdjustmentView`, consumes seeded adjustment draft text, previews via `vm.previewStudyDialogueAdjustment`, applies via `vm.applyStudyDialogueAdjustment`, and displays preview/result/red-state impact.

## REFACTOR

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: passed after formatting cleanup.

Additional verification:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
openspec validate introduce-study-plan-adjustment --strict
git diff --check
```

Result:

- `LearningAssistantViewModelTests`: passed.
- `openspec validate introduce-study-plan-adjustment --strict`: passed.
- `git diff --check`: passed.

## Modified Files

- `MalDaze/LearningAssistant/AssistantPanelView.swift`
- `MalDazeTests/LearningAssistantTests.swift`
- `openspec/changes/introduce-study-plan-adjustment/tasks.md`
- `openspec/learning-assistant-v2-flow-b/evidence/item-003/tdd-swift-ui-adjustment-controls-report.md`

## Remaining Risk

- The UI controls are intentionally compact and ID/date text-field based; they are functional wiring for the v2 slice, not a polished drag/drop calendar editor.
- Manual desktop app QA for 10.3 remains outstanding and should verify the controls against a live backend dataset.

## Review Fix RED

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: failed as expected after adding source constraints for the BLOCKED review feedback.

Expected failing coverage:

- Calendar adjustment controls had to be split into `calendarAddTaskControls`, `calendarDeleteTaskControls`, and `calendarMoveTaskControls` instead of one wide row.
- Adjust Plan needed local `previewedInstruction` / `previewedProjectId` identity and `hasCurrentPreview` so Apply cannot reuse a stale preview after input changes.
- Settings and Adjust Plan needed domain-specific error helpers instead of showing bare shared `studyPlanAdjustmentError`.
- Today move action needed `todayMoveDateChanged(for:)` so the default date is not immediately actionable.

Additional RED command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelAdjustPlanApplyRequiresPreviewForCurrentInput -quiet
```

Result: failed as expected after strengthening the stale-preview guard to require local preview identity reset before preview and rebinding only when `vm.studyPlanAdjustmentError == nil`.

## Review Fix GREEN

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: passed.

Reviewer issue closure:

- Calendar controls are now vertically split into narrow-column sections for add, delete, and move.
- Apply is disabled unless the stored preview belongs to the current trimmed instruction and current optional project id.
- Preview identity is cleared before preview requests and only restored after a successful preview for unchanged inputs, preventing old preview reuse after failed/stale preview attempts.
- Settings shows `休息日设置失败：...` only after rest-day operations; Adjust Plan shows `计划调整失败：...` only after dialogue operations.
- Today move is disabled until the user changes the date from the default Today date.

## Review Fix REFACTOR

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: passed after the preview identity reset refinement.

Final verification to run after this report update:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
openspec validate introduce-study-plan-adjustment --strict
git diff --check
```

Final verification result before auto commit:

- `LearningAssistantUISourceTests`: passed.
- `LearningAssistantViewModelTests`: passed.
- `openspec validate introduce-study-plan-adjustment --strict`: passed.
- `git diff --check`: passed.
- Spec Compliance Review: passed.
- Code Quality Re-review: passed after the review-fix TDD cycle.
