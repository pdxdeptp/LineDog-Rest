# Apply Group Evidence: anchor-state-machine-and-recovery

- Automation: add-initiate-changes
- Change: redesign-add-initiate-ui
- Checkpoint: redesign-add-initiate-ui:apply:anchor-state-machine-and-recovery
- Completed at: 2026-05-25T15:15:14Z
- Result: completed
- Implementation commit: 7b7b1adf6e8b506e494bbb383f01c6e2fedc51e5

## Scope

Completed the Add / Initiate anchor, state machine, recovery, and stale-response group covering tasks 2.3, 2.4, 2.5, and 2.6.

In scope:

- Added the single Add / Initiate ViewModel state projection for idle input, routing progress, role review, non-plan terminal, anchor review, planning progress, needs input, compile failed, infeasible review, draft review, option-effect progress, activation progress, activation failed, activated, and cancelled states.
- Added anchor draft fields for deadline, deadline type, daily capacity, target output, target depth, and assumptions.
- Added anchor confirmation through the Add / Initiate adapter with planning-progress feedback.
- Added needs-input recovery that keeps the existing session, role, anchors, assumptions, and editable anchor context.
- Added compile-failed retry that reuses retained anchors.
- Added minimal infeasible-review, draft-review, activation-failed, non-plan terminal, cancelled, option-effect progress, and activation progress state handling needed for this group.
- Added generation/request identity guards so stale session, stale draft-version, retry, option-effect, activation, and cancelled-flow responses cannot overwrite newer state.
- Updated the Add / Initiate UI to avoid multiple prominent primary actions in review states and to avoid visible raw state-machine tokens.

Out of scope:

- Full summary-first draft review UI remains in `draft-review-options-and-activation`.
- Detailed option-effect UI remains in `draft-review-options-and-activation`.
- Active-surface refresh/noise-boundary backend verification remains in `noise-boundaries-and-active-refresh`.
- Final real-context QA and OpenSpec task checkbox completion remain in `real-context-qa-and-final-verification`.
- OpenSpec task checkboxes remain unchanged; final verification owns checkbox completion.

## TDD Record

RED:

- Added focused ViewModel and UI-source tests for anchor confirmation, planning progress, retained anchors, needs-input recovery, compile-failed retry, cancellation, stale session rejection, same-session stale draft-version rejection, superseded starts, superseded anchor confirmations, option-effect identity, activation-failure recovery, one-primary-action UI, and visible-token cleanup.
- Initial RED failed on missing `AddInitiateFlowState`, anchor draft fields, `confirmAddInitiateAnchors`, assumptions text binding, mock anchor/option/activation capture hooks, cancellation invalidation, and superseding request guards.

GREEN:

- Implemented the ViewModel state projection and primary-action count.
- Implemented anchor confirmation request construction and retained-anchor retry.
- Implemented `addInitiateFlowGeneration` plus per-operation request sequences for stale response rejection.
- Implemented cancel and prepare-for-new-input flows that invalidate in-flight responses.
- Implemented minimal option-effect and activation state methods needed for stale identity and activation-failure recovery.
- Implemented anchor/recovery UI cards with localized visible text, single prominent primary action, and non-primary cancel actions.
- Extended the test mock with delayed start, role, anchor, option, and activation responses plus wait helpers.

REFACTOR:

- Moved assumptions editing from local SwiftUI state into the ViewModel to avoid cross-session leakage.
- Kept raw state names out of visible text while preserving accessibility/test identifiers where useful.
- Kept later-group draft/option/activation UI intentionally minimal.

## Review

- Spec compliance review 1: CHANGES_REQUESTED.
  - Fixed duplicate prominent primary actions caused by the always-visible input card.
  - Wired activation-failed retry to `activateAddInitiateDraft`.
  - Kept needs-input anchors and assumptions visible/editable.
  - Added non-plan/cancel primary actions.
  - Tightened same-session draft-version stale guards.
- Code quality review 1: CHANGES_REQUESTED.
  - Added cancellation invalidation for in-flight responses.
  - Allowed new starts and new anchor confirmations to supersede older in-flight operations.
  - Removed cross-session assumptions text leakage.
  - Removed visible raw/internal state tokens.
  - Removed enabled no-op primary buttons.
- Spec compliance re-review: APPROVED.
- Code quality re-review: APPROVED.

## Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet`: passed.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`: passed.
- `openspec validate redesign-add-initiate-ui --strict`: valid.
- `git diff --check -- MalDaze/LearningAssistant/AssistantPanelView.swift MalDaze/LearningAssistant/LearningAssistantViewModel.swift MalDazeTests/LearningAssistantTests.swift`: no whitespace errors.
- `git commit -m "Implement Add Initiate anchor state machine"`: 7b7b1adf6e8b506e494bbb383f01c6e2fedc51e5.

One intermediate UI-source test run failed with an Xcode `build.db` lock because two local `xcodebuild` commands were accidentally launched concurrently. The same test suite was rerun sequentially and passed.

## Files

- `MalDaze/LearningAssistant/AssistantPanelView.swift`
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
- `MalDazeTests/LearningAssistantTests.swift`

## Artifact Hashes

- `MalDaze/LearningAssistant/AssistantPanelView.swift`: `99f560684bc0c6f7671f1fce134362a539ff9adaba4c4357d25a9d8dc983435b`
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`: `f5269d33289c768d24d41b9b2a19ead98ef313355cfb0a9dc81745307cfda0eb`
- `MalDazeTests/LearningAssistantTests.swift`: `0ec596b57d5b23d19926136ae37de5da35147c44bb884b898ba3235aba9a1527`

## Protected Unrelated Dirty Paths

The following dirty paths were present before this checkpoint and were not edited or staged by this apply group:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Next

Next checkpoint: redesign-add-initiate-ui:apply:draft-review-options-and-activation
