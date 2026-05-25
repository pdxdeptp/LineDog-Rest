# Apply Group Evidence: entry-role-and-attachment-review

- Automation: add-initiate-changes
- Change: redesign-add-initiate-ui
- Checkpoint: redesign-add-initiate-ui:apply:entry-role-and-attachment-review
- Completed at: 2026-05-25T14:36:21Z
- Result: completed
- Implementation commit: d6e3ec280e5294d2bd8b7d1bd859999490630120

## Scope

Completed the Add / Initiate entry, role review, and existing-plan attachment review group covering tasks 1.1, 1.2, 2.1, and 2.2.

In scope:

- Renamed the Add tab surface to Add / Initiate / 添加 / 立项 while preserving bottom navigation behavior.
- Added first-version input source types for text goals, URLs, GitHub repos, existing project snippets, interview prep items, resume/project notes, and note snippets.
- Started Add / Initiate sessions through the typed adapter API instead of the legacy URL ingestion or old study-plan start paths.
- Added role review UI for recommended role, confidence, reason codes, role switching, existing-plan candidates, and attachment mode choices.
- Added ViewModel request mapping for `material_only`, `draft_phase`, and `scheduled_work`, including the user-facing supporting-material mapping to `attach_to_existing_plan` plus `material_only`.
- Preserved quiet add-time behavior for non-activation role confirmation paths by not refreshing Today, Home, Calendar, or resources.

Out of scope:

- Anchor review, full Add / Initiate state machine, draft review, infeasible options, option effects, activation UI, scheduler/compiler logic, and backend noise-boundary changes remain in later apply groups.
- OpenSpec task checkboxes remain unchanged; final verification owns checkbox completion.

## TDD Record

RED:

- Added ViewModel and UI source tests for Add / Initiate entry labels, source types, adapter start, role review rendering, attachment modes, quiet material-only confirmation, and legacy path avoidance.
- Review-driven RED cycles caught and fixed:
  - attachment context leaking into non-attachment role confirmations;
  - supporting material missing an existing-plan guard;
  - `attach_to_existing_plan` missing required plan/mode guards;
  - stale role-confirmation failures overwriting a newer session;
  - one-off role using the wrong canonical backend value;
  - role-review UI seeding retaining previous session selections.

GREEN:

- Added `AddInitiateSourceType`, `AddInitiateRoleChoice`, `AddInitiateAttachmentMode`, and lightweight existing-plan candidate mapping in the ViewModel.
- Added Add / Initiate start and role-confirmation ViewModel methods with session identity guards.
- Replaced the old Add tab content with `AddInitiateView`.
- Added role review, source-type input, existing-plan picker, and attachment mode picker UI.
- Added focused ViewModel tests for adapter calls, attachment mapping, quiet confirmation, stale failure rejection, canonical one-off role mapping, and required existing-plan/mode guards.

REFACTOR:

- Reset role-review local UI selections by session/intake identity so stale plans and attachment modes cannot carry into a new session.
- Kept later planning states out of this group and left `StudyPlanIntakeView` in the file for non-primary compatibility until later cleanup decisions.

## Review

- Spec compliance review 1: CHANGES_REQUESTED. Fixed attachment payload leakage, supporting-material missing-plan behavior, bottom navigation label, and missing attachment-mode tests.
- Spec compliance re-review: APPROVED.
- Code quality review 1: CHANGES_REQUESTED. Fixed role-review selection seeding, `attach_to_existing_plan` guards, stale failure handling, one-off role canonical value, and brittle attachment-mode test setup.
- Code quality re-review: APPROVED.

## Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`: passed.
- `openspec validate redesign-add-initiate-ui --strict`: valid.
- `git diff --check -- MalDaze/LearningAssistant/AssistantPanelView.swift MalDaze/LearningAssistant/LearningAssistantViewModel.swift MalDazeTests/LearningAssistantTests.swift`: no whitespace errors.
- `git commit -m "Implement Add Initiate entry role review"`: d6e3ec280e5294d2bd8b7d1bd859999490630120.

## Files

- `MalDaze/LearningAssistant/AssistantPanelView.swift`
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
- `MalDazeTests/LearningAssistantTests.swift`

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

Next checkpoint: redesign-add-initiate-ui:apply:anchor-state-machine-and-recovery
