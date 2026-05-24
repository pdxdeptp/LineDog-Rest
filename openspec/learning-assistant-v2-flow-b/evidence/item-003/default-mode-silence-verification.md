# ITEM-003 / 9.3 Default Mode Silence Verification

Date: 2026-05-24
Change: `introduce-study-plan-adjustment`

## Scope

Verify that red-state-producing manual study plan adjustments remain silent in default mode:

- Red states are shown as facts only (`expectedLate`, `overCapacity`, `restDay`, dialogue preview `redStateImpact`).
- Manual mutations do not invoke legacy chat/proposal flow.
- No smart suggestion card, automatic repair plan, or repair payload is introduced.

## RED 1: UI Source Guard

Added `LearningAssistantUISourceTests.testDefaultModeRedStateSectionsStayFactOnlyWithoutSmartSuggestionsOrRepairWiring`.

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
```

Result: failed as expected.

Failure summary:

- `testDefaultModeRedStateSectionsStayFactOnlyWithoutSmartSuggestionsOrRepairWiring()` failed because `AssistantPanelView.swift` did not yet contain/use `defaultModeSilentRedStateFact` in the Project, Calendar, and Adjust Plan red-state sections.

## RED 2: Manual Red-State Fixture Gap

Spec compliance review found that the first ViewModel aggregation test proved "manual mutations do not call chat/proposal", but did not prove the mutations produced red-state facts. The test still used the default `sampleStudyCalendarLoad(...)` with `over_capacity: false` and default project overview data without `expected_late: true`.

Added explicit assertions to `LearningAssistantViewModelTests.testManualAdjustmentMutationsDoNotInvokeChatProposalOrSmartRepairFlow` before changing fixtures:

- `vm.studyProjectOverview?.activeProjects.first?.expectedLate == true`
- `vm.studyCalendarLoad?.days.first?.overCapacity == true`

Command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests/testManualAdjustmentMutationsDoNotInvokeChatProposalOrSmartRepairFlow -quiet
```

Result: failed as expected because the existing sample fixture did not construct a red-state-producing manual adjustment scenario.

## GREEN

Minimal production/source change:

- Added `defaultModeSilentRedStateFact` in `AssistantPanelView.swift`.
- Wrapped existing red-state fact labels/text in:
  - `StudyCalendarLoadView`: `overCapacity`, `restDay`
  - `ProjectOverviewView`: `expectedLate`
  - `StudyPlanAdjustmentView`: `redStateImpact` expected-late and over-capacity facts

No user-visible smart suggestion, automatic repair, proposal, or chat behavior was added.

Minimal test fixture change:

- `testManualAdjustmentMutationsDoNotInvokeChatProposalOrSmartRepairFlow` now injects a post-adjustment project overview payload with an active project where `expected_late: true`.
- The same test now injects a post-adjustment calendar payload with an over-capacity day where `over_capacity: true`.
- `sampleStudyProjectSummaryJSON` gained an `expectedLate` parameter defaulting to `false`, so existing tests keep their previous behavior unless they explicitly opt into red state.

GREEN command:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests/testManualAdjustmentMutationsDoNotInvokeChatProposalOrSmartRepairFlow -quiet
```

Result: both passed.

## REFACTOR

No behavioral refactor was needed. The helper is intentionally transparent and only creates a stable source-level contract around fact-only red-state rendering.

## ViewModel Verification

Full command after the red-state fixture update:

```sh
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet
```

Result: passed.

Notes:

- The first full target run passed the new `testManualAdjustmentMutationsDoNotInvokeChatProposalOrSmartRepairFlow`, but had one transient unrelated failure in `testResourceManagementIgnoresDifferentResourceWhileAnotherResourceIsInFlight`.
- The same full command was rerun and all `LearningAssistantViewModelTests` passed.
- The updated aggregation test confirms that move, deadline edit, insert, delete, and rest-day update refresh into explicit `expectedLate` / `overCapacity` red-state facts while still not calling `sendMessage` / `confirmChat`, not appending `chatMessages`, not setting `currentProposal`, and not setting dialogue preview/apply state.

## Backend Check

No backend code or tests were modified. Existing backend regression coverage includes:

- `assistant_backend/tests/test_study_plan_adjustment_insert.py::test_inserted_task_after_deadline_recalculates_expected_late_without_repair`

That test asserts an inserted late task makes `expected_late` true without moving tasks into a repair schedule.

## Validation

Commands:

```sh
openspec validate introduce-study-plan-adjustment --strict
git diff --check
```

Results:

- `openspec validate introduce-study-plan-adjustment --strict`: passed.
- `git diff --check`: passed.

## Conclusion

Default mode now has explicit regression coverage that red-state sections remain fact-only and are not wired to smart suggestions, automatic repair, legacy chat, or proposal flows.

## Remaining Risk

- No backend mutation endpoint was changed in this task; backend silence relies on the existing `without_repair` regression coverage listed above.
