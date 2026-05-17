## Why

Menu bar clicks currently open the same wide control panel as desk pet clicks, which makes the menu bar entry feel too heavy for quick access. The app needs the two entry points to have distinct behavior: the desk pet remains the rich control panel entry, while the menu bar becomes a small settings launcher.

## Affected Specs

- `desk-pet-controls`

## What Changes

- Replace the menu bar `MenuBarExtra` content with a compact menu containing only one settings action.
- Keep desk pet left-click and desk pet menu shortcut behavior attached to the existing wide desk pet control panel.
- Opening the menu bar settings action presents the existing MalDaze settings window.
- Update the desk pet controls spec so it no longer requires menu bar and desk pet entries to reuse the same control panel.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `desk-pet-controls`: Split menu bar entry behavior from desk pet control panel behavior.

## Impact

- `MalDaze/MalDazeApp.swift`: menu bar scene content changes from the shared control panel to a compact settings-only menu.
- `MalDaze/MenuBarContentView.swift`: desk pet control panel remains the wide shared control surface for desk pet popovers and may need comments/naming clarified.
- `MalDaze/WindowManager/WindowManager.swift`: desk pet popover behavior should remain unchanged and continue constructing the control panel through its helper.
- `MalDaze/Settings/MalDazeSettingsView.swift`: existing settings presenter is reused for the menu bar settings action.
- `MalDazeTests/ControlPanelPresentationTests.swift`: tests should assert the menu bar no longer embeds `MenuBarContentView` while desk pet still does.
