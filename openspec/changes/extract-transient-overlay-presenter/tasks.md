## 1. Regression Coverage

- [x] 1.1 Add failing tests for `MalDazeTransientOverlayPresenter` passive policy (non-activating panel, screenSaver level, dashboard demote guard using pre-present `NSApp.isActive` snapshot).
- [x] 1.2 Add failing tests proving `HydrationReminderController` delegates presentation and no longer owns inline `NSPanel` lifecycle.
- [x] 1.3 Add failing tests proving `SevenMinuteReminderController.presentCenterBellReminder` delegates to the presenter while preserving public API.
- [x] 1.4 Add failing tests proving smart reminder input/toast paths delegate to the presenter while preserving draft, Esc/outside dismiss, and anchor clamp behavior.
- [x] 1.5 Verify new tests fail before implementation.

## 2. Presenter Foundation

- [x] 2.1 Create `MalDaze/TransientOverlay/` with `MalDazeTransientOverlayPresenting` protocol and `MalDazeTransientOverlayPresenter` implementation.
- [x] 2.2 Inject dashboard demote policy from `WindowManager` (reuse `dashboard.order(.below, relativeTo: 0)`).
- [x] 2.3 Implement passive centered presentation shell (create, order, dismiss, screen observer, reposition).
- [x] 2.4 Implement interactive anchored presentation shell for smart reminder surfaces.
- [x] 2.5 Wire presenter instance from `WindowManager.bindDeskPetMenu` / `AppViewModel` init path.

## 3. Migrate Hydration Reminder

- [x] 3.1 Extract hydration card/button content into a builder used by the presenter.
- [x] 3.2 Slim `HydrationReminderController` to scheduling + `presentHydrationReminder` delegation.
- [x] 3.3 Remove duplicated hydration screen observer and inline panel code.
- [x] 3.4 Run hydration-focused tests and confirm GREEN.

## 4. Migrate Center Bell

- [x] 4.1 Extract center bell content into a builder used by the presenter.
- [x] 4.2 Route `SevenMinuteReminderController.presentCenterBellReminder` / dismiss through the presenter.
- [x] 4.3 Confirm `SleepReminderController` and `InterventionRequestController` need no public API changes.
- [x] 4.4 Run sleep/intervention/center-bell focused tests and confirm GREEN.

## 5. Migrate Smart Reminder Overlays

- [x] 5.1 Move smart reminder SwiftUI content builders under the transient overlay module (or keep file, delegate lifecycle).
- [x] 5.2 Route `WindowManager.presentSmartReminderInput`, toast presentation, and teardown through the presenter.
- [x] 5.3 Preserve draft storage, Esc monitor, outside-click dismiss, and anchor clamp semantics in `WindowManager`.
- [x] 5.4 Delete or slim obsolete panel factory code in `SmartReminderUIPanels.swift`.
- [x] 5.5 Run smart reminder focused tests and confirm GREEN.

## 6. Verification and Docs

- [x] 6.1 Run `openspec validate extract-transient-overlay-presenter`.
- [x] 6.2 Run focused `MalDazeTests` suites touched by this change (`TransientOverlayPresenterTests`, `ControlPanelPresentationTests`, sleep/intervention/hydration coverage).
- [x] 6.3 Manual QA — passive overlays: open Dashboard, switch to another app, trigger hydration timer/test and sleep/intervention bell; confirm overlay is topmost while Dashboard stays behind other apps.
- [x] 6.4 Manual QA — interactive overlays: right-click and shortcut smart reminder input near right Dock; confirm clamp, typing, draft retention, submit, toast undo.
- [x] 6.5 Manual QA — explicit Dashboard entry points (Dock, desk pet toggle) still foreground Dashboard.
- [x] 6.6 Update `docs/refactoring/refactor-todo.md` R22 status after apply.
