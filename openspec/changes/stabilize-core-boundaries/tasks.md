## 1. Governance And Documentation

- [x] 1.1 Create the `stabilize-core-boundaries` OpenSpec change.
- [x] 1.2 Create `proposal.md` describing the coupling problem and staged refactor intent.
- [x] 1.3 Create `design.md` defining staged, behavior-preserving refactor strategy.
- [x] 1.4 Create `specs/core-boundary-stabilization/spec.md` with audit, todo, behavior-preservation, Hermes-boundary, and test-migration requirements.
- [x] 1.5 Create `docs/refactoring/system-coupling-audit.md` with evidence-based hotspot analysis.
- [x] 1.6 Create `docs/refactoring/refactor-todo.md` with prioritized refactor queue.

## 2. Low-Risk Duplicate Infrastructure

- [x] 2.1 Extract a shared FSEvent file watcher used by learning projects, sleep schedule, nutrition daily log, and intervention request watchers.
- [x] 2.2 Add focused tests or source-level verification for shared watcher filtering and lifecycle behavior.
- [x] 2.3 Consolidate global shortcut value modeling into one descriptor/value type while preserving existing defaults keys.
- [x] 2.4 Add shortcut load/save/display/enabled tests covering smart input, desk menu, seven-minute reminder, and pet reset shortcuts.
- [x] 2.5 Convert Carbon global hotkey registration to table-driven registration while preserving current NotificationCenter command names.
- [x] 2.6 Verify disabled shortcuts remain unregistered and existing shortcut behavior remains unchanged.

## 3. Hermes Runtime Boundary

- [x] 3.1 Extract shared Hermes home/path resolution without changing existing JSON contract locations.
- [x] 3.2 Extract a shared Hermes process runner with explicit timeout and stderr/stdout handling.
- [x] 3.3 Migrate learning schedule CLI to the shared Hermes runtime helper.
- [x] 3.4 Migrate nutrition CLI to the shared Hermes runtime helper while preserving current timeout behavior.
- [x] 3.5 Inject shared Hermes path helpers into sleep, intervention, nutrition daily log, and nutrition recommendation contract readers.
- [x] 3.6 Verify existing Hermes model, CLI, and contract tests pass; update audit/todo with any discovered contract risk.

## 4. Settings And Defaults Boundary

- [x] 4.1 Split `MalDazeDefaults` key namespaces from migration, clamp, layout, and Hermes sync behavior.
- [x] 4.2 Move dashboard layout clamp policy into dashboard layout types with focused tests.
- [ ] 4.3 Move learning capacity Hermes profile sync into an explicit learning settings sync service.
- [ ] 4.4 Introduce typed settings domains for timer, reminder, pet appearance, dashboard layout, shortcuts, and smart input settings.
- [ ] 4.5 Update Dashboard and Settings views to bind through typed settings domains where practical.
- [ ] 4.6 Verify existing settings behavior and update docs after the boundary change.

## 5. AppViewModel Boundary Extraction

- [ ] 5.1 Add or strengthen tests around timer mode, suspended-session, rest transition, and status text behavior.
- [ ] 5.2 Extract timer mode and suspended-session policy from `AppViewModel`.
- [ ] 5.3 Add or strengthen tests around pet display mode mapping.
- [ ] 5.4 Extract pet display mode mapping into a dedicated coordinator or policy.
- [ ] 5.5 Add or strengthen tests around smart reminder submit, undo, toast, and delayed bell behavior.
- [ ] 5.6 Extract smart reminder UI orchestration from `AppViewModel`.
- [ ] 5.7 Add or strengthen tests around reminder setting changes and controller lifecycle.
- [ ] 5.8 Extract hydration, sleep, intervention, and seven-minute lifecycle coordination from `AppViewModel`.
- [ ] 5.9 Extract T7 dashboard adapter responsibilities from `AppViewModel`.
- [ ] 5.10 Verify AppViewModel remains a composition/UI facade and update audit/todo.

## 6. WindowManager Boundary Extraction

- [ ] 6.1 Add or strengthen tests around dashboard window show/hide/frame/ESC/Cmd-W policy.
- [ ] 6.2 Extract dashboard window controller from `WindowManager`.
- [ ] 6.3 Add or strengthen tests around idle pet frame clamp, install ordering, and mouse policy.
- [ ] 6.4 Extract idle pet window controller from `WindowManager`.
- [ ] 6.5 Add or strengthen tests around rest and breakRun callback order and return-to-idle policy.
- [ ] 6.6 Extract rest and breakRun presentation controller from `WindowManager`.
- [ ] 6.7 Add or strengthen tests around smart input draft, cancel, submit clear, toast, and auto-dismiss behavior.
- [ ] 6.8 Extract smart input and toast panel controller from `WindowManager`.
- [ ] 6.9 Document manual QA steps for dashboard, idle pet, rest, breakRun, and smart input window behavior.

## 7. Source-Inspection Test Migration

- [ ] 7.1 Inventory source-inspection tests by protected regression and link each to a behavior or guardrail purpose.
- [ ] 7.2 Replace dashboard/window source-shape checks with behavior or policy tests where extracted coverage exists.
- [ ] 7.3 Replace T7 source-shape checks with behavior tests where extracted coverage exists.
- [ ] 7.4 Keep only documented, intentionally narrow source guardrails for platform constraints that cannot be tested directly.
- [ ] 7.5 Verify the test suite remains meaningful after source-inspection pruning.

## 8. Reminder And Pet Interaction Cleanup

- [ ] 8.1 Extract shared reminder panel/presentation utilities where hydration, seven-minute, sleep, and intervention controllers duplicate lifecycle behavior.
- [ ] 8.2 Extract PetStageView hit-test and interaction policies where behavior can be covered by tests.
- [ ] 8.3 Review existing code-map docs and align them with the new architecture.
- [ ] 8.4 Update `docs/refactoring/system-coupling-audit.md` and `docs/refactoring/refactor-todo.md` with final status and remaining follow-up work.
