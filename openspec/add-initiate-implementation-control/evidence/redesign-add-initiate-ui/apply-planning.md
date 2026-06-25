# Apply Planning: redesign-add-initiate-ui

## Decision

GO for apply planning and pre-apply checkpoint. The scope dependency check passed, all OpenSpec artifacts are complete, and the final Add / Initiate child change can enter implementation once the pre-apply checkpoint commit is recorded.

This apply must not turn the Add / Initiate surface back into URL-only ingestion, parser work, priority judgment, scheduler math, compiler generation, or smart-mode logic. It owns the user-facing session, progress, review, confirmation, and quiet-boundary experience over completed backend primitives.

## Mechanical Check

- `openspec status --change redesign-add-initiate-ui --json`: ready; proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change redesign-add-initiate-ui --json`: ready; 31 pending tasks.
- Scope dependency prerequisite: pass; `changes[4].scopeDependencyCheckCompleted=true`.
- `openspec validate redesign-add-initiate-ui --strict`: pass.
- `jq empty openspec/add-initiate-implementation-control/evidence/redesign-add-initiate-ui/apply-task-groups.json`: pass.
- Workspace: unrelated dirty files are protected and must not be edited or staged by this change.

## Existing Implementation Context

Backend primitives already exist from earlier child changes:

- `assistant_backend/src/routers/study_intake.py` exposes route and confirm intake endpoints.
- `assistant_backend/src/study_plan/intake.py` owns intake role recommendation, attachment modes, non-plan storage, and draft handoff.
- `assistant_backend/src/study_plan/lifecycle.py` owns durable draft identity, versions, package states, activation guard, cancellation, and active-task creation.
- `assistant_backend/src/study_plan/compiler.py` owns phase/task generation, package status, estimates, trace, and compiler recovery.
- `assistant_backend/src/study_plan/scheduling.py` owns deterministic scheduled review packages, risk facts, fallback metadata, infeasibility options, and option effects.

Swift surfaces already exist but are legacy or partial:

- `MalDaze/LearningAssistant/AssistantAPIClient.swift` has legacy URL ingestion and study-plan draft APIs.
- `MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift` defines the injectable API surface for tests.
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift` owns dashboard refresh, ingestion, study-plan draft, smart-mode, adjustment, and calendar state.
- `MalDaze/LearningAssistant/AssistantPanelView.swift` owns the bottom nav and current `StudyPlanIntakeView`.
- `MalDazeTests/LearningAssistantTests.swift` contains backend model decoding, UI source, ViewModel, and ingestion tests.

## Apply Groups

Apply will run sequentially because the groups share `LearningAssistantViewModel.swift`, `AssistantPanelView.swift`, `AssistantAPIClient.swift`, and `MalDazeTests/LearningAssistantTests.swift`.

1. `session-adapter-and-api-contract`
   - Backend/Swift session contract, adapter wrapper, progress identity, stale identity, and legacy URL compatibility guardrails.
   - Must not add new router, compiler, scheduler, or activation algorithms.
2. `entry-role-and-attachment-review`
   - Add / Initiate entry surface, input types, role confirmation, and existing-plan attachment choices.
3. `anchor-state-machine-and-recovery`
   - Anchor confirmation, one Add / Initiate ViewModel state machine, recoverable states, one-primary-action rule, retry and stale response guards.
4. `draft-review-options-and-activation`
   - Summary-first review, first-week schedule rendering, fallback metadata, canonical options, hard-deadline guardrails, option effects, activation and failure paths.
5. `noise-boundaries-and-active-refresh`
   - No Today/Calendar/smart-mode/reminder noise before activation; activation success is the only active-work refresh path.
6. `real-context-qa-and-final-verification`
   - Real-context fixtures/manual QA, full focused backend/Swift verification, strict OpenSpec validation, and task checkbox completion.

## Dispatch Recheck

Parallelization decision: sequential only.

Reasons:

- Swift groups share the same ViewModel, API client, protocol, panel UI, and monolithic test file.
- Backend adapter tests depend on the same study-intake/draft/compiler/scheduler contracts that the Swift client will consume.
- The final no-noise guarantees require cross-checking backend storage states and frontend refresh behavior.
- Running subagents in parallel would likely collide in `LearningAssistantViewModel.swift`, `AssistantPanelView.swift`, and `MalDazeTests/LearningAssistantTests.swift`.

## Protected Unrelated Dirty Paths

These paths are dirty before this checkpoint and are protected unrelated work for this apply unless a later task group explicitly blocks on an overlap:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

The current checkpoint may stage only:

- `openspec/add-initiate-implementation-control/evidence/redesign-add-initiate-ui/apply-planning.md`
- `openspec/add-initiate-implementation-control/evidence/redesign-add-initiate-ui/apply-task-groups.json`
- `openspec/add-initiate-implementation-control/evidence/manifest.json`
- `openspec/add-initiate-implementation-control/progress.md`
- `openspec/add-initiate-implementation-control/state.json`

## Next Step

Create the pre-apply checkpoint commit for this planning state, then on the next heartbeat start `openspec-apply-change redesign-add-initiate-ui` with the `session-adapter-and-api-contract` group under the required delegated TDD workflow.
