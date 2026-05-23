# Learning Assistant v2 Flow B Progress

## Current Status

- Phase: Flow B implementation
- Current item: ITEM-001 `study-plan-foundation`
- Current change: `introduce-study-plan-foundation`
- Current spec: `study-plan`
- Checkout strategy: current checkout only; worktrees are forbidden by automation instruction.

## Round 01 · 2026-05-23T14:50:55Z

### Git / Safety

- Start status contained only automation-owned Flow A files and the updated `learning-assistant-v2.md` from the previous heartbeat.
- No user-created overlapping changes were detected in this heartbeat.
- No implementation code was written.

### Flow A Gate

- `openspec/learning-assistant-v2-flow-a/final-readiness-report.md` says `Flow B readiness: PASS`.
- Controller state is `phase=flow-b`.

### V1 Observation Summary

- Swift UI currently has `AssistantPanelView`, `LearningAssistantViewModel`, `AssistantAPIClient`, and supporting learning views.
- The current add-resource flow calls `/api/ingest/start`, listens to SSE, displays an ingestion draft, supports A/B schedule options, and confirms with `/api/ingest/confirm`.
- The backend uses FastAPI + LangGraph ingestion agent. It has URL handlers, batch duration estimation, A/B scheduling, interrupt-based confirmation, and SQLite tables for resources, units, tasks, events, and system_state.
- This is a useful baseline but still v1-shaped: it is resource ingestion plus autonomous agents, not a v2 study-plan calendar model with guided clarification, review-state plan drafts, deterministic D24 scheduling, and user-owned confirmation semantics.
- App Use observation found multiple `com.maldaze.MalDaze` bundle instances. The current checkout app path `/Users/cpt/Public/MalDaze/DerivedData/Build/Products/Debug/MalDaze.app` can be targeted, but its visible window was blank/menu-bar-like during this heartbeat. A fuller UI verification should happen after implementation when the app has a known launch path.

### OpenSpec

- Created change scaffold: `openspec/changes/introduce-study-plan-foundation`.
- New capability: `study-plan`.
- Affected existing specs for context only: `learning-data-layer`, `material-ingestion`, `assistant-panel-ui`, `conversational-planner`, `daily-morning-agent`, `progress-feedback`, `weekly-review-agent`.
- Old v1 specs are not modified in this change; retirement should remain a later dedicated change after v2 coverage exists.
- Created proposal/design/spec/tasks for `introduce-study-plan-foundation`.
- Ran `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `openspec status --change introduce-study-plan-foundation --json` reports all required artifacts done and `isComplete=true`.

### Next Step

Before implementation, create a checkpoint commit in the current checkout, then enter `opsx:apply` with Superpowers subagent/TDD discipline.

## Round 02 · 2026-05-23T14:55:55Z

### Checkpoint

- Created checkpoint commit before implementation: `efd022d chore: checkpoint study plan openspec proposal`.
- Apply instructions reported 18 tasks, 0 complete at the start of the round.

### Tasks Completed

- Marked 1.1 complete based on strict OpenSpec validation coverage.
- Marked 1.2 complete after `openspec validate introduce-study-plan-foundation --strict` passed and `openspec status` reported all artifacts complete.

### Next Implementation Task

- Dispatch worker for 2.1/2.2: draft study project lifecycle tests and minimal backend implementation.

### 2.1 / 2.2 Result

- Worker completed draft lifecycle TDD.
- RED observed: missing `src.study_plan.lifecycle`, then review-driven duplicate-confirm regression.
- GREEN observed: `18 passed, 2 warnings` for lifecycle + resource management tests.
- Spec compliance review: APPROVED.
- Code quality review: initially CHANGES_REQUESTED for transaction safety, then APPROVED after fix.
- Tasks 2.1 and 2.2 are complete.

### Next Task

- 2.3 / 2.4: D24 deterministic scheduling over non-rest days and over-capacity/late status.

## Round 03 · 2026-05-23T15:16:25Z

### Safety

- Start status contained only automation-owned implementation artifacts from the current `introduce-study-plan-foundation` apply pass.
- No unrelated user-created overlapping changes were detected.
- Worktree usage remains forbidden; all work stayed in `/Users/cpt/Public/MalDaze`.

### 2.3 / 2.4 Result

- Worker completed D24 scheduling TDD.
- Initial RED observed: missing `src.study_plan.scheduling`.
- Spec review then found a real mismatch: first implementation was greedy next-fit packing, not D24 spread/average distribution.
- Worker added a review-driven RED test where four 60-minute tasks across four available days must land on four separate days, then fixed the scheduler.
- Re-review spec compliance: APPROVED.
- Code quality review: APPROVED, with non-blocking follow-ups for additional edge tests, return typing, mapping order contract, and `rest_weekdays` validation.

### Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py tests/test_resource_management.py -q`: `21 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/src/study_plan/scheduling.py`.
- Added `assistant_backend/tests/test_study_plan_scheduling.py`.
- Updated `openspec/changes/introduce-study-plan-foundation/tasks.md` to mark 2.3 and 2.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-001/tdd-scheduling-report.md`.

### Next Task

- 3.1 / 3.2: D30 guided clarification generation and fallback behavior.

## Round 04 · 2026-05-23T15:16:25Z

### 3.1 / 3.2 Result

- Worker completed D30 guided clarification TDD.
- RED observed: missing `src.study_plan.clarification`.
- GREEN observed: D30 helper returns a bounded clarification surface with recommended/default/unsure options, structure-vs-output final question behavior, skip response defaults, and low-calibration marker.
- Spec compliance review: APPROVED.
- Code quality review: APPROVED.
- Non-blocking follow-ups recorded: independent copies for skip response dictionaries, narrower material type matching, response schema typing, and review UI low-calibration propagation in later tasks.

### Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py tests/test_resource_management.py -q`: `26 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/src/study_plan/clarification.py`.
- Added `assistant_backend/tests/test_study_plan_clarification.py`.
- Updated `openspec/changes/introduce-study-plan-foundation/tasks.md` to mark 3.1 and 3.2 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-001/tdd-clarification-report.md`.

### Next Task

- 3.3 / 3.4: D29 decomposition pipeline stages and unknown-material fallback.

## Round 05 · 2026-05-23T15:16:25Z

### 3.3 / 3.4 Result

- Worker completed D29 decomposition pipeline TDD.
- RED observed: missing `src.study_plan.decomposition`.
- GREEN observed: minimal pipeline produces ordered draft tasks, preserves skipped-clarification/low-calibration metadata, uses generic fallback for unknown materials, returns user-visible failure for empty unknown material, preserves known durations, and uses deterministic duration defaults.
- Spec compliance review: APPROVED.
- Code quality review: APPROVED.
- Non-blocking follow-ups recorded: narrower material-type matching, structure fallback tests, deterministic tie-break tests, no-mutation tests, and API/lifecycle gating on `status == "draft_ready"`.

### Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`: `18 passed`.

### Files Added / Changed

- Added `assistant_backend/src/study_plan/decomposition.py`.
- Added `assistant_backend/tests/test_study_plan_decomposition.py`.
- Updated `openspec/changes/introduce-study-plan-foundation/tasks.md` to mark 3.3 and 3.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-001/tdd-decomposition-report.md`.

### Next Task

- 4.1 / 4.2: Swift decoding/API-client tests and study-plan draft flow client models.

## Round 06 · 2026-05-23T15:16:25Z

### 3.5 / 3.6 Router Blocker

- Swift API code quality review found a blocking contract issue: the new Swift client methods pointed at `/api/study-plan/...`, but the backend had no registered study-plan router.
- Added tasks 3.5 and 3.6 to make the missing backend HTTP surface explicit.
- Worker completed router TDD.
- RED observed: all `/api/study-plan` endpoints were 404.
- GREEN observed: start, clarification submit, duration update, cancel, and confirm endpoints work against the app lifespan test client.
- Spec review initially blocked on missing D24 existing-load status at the router layer.
- Worker added RED coverage for active task load causing over-capacity, then passed existing load into D24 scheduling without reshuffling draft placement.
- Code quality review then blocked on stale-state partial writes.
- Worker added RED coverage for draft state changing before persistence and wrapped clarification/duration writes in guarded transactions.
- Spec compliance re-review: APPROVED.
- Code quality re-review: APPROVED.

### 4.1 / 4.2 Swift API Result

- Worker completed Swift API model/client TDD.
- Initial RED observed: missing study-plan models and protocol/client methods.
- Spec review blocked because `startStudyPlan` returned only clarification and did not expose a follow-up `draftId`.
- Worker added RED coverage for `StudyPlanStartResponse { draft_id, clarification }` and changed protocol/client/mock/preview fixture to use it.
- Spec compliance re-review: APPROVED.
- Code quality review blocked until backend router tasks 3.5/3.6 were completed; after router review passed, this blocker is resolved.

### Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- Backend: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`: `27 passed, 2 warnings`.
- Swift targeted: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/AssistantModelDecodingTests -only-testing:MalDazeTests/LearningAssistantViewModelTests`: `** TEST SUCCEEDED **`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/src/routers/study_plan.py`.
- Added `assistant_backend/tests/test_study_plan_router.py`.
- Updated `assistant_backend/src/main.py`.
- Updated `MalDaze/LearningAssistant/AssistantAPIClient.swift`.
- Updated `MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift`.
- Updated `MalDaze/LearningAssistant/AssistantPanelView.swift`.
- Updated `MalDazeTests/LearningAssistantTests.swift`.
- Added router and Swift API evidence reports.

### Next Task

- 4.3 / 4.4: view-model state transitions for URL intake, clarification skip/answer flow, review-state duration edits, cancel, and explicit confirmation.

## Round 07 · 2026-05-23T17:21:43Z

### 4.3 / 4.4 Swift ViewModel Result

- Worker completed ViewModel TDD for the study-plan draft flow.
- Initial RED observed: missing ViewModel state and methods for URL intake, guided clarification, review draft edit/cancel, and explicit confirm.
- GREEN observed: ViewModel stores draft id and clarification after URL intake, submits or skips clarification into review-state drafts, edits task duration only in review state, cancels without refreshing dashboard, and confirms only after explicit review.
- Review-driven fixes added:
  - start failure preserves an existing review draft,
  - duplicate confirm is ignored while confirm is in flight,
  - duration edit and confirm require a review-ready local draft,
  - study-plan draft mutations share a unified busy guard,
  - in-flight tests use a deterministic `NSLock`-protected continuation gate instead of `Task.yield()`.
- Spec compliance review: APPROVED.
- Final code quality review: APPROVED.

### Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- Backend: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`: `27 passed, 2 warnings`.
- Swift targeted: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `git diff --check`: PASS.
- `openspec instructions apply --change introduce-study-plan-foundation --json`: `16/20` tasks complete; remaining tasks are 5.1 through 5.4.

### Files Added / Changed

- Updated `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`.
- Updated `MalDazeTests/LearningAssistantTests.swift`.
- Updated `openspec/changes/introduce-study-plan-foundation/tasks.md` to mark 4.3 and 4.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-001/tdd-swift-viewmodel-report.md`.

### Next Task

- 5.1 / 5.2: guided clarification card and draft review UI controls for US-1 through US-5.

## Round 08 · 2026-05-23T17:52:11Z

### 5.1 / 5.2 Swift UI Result

- Worker completed Swift UI TDD for the v2 study-plan intake/review surface.
- RED observed: source-level UI tests failed because the add-resource tab still used the old ingestion flow and no `StudyPlanIntakeView`, guided clarification card, or draft review controls existed.
- GREEN observed: `.addResource` now routes to `StudyPlanIntakeView`, with URL intake, required deadline, daily capacity, guided clarification submit/skip, draft review, duration edit, cancel, and explicit confirm controls.
- Spec compliance review: APPROVED.
- Code quality review initially requested changes for two blockers:
  - clarification and draft duration local state could leak across draft identities,
  - the visible default deadline was blocked by a hidden `hasSelectedDeadline` gate.
- Fixes added:
  - draft-identity reset for clarification answers,
  - duration identity reset using `draft.id` plus `orderIndex:estimatedMinutes`,
  - removal of the hidden deadline gate so the default DatePicker value is usable.
- Final code quality re-review: APPROVED.

### Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- Backend: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`: `27 passed, 2 warnings`.
- Swift targeted: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `git diff --check`: PASS.

### Files Added / Changed

- Updated `MalDaze/LearningAssistant/AssistantPanelView.swift`.
- Updated `MalDazeTests/LearningAssistantTests.swift`.
- Updated `openspec/changes/introduce-study-plan-foundation/tasks.md` to mark 5.1, 5.2, and 5.3 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-001/tdd-swift-ui-report.md`.

### Next Task

- 5.4: use Computer Use/App Use on the current checkout app path to verify URL intake, clarification, draft review, duration edit, cancel, and confirm behavior; save evidence under Flow B.

## Round 09 · 2026-05-23T18:08:54Z

### 5.4 Current-Checkout App Verification

- Built and launched `/Users/cpt/Public/MalDaze/DerivedData/Build/Products/Debug/MalDaze.app`.
- Targeted Computer Use at the current checkout app path because another `com.maldaze.MalDaze` bundle instance was also running from Xcode's default DerivedData path.
- Verified the v2 `添加资料` surface:
  - URL intake,
  - required deadline with usable default,
  - daily capacity stepper,
  - guided clarification,
  - draft review,
  - duration edit,
  - cancel,
  - explicit confirm.
- App verification found a radio-selection regression in the clarification card. The issue was fixed under TDD by changing UI selection identity from answer value to option id while still submitting answer values.
- Rebuilt and reverified that selecting `Some familiarity` leaves only that radio option selected in its group.
- Verified duration update by changing the first draft task from `45` to `50` minutes and observing the persisted review-state update.
- Verified cancel by cancelling that draft and returning to intake without active task creation for draft `id=2`.
- Verified confirm by creating a rough plan, seeing the low-calibration warning, confirming it, and observing local backend resource/task creation for resource `id=6`.

### Evidence

- Added `openspec/learning-assistant-v2-flow-b/evidence/item-001/app-verification/app-verification.md`.
- Backend/API evidence:
  - `GET /api/resources` includes active `study_project` resource `id=6`, title `Course V2`, URL `https://example.com/course-v2`.
  - SQLite shows draft `id=2` cancelled and draft `id=3` confirmed.
  - SQLite shows active tasks `136` and `137` for resource `id=6`.
- Screenshot note: `screencapture` failed to create an image from the desktop rect/display in this environment, so the evidence is textual accessibility/API evidence.

### Verification

- Current-checkout app build: `** BUILD SUCCEEDED **`.
- Swift targeted tests after app-discovered regression fix: `** TEST SUCCEEDED **`.
- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `openspec instructions apply --change introduce-study-plan-foundation --json`: `20/20` tasks complete, `state=all_done`.
- Backend: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`: `27 passed, 2 warnings`.
- Swift targeted: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `git diff --check`: PASS.

### Item Status

- Marked task 5.4 complete.
- Marked ITEM-001 `study-plan-foundation` complete.
- Next item: ITEM-002 `study-views`.

## Round 10 · 2026-05-23T18:18:56Z

### Safety

- Start status contained only automation-owned ITEM-001 implementation/evidence files plus Flow B state files.
- No unrelated user-created overlapping changes were detected.
- No implementation code was written in this round.
- Worktree usage remains forbidden; all work stayed in `/Users/cpt/Public/MalDaze`.

### ITEM-002 Exploration

- Read `openspec/learning-assistant-v2.md` sections for US-6, US-7, US-12, US-13, US-14, and related completion/archive notes.
- Ran `openspec list --specs`; existing v1 learning specs remain present, while v2 `study-plan` is still in the completed active change because it has not been archived.
- Inspected current backend and Swift learning assistant surfaces:
  - `/api/today-briefing` is v1 morning-agent/cached-summary shaped.
  - `/api/resources` returns active resources only.
  - `complete_task` updates task/unit/resource state but needs idempotency and v2 view guarantees.
  - Swift home/资料进度 already have useful UI pieces but no first-class calendar or completed history view.
- Used Computer Use on the current checkout app path:
  - Home shows a Today-like summary and today's task list.
  - 资料进度 shows active resource/project cards, including ITEM-001's `Course V2`.
  - No Calendar view or completed/archive history is exposed.

### Evidence

- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/v1-observation.md`.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/gap-analysis.md`.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/openspec-review.md`.

### OpenSpec

- Created change `introduce-study-views`.
- New capability: `study-views`.
- Affected specs: new `study-views`; old v1 learning specs are context-only and not modified.
- Created:
  - `openspec/changes/introduce-study-views/proposal.md`
  - `openspec/changes/introduce-study-views/design.md`
  - `openspec/changes/introduce-study-views/specs/study-views/spec.md`
  - `openspec/changes/introduce-study-views/tasks.md`
- Marked tasks 1.1 and 1.2 complete because strict validation passed and exploration evidence exists.

### Verification

- `openspec validate introduce-study-views --strict`: PASS.
- `openspec status --change introduce-study-views --json`: required artifacts done, `isComplete=true`.
- `openspec instructions apply --change introduce-study-views --json`: `22` tasks total, `2` complete, state `ready`.
- `git diff --check`: PASS.

### Next Task

- Before entering `opsx:apply`, create a checkpoint commit in the current checkout if no unrelated user changes are present.
- Then begin backend TDD for tasks 2.1 and 2.2.
