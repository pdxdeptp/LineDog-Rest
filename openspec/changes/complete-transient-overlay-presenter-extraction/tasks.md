## 1. Git Safety and RED Baseline

- [x] 1.1 Run `git status --short --branch`, identify every overlapping user/parallel change in `MalDaze.xcodeproj/project.pbxproj`, `WindowManager.swift`, and `ControlPanelPresentationTests.swift`, and choose current-checkout sequential execution without overwriting unrelated hunks.
- [x] 1.2 Before non-worktree `opsx:apply`, create the required checkpoint commit containing only authorized current-state files; if unrelated changes cannot be separated safely, stop and request user direction.
- [x] 1.3 Add a behavior test that presents smart input, dismisses it before delayed focus executes, then executes the captured focus work and asserts the old panel is not activated, ordered, focused, or visible.
- [x] 1.4 Add a behavior test that replaces smart input A with B, executes A's stale focus work, and asserts only B remains the owned visible input.
- [x] 1.5 Add behavior tests that screen-parameter changes recenter passive overlays, reclamp input/Toast overlays with their stored anchor, and keep the observer installed while any other overlay remains visible.
- [x] 1.6 Add boundary tests proving `WindowManager` declares no smart input/Toast panel properties and the smart reminder content builder does not construct `NSPanel`.
- [x] 1.7 Add a focused test proving countdown completion removes the `SevenMinuteReminderController` screen observer before presenter-owned center bell display.
- [x] 1.8 Run the new focused tests and record the expected RED failures before writing implementation code.

## 2. Interactive Presenter Ownership

- [x] 2.1 Define a panel-free `TransientOverlayContent` (or equivalent) carrying hosted content and size, plus semantic smart input/Toast present, query, containment, and dismiss APIs on `MalDazeTransientOverlayPresenting`.
- [x] 2.2 Extend `MalDazeTransientOverlayPresenter` state to retain the current smart input and Toast panels with anchor, content size, policy, and generation while keeping passive overlay state behavior unchanged.
- [x] 2.3 Move interactive panel shell creation, configuration, positioning, ordering, closing, and release into the presenter.
- [x] 2.4 Implement idempotent input/Toast dismissal that invalidates the current generation and removes only the requested overlay state.
- [x] 2.5 Guard delayed input focus with weak panel capture plus current kind/generation/identity checks so dismissed or replaced panels cannot be revived.

## 3. Unified Repositioning and Content Boundary

- [x] 3.1 Refactor `SmartReminderUIPanels` into a content builder that returns hosted input/Toast content and sizing information without constructing or positioning panels.
- [x] 3.2 Install the presenter screen observer whenever any passive or interactive overlay is visible and remove it only after all owned overlays are dismissed.
- [x] 3.3 Reposition passive overlays with `PassiveCenteredOverlayGeometry` and interactive overlays with the stored anchor/size using the existing visible-frame clamp algorithm.
- [x] 3.4 Run presenter behavior tests and confirm delayed-focus, replacement, multi-overlay observer, and screen-change scenarios are GREEN.

## 4. WindowManager and Countdown Cleanup

- [x] 4.1 Remove `smartInputPanel` / `smartToastPanel` ownership and direct panel creation/close/order calls from `WindowManager`.
- [x] 4.2 Preserve input draft, submit, Esc, local/global outside-click, global-shortcut toggle, and cancel callback semantics using presenter visibility/containment queries and dismiss commands.
- [x] 4.3 Preserve Toast undo and four-second auto-dismiss orchestration while delegating current-toast closing to the presenter; stale Toast work must not affect a replacement.
- [x] 4.4 Remove the `SevenMinuteReminderController` countdown screen observer when countdown UI ends, before presenting the center bell through the shared presenter.
- [x] 4.5 Run smart reminder, center-bell, sleep, intervention, hydration, and Dashboard presentation regression tests and confirm GREEN.

## 5. Verification, Manual QA, and Handoff

- [x] 5.1 Run `openspec validate --strict extract-transient-overlay-presenter` and `openspec validate --strict complete-transient-overlay-presenter-extraction`.
- [x] 5.2 Run the complete focused test set (`TransientOverlayPresenterTests`, affected `ControlPanelPresentationTests`, `SevenMinuteReminderCompletionTests`, `SleepReminderClamshellTests`, and intervention coverage) and record the exact passing command/result.
- [x] 5.3 Run the broader `MalDazeTests` suite; distinguish any pre-existing failure from this change with evidence, and do not claim the branch green while an unaccounted failure remains.
- [x] 5.4 Manual QA — open smart input near the right Dock, type a draft, exercise Esc/outside/cancel/rapid reopen, submit, Toast undo, and auto-dismiss; confirm no dismissed or replaced panel reappears.
- [x] 5.5 Manual QA — while input and Toast are visible, change display arrangement/resolution and confirm both remain clamped; repeat passive hydration/center-bell checks and confirm Dashboard z-order is unchanged.
- [x] 5.6 Update `docs/refactoring/refactor-todo.md` R22 evidence only after focused tests and manual QA pass; keep it non-Done while this follow-up remains incomplete.
- [x] 5.7 Record final archive dependency: archive `extract-transient-overlay-presenter` first and `complete-transient-overlay-presenter-extraction` second only after both changes pass final verification.
