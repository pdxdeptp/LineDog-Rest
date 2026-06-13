## Context

The current MalDaze codebase has several high-coupling centers:

- `AppViewModel` coordinates timer engines, reminder controllers, T7, Hermes-backed workflows, NotificationCenter commands, UserDefaults synchronization, and window side effects.
- `WindowManager` owns multiple independent window/state machines: idle pet, rest fullscreen, breakRun, dashboard, smart input, toast, cursor tracking, and screen observers.
- Dashboard and Settings views write many settings directly through `@AppStorage`, then rely on `NotificationCenter` or AppViewModel methods to make runtime state catch up.
- Hermes integration code is spread across contract readers, CLI wrappers, and file watchers with duplicated paths and runtime behavior.
- Several large tests assert source-code shape instead of behavior. They protect known regressions, but they make behavior-preserving refactors expensive.

The refactor must therefore be staged. The first deliverable is a maintained audit and todo so each later implementation step has a known scope, risk level, and verification route.

## Goals / Non-Goals

**Goals:**

- Document current coupling hotspots with concrete file evidence.
- Maintain a prioritized refactor todo that can be executed one item at a time.
- Start with low-risk infrastructure consolidation before high-risk coordinator/window extraction.
- Preserve existing user-visible behavior while moving responsibilities into smaller boundaries.
- Preserve Hermes as the source of truth; MalDaze must not add client-side shadow state to hide backend recalculation.
- Replace source-inspection tests gradually with behavior or policy tests before moving heavily guarded code.

**Non-Goals:**

- No rewrite of the app architecture in one pass.
- No product behavior change unless a later OpenSpec task explicitly updates the relevant capability spec.
- No Hermes JSON contract changes in this change.
- No removal of historical regression tests until equivalent stronger coverage exists.
- No git worktree by default; this desktop app usually benefits from current-checkout manual QA.

## Decisions

### Decision 1: Treat refactoring as a governed capability

Create `core-boundary-stabilization` as an OpenSpec capability. This lets the project track refactor quality requirements alongside product specs instead of leaving them as loose notes.

Alternative considered: keep only an ad hoc markdown todo. That is lighter, but it does not create an apply-ready gate or a durable requirement that future refactors must preserve behavior and contracts.

### Decision 2: Keep a project-level audit separate from OpenSpec tasks

Add `docs/refactoring/system-coupling-audit.md` for evidence and architectural diagnosis, and `docs/refactoring/refactor-todo.md` for the living execution queue.

Alternative considered: keep all details inside `openspec/changes/stabilize-core-boundaries/tasks.md`. That makes implementation tracking easier, but it mixes durable architecture knowledge with one change's task lifecycle.

### Decision 3: Refactor from low-risk duplicates toward high-risk centers

The implementation order should be:

1. Generic file watcher.
2. Shortcut model and Carbon registration consolidation.
3. Hermes runtime/path/process helper extraction.
4. Settings/defaults boundary cleanup.
5. AppViewModel coordinator extraction.
6. WindowManager controller extraction.
7. Source-inspection test migration and pruning.

Alternative considered: split `AppViewModel` or `WindowManager` first. That attacks the largest pain directly, but current source-inspection tests and window lifecycle complexity make it more likely to create regressions.

### Decision 4: Require tests before risky movement

Each behavior-affecting refactor should first add or strengthen tests around the responsibility being moved. For purely mechanical duplicate extraction, source and existing tests may be enough, but high-risk boundaries must use RED/GREEN/REFACTOR through the project workflow.

Alternative considered: rely on broad app launch/manual QA. That would miss many state synchronization bugs that caused the current coupling pain.

### Decision 5: Use adapters, not shadow state, at Hermes boundaries

Hermes integration refactors may centralize paths, process execution, timeouts, decoding, and file watching. They must not add MalDaze-owned suppression lists, optimistic hiding, local replacement schedules, or client-side filters to mask Hermes recalculation.

Alternative considered: cache Hermes-derived state locally for smoother UI. That conflicts with the project contract that Hermes remains the source of truth.

## Risks / Trade-offs

- Large refactor scope -> Mitigation: keep the todo staged and apply one bounded task at a time.
- Source-inspection tests may block clean extraction -> Mitigation: convert critical source checks to behavior/policy tests before moving guarded code.
- Window lifecycle regressions are easy to miss -> Mitigation: defer `WindowManager` split until lower-risk scaffolding and focused tests exist.
- Hermes runtime consolidation could accidentally change contract semantics -> Mitigation: preserve existing readers/CLI behavior first, then centralize only duplicated infrastructure.
- Documentation may drift -> Mitigation: require each completed refactor task to update the audit/todo status before it is marked done.

## Migration Plan

1. Land the audit and todo documents.
2. Validate OpenSpec artifacts and keep this change apply-ready.
3. Before implementation, create or confirm a clean git checkpoint in the current checkout.
4. Apply tasks one at a time, preferring behavior-preserving extractions with focused tests.
5. After each task, update `docs/refactoring/refactor-todo.md` with status, evidence, and remaining risk.
6. Archive this change only after the initial refactor sequence has either completed or been split into smaller successor changes with clear ownership.

## Open Questions

- Which high-risk boundary should get the first dedicated behavior test harness: AppViewModel timer state, WindowManager dashboard lifecycle, or Hermes process execution?
- Should completed source-inspection tests be kept as archived regression notes, or deleted once behavior coverage exists?
- How much manual UI QA should be required for each window-boundary task before commit?
