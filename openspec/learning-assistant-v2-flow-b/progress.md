# Learning Assistant v2 Flow B Progress

## Current Status

- Phase: Flow B implementation
- Current item: ITEM-003 `study-plan-adjustment`
- Current change: pending OpenSpec proposal
- Current spec: pending `study-plan-adjustment`
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

## Round 11 · 2026-05-23T18:25:26Z

### Checkpoint

- Created checkpoint commit before `opsx:apply`: `92cb29d chore: checkpoint study plan foundation and views spec`.
- Excluded runtime SQLite files `assistant_backend/learning.db-wal` and `assistant_backend/learning.db-shm` from the checkpoint.

### 2.1 / 2.2 Result

- Worker completed backend Today Study View TDD.
- RED observed: `/api/study-views/today` returned `404 Not Found`.
- GREEN observed:
  - deterministic `GET /api/study-views/today`,
  - SQLite-backed query over `tasks`, `resources`, and `units`,
  - filters for today's active `study_project` tasks,
  - excludes completed/archived projects, non-study resources, and non-today tasks,
  - does not invoke the morning agent or LLM.
- Spec compliance review: APPROVED.
- Code quality review: APPROVED.
- Non-blocking review notes:
  - future tests can guard direct import of `src.agents.morning_agent.run_morning_agent`,
  - unit join can be hardened with `u.resource_id = t.resource_id` if dirty data becomes a concern.

### Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py -q`: `1 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_lifecycle.py tests/test_resource_management.py -q`: `27 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/tests/test_study_views_today.py`.
- Added `assistant_backend/src/routers/study_views.py`.
- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/main.py`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 2.1 and 2.2 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-backend-today-view-report.md`.

### Next Task

- 2.3 / 2.4: task completion idempotency, progress update, unit completion, and v2 view refresh facts.

### 2.3 / 2.4 Result

- Worker completed backend task completion TDD.
- RED observed:
  - duplicate completion produced a new `completed_at` instead of preserving the persisted completion fact,
  - missing task IDs had no deterministic 404/no-event guarantee,
  - same-unit multiple task completion could double-count unit progress,
  - the v2 Today view refresh path after completion needed direct coverage.
- Initial spec review requested changes because the first implementation attempted to auto-complete/archive the project in this slice, which belongs to 2.9 / 2.10.
- GREEN observed:
  - completion runs in one SQLite transaction,
  - duplicate completion is idempotent,
  - unknown task completion returns 404 and writes no fake event,
  - linked units complete once without double-counting `completed_units`,
  - resource `actual_minutes_total` accumulates non-duplicate task minutes,
  - Today view reflects the persisted `completed_at` after completion,
  - project/resource auto-completion remains deferred to 2.9 / 2.10.
- Second-pass spec compliance review: APPROVED.
- Second-pass code quality review: APPROVED.

### Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_completion.py -q`: `3 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_resource_management.py tests/test_study_plan_lifecycle.py -q`: `19 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/tests/test_study_views_completion.py`.
- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/routers/tasks.py`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 2.3 and 2.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-backend-completion-report.md`.

### Next Task

- 2.5 / 2.6: Project Overview active summaries and completed history.

### 2.5 / 2.6 Result

- Worker completed backend Project Overview TDD.
- Initial RED observed: `/api/study-views/projects` returned `404 Not Found`.
- GREEN observed:
  - deterministic `GET /api/study-views/projects`,
  - `active_projects` and `completed_projects` sections,
  - active study project summaries with title, completed count, total count, ratio, target minutes, actual minutes, deadline, and status,
  - completed study project history remains visible,
  - archived projects and non-study resources are excluded,
  - task completion refreshes overview from persisted facts.
- Review-driven repairs:
  - progress now uses task completed/total facts rather than unit status or stale resource cache,
  - same-unit multiple-task projects no longer appear 100% complete after only one task,
  - no-actual completion persists target fallback to `tasks.actual_minutes`,
  - zero-task projects report task-derived `0/0` instead of stale `resources.total_units`,
  - tests no longer freeze final-task no-auto-archive behavior that belongs to 2.9 / 2.10.
- Spec compliance review: APPROVED.
- Code quality review: requested fixes twice; both rounds were resolved before task completion.

### Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_project_overview.py tests/test_study_views_completion.py -q`: `9 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_resource_management.py -q`: `14 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/tests/test_study_views_project_overview.py`.
- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/routers/study_views.py`.
- Updated `assistant_backend/tests/test_study_views_completion.py`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 2.5 and 2.6 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-backend-project-overview-report.md`.

### Next Task

- 2.7 / 2.8: Calendar load aggregation and read-only load route.

### 2.7 / 2.8 Result

- Worker completed backend Calendar Load TDD.
- RED observed: `/api/study-views/calendar?start=...&end=...` returned `404 Not Found`.
- GREEN observed:
  - deterministic `GET /api/study-views/calendar`,
  - inclusive date-window buckets,
  - one bucket per day, including empty days,
  - active `study_project` tasks only,
  - scheduled task count, total target minutes, completed task count, and over-capacity flag,
  - configured daily capacity from `system_state.daily_capacity_min`, fallback `60`,
  - read-only behavior with no events or task date mutations.
- Spec compliance review: APPROVED.
- Code quality review: APPROVED.
- Non-blocking review notes were recorded in evidence; no blocker remains for 2.7 / 2.8.

### Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_calendar.py -q`: `3 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_study_views_completion.py tests/test_study_views_project_overview.py tests/test_resource_management.py -q`: `23 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Added `assistant_backend/tests/test_study_views_calendar.py`.
- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/routers/study_views.py`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 2.7 and 2.8 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-backend-calendar-report.md`.

### Next Task

- 2.9 / 2.10: automatic completed project archive/history when the last unfinished task completes.

### 2.9 / 2.10 Result

- Worker completed backend automatic completed-project archive TDD.
- RED observed: completing the final active `study_project` task left the project resource `active`.
- GREEN observed:
  - final active `study_project` task completion transitions the resource to `completed`,
  - completed project disappears from active Today and active Project Overview,
  - completed project appears in Project Overview completed history,
  - `resource_completed` event is inserted once with `source: task_completion`,
  - duplicate completion does not duplicate `task_completed` or `resource_completed`,
  - non-study resources do not auto-complete through this path,
  - resource, unit, task, and event rows remain persisted.
- Spec compliance review: APPROVED.
- Code quality review: APPROVED.

### Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_completion.py tests/test_study_views_project_overview.py tests/test_study_views_today.py -q`: `12 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_calendar.py tests/test_resource_management.py -q`: `16 passed, 2 warnings`.
- `git diff --check`: PASS.

### Files Added / Changed

- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/tests/test_study_views_completion.py`.
- Updated `assistant_backend/tests/test_study_views_project_overview.py`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 2.9 and 2.10 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-backend-auto-archive-report.md`.

### Next Task

- 3.1 / 3.2: Swift API models and client methods for Today, Project Overview, Calendar Load, and task completion refresh payloads.

### 3.1 / 3.2 Result

- Worker completed Swift API model/client TDD.
- Initial RED observed: Swift tests failed because `StudyTodayView`, `StudyProjectOverview`, and `StudyCalendarLoad` were missing.
- Review-driven RED observed:
  - `TaskCompletionResult` was missing,
  - `completeTask` discarded the backend completion payload,
  - Calendar query construction lacked real client coverage,
  - AssistantPanel preview fixture still had the old `completeTask -> Void` signature.
- GREEN observed:
  - v2 study view Swift models added,
  - concrete client and protocol expose v2 fetch methods,
  - `completeTask` returns decoded `TaskCompletionResult`,
  - URLProtocol-backed tests cover method, path, query, request body, and decode behavior,
  - Calendar query is built with `URLQueryItem`,
  - preview fixture conforms to the new completion result signature.
- Spec compliance review: APPROVED.
- Code quality review: requested fixes twice; both rounds were resolved before task completion.

### Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `git diff --check`: PASS.

### Files Added / Changed

- Updated `MalDaze/LearningAssistant/AssistantAPIClient.swift`.
- Updated `MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift`.
- Updated `MalDaze/LearningAssistant/AssistantPanelView.swift` preview fixture.
- Updated `MalDazeTests/LearningAssistantTests.swift`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 3.1 and 3.2 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-swift-api-client-report.md`.

### Next Task

- 3.3 / 3.4: ViewModel state transitions for v2 Today, task completion refresh, Project Overview active/history, and read-only Calendar load.

### 3.3 / 3.4 Result

- Worker completed Swift ViewModel TDD for v2 study views.
- Initial RED observed: `LearningAssistantViewModel` lacked first-class `studyTodayView`, `studyProjectOverview`, `studyCalendarLoad`, and `fetchStudyCalendarLoad(start:end:)`.
- GREEN observed:
  - default dashboard refresh uses dedicated v2 Today and Project Overview APIs,
  - v2 ViewModel state stores Today, Project Overview active/completed history, and read-only Calendar load,
  - task completion refreshes persisted Today and Project Overview facts,
  - `TodayBriefing.highlights` is no longer the v2 dashboard source of truth,
  - Calendar load remains read-only ViewModel state.
- Code quality review requested fixes for Calendar stale overwrite, project-title mapping, and v2 fixture coverage.
- Review-driven RED observed: older Calendar range could overwrite a newer range, and visible task mapping preferred resource title when both project/resource titles existed.
- Repair added latest-request-wins Calendar sequencing, project-title-first visible task mapping, and v2-only fixtures for the relevant ViewModel dashboard/concurrency/completion tests.
- Spec compliance review: APPROVED.
- Code quality re-review: APPROVED.

### Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `openspec validate introduce-study-views --strict`: PASS.
- `git diff --check`: PASS.

### Files Added / Changed

- Updated `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`.
- Updated `MalDazeTests/LearningAssistantTests.swift`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 3.3 and 3.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-swift-viewmodel-report.md`.

### Next Task

- 4.1 / 4.2: presentation tests and minimal Swift UI for first-class Today, Project Overview, completed history, and read-only Calendar load.

### 4.1 / 4.2 / 4.3 Result

- Worker completed Swift UI TDD for first-class v2 study views.
- Initial RED observed:
  - source tests failed because the panel did not expose first-class Project Overview and Calendar tabs,
  - `ProjectOverviewView` and `StudyCalendarLoadView` were missing,
  - Today did not surface v2 persisted Today facts,
  - Calendar read-only behavior was not yet locked by tests.
- GREEN observed:
  - Today, Project Overview, and Calendar are available as first-class bottom navigation views,
  - Today displays v2 persisted facts,
  - Project Overview displays active projects, completed history, progress, status, deadline, and minute facts,
  - Calendar displays read-only daily load facts.
- Code quality review requested fixes for Calendar default range, in-flight fetch dedupe, Project Overview progress clamping, and status/deadline formatting.
- Repair-driven RED observed all four review blockers before implementation.
- Repair added a 28-day default Calendar window, loaded/in-flight request guard, shared clamped progress helper, non-finite guard, Chinese status labels, and `无截止日期` fallback.
- Spec compliance re-review: APPROVED.
- Code quality re-review: APPROVED.

### Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests`: `** TEST SUCCEEDED **`.
- `openspec validate introduce-study-views --strict`: PASS.
- `git diff --check`: PASS.

### Files Added / Changed

- Updated `MalDaze/LearningAssistant/AssistantPanelView.swift`.
- Updated `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`.
- Updated `MalDazeTests/LearningAssistantTests.swift`.
- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 4.1, 4.2, and 4.3 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/tdd-swift-ui-report.md`.

### Next Task

- 5.1 / 5.2 / 5.3: final backend/Swift test verification, OpenSpec validation, and Computer Use/App Use verification in the current checkout.

### 5.1 / 5.2 Partial Final Verification

- Relevant backend tests passed.
- Relevant Swift ViewModel, model/client decoding, and UI source tests passed.
- OpenSpec strict validation passed.
- `git diff --check` passed.
- App Use verification was attempted against the current checkout app path, but Computer Use could not attach to a key dashboard content window for the menu-bar/desktop-pet panel.
- Supplemental AX/CGWindow observation confirmed the current checkout app process was running and exposing visible pet/menu windows.
- 5.3 remains open pending a reliable current-checkout App Use path.

### Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_study_views_completion.py tests/test_study_views_project_overview.py tests/test_study_views_calendar.py tests/test_resource_management.py -q`: `28 passed, 2 warnings`.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests -only-testing:MalDazeTests/LearningAssistantUISourceTests`: `** TEST SUCCEEDED **`.
- `openspec validate introduce-study-views --strict`: PASS.
- `git diff --check`: PASS.

### Files Added / Changed

- Updated `openspec/changes/introduce-study-views/tasks.md` to mark 5.1 and 5.2 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-002/final-tests-and-app-use-attempt.md`.

### Next Task

- 5.3: complete Computer Use/App Use verification for the current checkout dashboard, or mark blocked if older running `MalDaze.app` instances prevent safe isolation without user approval.

### 5.3 Blocked

- Current checkout app was launched from `/Users/cpt/Library/Developer/Xcode/DerivedData/MalDaze-bpwxiacqyfwxjndsvopwqmqitret/Build/Products/Debug/MalDaze.app`.
- The current checkout process exposed a dashboard-sized CG window after an in-process dashboard notification.
- Computer Use still returned `cgWindowNotFound` for the current app.
- System-wide AX hit testing over the dashboard area returned `loginwindow` elements, and screenshot capture was black.
- Root blocker: the desktop/session is currently locked or hidden behind the login window, so Computer Use/App Use cannot observe app pixels or the app accessibility tree.
- Task 5.3 remains incomplete until the user unlocks the session or explicitly approves an alternate verification method.

## Round 15 · 2026-05-24T02:57:10Z

### 5.3 App Use Verification Result

- The earlier loginwindow blocker was gone; the current checkout app could render a dashboard-sized CG window.
- Current checkout app path verified: `/Users/cpt/Library/Developer/Xcode/DerivedData/MalDaze-bpwxiacqyfwxjndsvopwqmqitret/Build/Products/Debug/MalDaze.app`.
- Computer Use could attach to `MalDaze`, but the app exposed the pet stage as the key accessibility window. The dashboard verification therefore used the current checkout dashboard window plus accessibility actions against the current checkout PID.
- Real user DB screenshots verified first-class Today, Project Overview, and Calendar tabs without mutating user task state.
- A temporary database was launched via `DB_PATH=/tmp/maldaze-study-views-appuse.db` to safely click the task completion control without touching user data.
- Temporary DB verification showed:
  - Today before completion contained `App Use completion task`.
  - Pressing the actual completion button moved Today into the all-tasks-completed state.
  - Project Overview refreshed to `1/2` units, `50%`, and `35` actual minutes.
  - Calendar refreshed the current day completed count to `1`.
  - Direct SQLite confirmation showed task `9701` completed, unit status `completed`, resource completed units `1`, and resource actual minutes `35`.

### Evidence

- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-verification.md`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/dashboard-home.png`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/dashboard-project-overview.png`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/dashboard-calendar.png`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/tempdb-home-before.png`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/tempdb-home-after-complete.png`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/tempdb-project-overview-after-complete.png`
- `openspec/learning-assistant-v2-flow-b/evidence/item-002/app-use-screenshots/tempdb-calendar-after-complete.png`

### ITEM-002 Completion

- Marked OpenSpec task 5.3 complete.
- Marked ITEM-002 `study-views` complete in the Flow B item queue.
- Next item: ITEM-003 `study-plan-adjustment`.
- Next step: start ITEM-003 with v1 observation, gap analysis, and OpenSpec explore/propose before any implementation.

## Round 16 · 2026-05-24T03:00:05Z

### ITEM-003 Explore / Proposal

- Restored controller state: `phase=flow-b`, `current_item=study-plan-adjustment`.
- Start status contained automation-owned ITEM-002 files and no detected unrelated user edits.
- No implementation code was written.
- Affected spec decision:
  - new v2 spec id: `study-plan-adjustment`;
  - existing v1 specs are not modified in this change;
  - completed-but-unarchived context changes are `introduce-study-plan-foundation` and `introduce-study-views`.

### V1 / Current-State Observation

- Backend has a single-task `reschedule_task` helper but no v2 same-project cascade, no auto-roll counters, no active deadline edit endpoint, no add/delete active task endpoint, no rest-day settings/cascade, and no route-A dialogue preview/apply boundary.
- Calendar can already compute over-capacity facts, but Project Overview does not expose expected-late project state.
- Swift has first-class Today, Project Overview, Calendar, and Adjust Plan tabs, but Adjust Plan is still the generic chat surface. App Use observation captured this at `openspec/learning-assistant-v2-flow-b/evidence/item-003/app-use-screenshots/adjust-plan-current.png`.

### OpenSpec

- Created change: `openspec/changes/introduce-study-plan-adjustment`.
- Created proposal, design, spec delta, and tasks.
- `openspec validate introduce-study-plan-adjustment --strict`: PASS.
- `openspec status --change introduce-study-plan-adjustment --json`: complete/apply-ready.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks, 3 complete after proposal readiness tasks were marked.

### Readiness

- Readiness review: PASS with caution.
- Scope is large but coherent around one invariant: user action plus explicit mechanical rules, no hidden repair.
- D26/D27 rest-day handling is included because automation scoped this item to D20-D28.
- Smart-mode proposal generation remains deferred to ITEM-004.
- Recommended next step: create a checkpoint commit in the current checkout, then enter `opsx:apply` for `introduce-study-plan-adjustment`.

## Round 17 · 2026-05-24T03:13:05Z

### ITEM-003 2.1-2.4 Backend Schema / Red-State Facts

- Restored controller state: `phase=flow-b`, `current_item=study-plan-adjustment`.
- Current checkout only; no worktree was created or used.
- Existing checkpoint before apply: `c9da6ff chore: checkpoint study views and adjustment proposal`.
- Subagent TDD implementation completed OpenSpec tasks 2.1-2.4:
  - task auto-roll metadata columns and existing DB migration support;
  - default rest-day system state keys;
  - Project Overview `expected_late` facts for active study projects;
  - Calendar over-capacity regression coverage confirming view reads do not move task dates.

### Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: PASS.
- P3 follow-up from review: `assistant_backend/tests/test_study_plan_adjustment_schema.py` is new/untracked and must be included in the eventual implementation commit.
- No blocking or critical issues found for the 2.1-2.4 slice.

### Verification

- `assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_schema.py assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q`: `13 passed, 2 warnings`.
- `openspec validate introduce-study-plan-adjustment --strict`: PASS.
- `git diff --check`: PASS.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks total, 7 complete, 30 remaining.

### Files Added / Changed

- Updated `assistant_backend/src/db/schema.py`.
- Updated `assistant_backend/src/db/init.py`.
- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/tests/test_study_views_project_overview.py`.
- Updated `assistant_backend/tests/test_study_views_calendar.py`.
- Added `assistant_backend/tests/test_study_plan_adjustment_schema.py`.
- Updated `openspec/changes/introduce-study-plan-adjustment/tasks.md` to mark 2.1-2.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-003/tdd-backend-schema-red-states-report.md`.

### Next Task

- Continue `opsx:apply` for ITEM-003 with tasks 3.1 and 3.2: idempotent unfinished-task rollover into the current local day, route/service implementation, auto-roll counters, and event persistence.

## Round 18 · 2026-05-24T03:24:05Z

### ITEM-003 3.1-3.2 Rollover Service / Route

- Restored controller state: `phase=flow-b`, `current_item=study-plan-adjustment`.
- Current checkout only; no worktree was created or used.
- Continued from checkpoint `c9da6ff` and existing ITEM-003 implementation state.
- Subagent TDD implementation completed OpenSpec tasks 3.1-3.2:
  - `POST /api/study-plan-adjustment/rollover`;
  - active study-project unfinished tasks scheduled before today roll into today;
  - same-project later tasks are not cascaded;
  - completed tasks, completed projects, and non-study resources are excluded;
  - `auto_roll_days` and `last_auto_rolled_at` are persisted;
  - `study_task_rolled_over` events are recorded only for actual rollovers;
  - repeated same-day calls are idempotent.

### Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: PASS.
- No P0/P1/P2 issues found for the 3.1-3.2 slice.
- P3 residual risks:
  - rollover tests and route each call `date.today()`, so a test crossing local midnight could become flaky;
  - `rollover_unfinished_study_tasks` expects a connection with `aiosqlite.Row` row factory, which is true for the route path but not enforced for direct helper callers;
  - idempotency coverage is sequential, not a true concurrent POST stress test.

### Verification

- `assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rollover.py assistant_backend/tests/test_study_plan_adjustment_schema.py assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q`: `15 passed, 2 warnings`.
- `openspec validate introduce-study-plan-adjustment --strict`: PASS.
- `git diff --check`: PASS.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks total, 9 complete, 28 remaining.

### Auto Commit

- Commit: `adff33a feat: add study plan adjustment rollover foundation`.
- Scope: verified ITEM-003 backend schema/fact helpers plus rollover service/route through OpenSpec tasks 2.1-3.2.
- Pre-commit checks: related backend tests, `openspec validate introduce-study-plan-adjustment --strict`, `git diff --check`, Spec Compliance Review, and Code Quality Review all passed.

### Files Added / Changed

- Updated `assistant_backend/src/db/queries.py`.
- Added `assistant_backend/src/routers/study_plan_adjustment.py`.
- Updated `assistant_backend/src/main.py`.
- Added `assistant_backend/tests/test_study_plan_adjustment_rollover.py`.
- Updated `openspec/changes/introduce-study-plan-adjustment/tasks.md` to mark 3.1 and 3.2 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-003/tdd-rollover-report.md`.

### Next Task

- Continue `opsx:apply` for ITEM-003 with tasks 3.3 and 3.4: Today rolled-day count payload, threshold badge facts, and completion clearing active rolled badge state.

## Round 19 · 2026-05-24T03:39:05Z

### ITEM-003 3.3-3.4 Today Rolled Badge Payload

- Restored controller state: `phase=flow-b`, `current_item=study-plan-adjustment`.
- Current checkout only; no worktree was created or used.
- Auto-commit rule was active this round.
- Subagent TDD implementation completed OpenSpec tasks 3.3-3.4:
  - Today view runs idempotent rollover before reading Today facts;
  - Today task payload includes `rolled_day_count` and `show_rolled_badge`;
  - badge threshold is `rolled_day_count >= 3`;
  - task completion resets `auto_roll_days` and `last_auto_rolled_at`;
  - existing Today fields remain additive-compatible.

### Review Gates

- Spec Compliance Review: PASS.
- Code Quality Review: PASS.
- No P0/P1 blocker found.
- P2 residual risk: `GET /api/study-views/today` now calls rollover, which enters a SQLite `BEGIN IMMEDIATE` transaction even when no overdue task exists. This matches the current spec/design but may create avoidable lock contention; later optimization can add candidate short-circuiting.
- P3 coverage gaps: no route-level double-GET idempotency test, and no duplicate-completion stale-marker test for the already-completed branch.

### Verification

- `assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_views_today.py assistant_backend/tests/test_study_views_completion.py assistant_backend/tests/test_study_plan_adjustment_rollover.py -q`: `11 passed, 2 warnings`.
- `openspec validate introduce-study-plan-adjustment --strict`: PASS.
- `git diff --check`: PASS.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks total, 11 complete, 26 remaining.

### Auto Commit

- Commit: `511077b feat: expose study plan rollover badges`.
- Scope: verified ITEM-003 Today rolled-day count/badge payload and completion rollover-marker reset through OpenSpec tasks 3.3-3.4.
- Pre-commit checks: related backend tests, `openspec validate introduce-study-plan-adjustment --strict`, `git diff --check`, Spec Compliance Review, and Code Quality Review all passed.

### Files Added / Changed

- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/routers/study_views.py`.
- Updated `assistant_backend/tests/test_study_views_today.py`.
- Updated `assistant_backend/tests/test_study_views_completion.py`.
- Updated `openspec/changes/introduce-study-plan-adjustment/tasks.md` to mark 3.3 and 3.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-003/tdd-today-rolled-badge-report.md`.

### Next Task

- Continue `opsx:apply` for ITEM-003 with tasks 4.1 and 4.2: active unfinished task date move with same-project later-task cascade, no cross-project movement, past-date rejection, event persistence, and rollover reset.

## Round 20 · 2026-05-24T04:16:05Z

### ITEM-003 4.1-4.2 Manual Move Cascade

- Restored controller state: `phase=flow-b`, `current_item=study-plan-adjustment`.
- Current checkout only; no worktree was created or used.
- Subagent TDD implementation completed OpenSpec tasks 4.1-4.2:
  - `POST /api/study-plan-adjustment/tasks/{task_id}/move`;
  - selected active unfinished study task moves to the requested date;
  - unfinished later same-project tasks cascade by the same date delta;
  - earlier same-project tasks, completed tasks, and other projects are not moved;
  - target dates before today are rejected with no mutation;
  - cascade results that would move any affected task before today are rejected with no mutation;
  - affected tasks reset rollover markers and receive `user_adjusted_at`;
  - `study_task_moved` event evidence records selected and affected task date changes with source `manual_move`.

### Review Gates

- Spec Compliance Review: PASS.
- Initial Code Quality Review: PASS with one P2.
- P2 fixed with TDD: cascade results before today now reject the whole move and roll back before updates/events.
- Manual Move Re-review: PASS with no P0/P1/P2/P3 findings.

### Verification

- `assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py assistant_backend/tests/test_study_plan_adjustment_rollover.py assistant_backend/tests/test_study_views_today.py -q`: `8 passed, 2 warnings`.
- `openspec validate introduce-study-plan-adjustment --strict`: PASS.
- `git diff --check`: PASS.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks total, 13 complete, 24 remaining.

### Auto Commit

- Commit: `5850eb5 feat: add study plan manual move cascade`.
- Scope: verified ITEM-003 manual task date move cascade through OpenSpec tasks 4.1-4.2.
- Pre-commit checks: related backend tests, `openspec validate introduce-study-plan-adjustment --strict`, `git diff --check`, Spec Compliance Review, Code Quality Review, and P2 fix re-review all passed.

### Files Added / Changed

- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/routers/study_plan_adjustment.py`.
- Added `assistant_backend/tests/test_study_plan_adjustment_move.py`.
- Updated `openspec/changes/introduce-study-plan-adjustment/tasks.md` to mark 4.1 and 4.2 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-003/tdd-manual-move-report.md`.

### Next Task

- Continue `opsx:apply` for ITEM-003 with tasks 4.3 and 4.4: active project deadline edit that recalculates expected-late state without moving tasks.

## Round 21 · 2026-05-24T04:36:05Z

### ITEM-003 4.3-4.4 Project Deadline Edit

- Restored controller state: `phase=flow-b`, `current_item=study-plan-adjustment`.
- Current checkout only; no worktree was created or used.
- Subagent TDD implementation completed OpenSpec tasks 4.3-4.4:
  - `POST /api/study-plan-adjustment/projects/{project_id}/deadline`;
  - active study-project deadlines update `resources.deadline`;
  - existing task `scheduled_date` values are not moved;
  - Project Overview recalculates `expected_late` from persisted unfinished task facts after deadline changes;
  - `study_project_deadline_updated` events record project id, old/new deadline, and source `deadline_edit`;
  - completed projects, non-study resources, and missing projects are rejected safely;
  - missing, `null`, and empty deadline payloads are rejected with an explanation that v2 active plans require deadlines for late-state detection.

### Review Gates

- Initial Spec Compliance Review: FAIL with one P1.
- P1 fixed with TDD: clearing/missing deadline now returns explanatory 422 text and remains non-mutating.
- Spec Compliance Re-review: PASS.
- Code Quality Review: APPROVED with no P0/P1/P2 issues.
- P3 residual risks:
  - business error paths perform an explicit rollback before the broad exception rollback, matching adjacent query style but remaining slightly redundant;
  - unknown project 404 is implemented but not separately covered by a dedicated no-event regression test.

### Verification

- `assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py assistant_backend/tests/test_study_views_project_overview.py -q`: `12 passed, 2 warnings`.
- `openspec validate introduce-study-plan-adjustment --strict`: PASS.
- `git diff --check`: PASS.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks total, 15 complete, 22 remaining.

### Auto Commit

- Commit: `dd9dce4 feat: add study plan deadline editing`.
- Scope: verified ITEM-003 project deadline editing through OpenSpec tasks 4.3-4.4.
- Pre-commit checks: related backend tests, `openspec validate introduce-study-plan-adjustment --strict`, `git diff --check`, Spec Compliance Review plus re-review, and Code Quality Review all passed.

### Files Added / Changed

- Updated `assistant_backend/src/db/queries.py`.
- Updated `assistant_backend/src/routers/study_plan_adjustment.py`.
- Added `assistant_backend/tests/test_study_plan_adjustment_deadline.py`.
- Updated `openspec/changes/introduce-study-plan-adjustment/tasks.md` to mark 4.3 and 4.4 complete.
- Added `openspec/learning-assistant-v2-flow-b/evidence/item-003/tdd-deadline-edit-report.md`.

### Next Task

- Continue `opsx:apply` for ITEM-003 with tasks 5.1 and 5.2: inserting an active project task on a selected date with no cascade and red-state recalculation.
