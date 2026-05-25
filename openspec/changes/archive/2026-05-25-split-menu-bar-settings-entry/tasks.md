## 1. Regression Tests

- [x] 1.1 Add a failing regression test proving `MalDazeApp.swift` no longer constructs `MenuBarContentView(viewModel:)` inside the `MenuBarExtra` content.
- [x] 1.2 Add a failing regression test proving the menu bar content is a settings-only menu that presents `MalDazeSettingsWindowPresenter`.
- [x] 1.3 Keep or adjust desk pet control panel tests so `WindowManager.makeDeskPetControlPanelRootView` remains the only desk pet popover construction point for `MenuBarContentView(viewModel:)`.

## 2. Menu Bar / Desk Pet Split

- [x] 2.1 Create a compact SwiftUI menu bar content view with exactly one settings action.
- [x] 2.2 Replace the `MenuBarExtra` content in `MalDazeApp.swift` with the compact settings-only menu while keeping the existing dog label and window menu style.
- [x] 2.3 Keep desk pet left-click and desk pet menu shortcut behavior using the existing wide `MenuBarContentView(viewModel:)` popover.
- [x] 2.4 Update comments or names that still describe `MenuBarContentView` as shared by both menu bar and desk pet entries.

## 3. Verification

- [x] 3.1 Run the relevant `MalDazeTests` covering control panel presentation.
- [x] 3.2 Run the broader available app test command if practical in the local environment.
- [x] 3.3 Note manual QA: restart the desktop app, click the menu bar icon, verify only the settings button appears, click it, then verify desk pet click still opens the full control panel.
