## Context

`MalDazeApp` currently places `MenuBarContentView(viewModel:)` directly inside `MenuBarExtra`, while `WindowManager` also uses `MenuBarContentView` as the desk pet popover root. The existing `desk-pet-controls` spec documents that shared behavior, but the requested product behavior is now different: menu bar clicks should show a tiny settings-only menu, and desk pet clicks should remain the rich control-panel entry.

The settings UI already has `MalDazeSettingsWindowPresenter.present()`, so this change can reuse the existing settings window instead of adding another settings scene or route.

## Goals / Non-Goals

**Goals:**

- Make menu bar clicks open a compact menu containing only one settings button.
- Make that settings button present the existing MalDaze settings window.
- Keep desk pet left-click and the desk pet global shortcut opening the existing wide control panel.
- Preserve current desk pet popover sizing, dismiss behavior, and smart-reminder right-click behavior.

**Non-Goals:**

- Redesign `MalDazeSettingsView`.
- Move timer, reminder, assistant, or pet-visual controls out of the desk pet control panel.
- Change global shortcuts or smart-reminder input behavior.

## Decisions

- Introduce a separate menu bar content view for the compact settings menu.
  - Rationale: this makes the entry-point split explicit and prevents future menu bar code from accidentally pulling in the heavy desk pet control panel.
  - Alternative considered: conditionally render `MenuBarContentView` differently when used by the menu bar. That keeps shared code coupled and makes the two entry points harder to reason about.

- Reuse `MalDazeSettingsWindowPresenter.present()` from the menu bar settings action.
  - Rationale: the app already needs an explicit settings window presenter under `LSUIElement`; using the same presenter keeps behavior consistent between the control panel gear button and menu bar settings button.
  - Alternative considered: rely on the SwiftUI `Settings` scene. Existing comments note this path is unreliable for a menu-bar-agent app.

- Keep desk pet popover construction centralized in `WindowManager.makeDeskPetControlPanelRootView`.
  - Rationale: existing tests and architecture already isolate desk pet control panel construction there; the menu bar split should not disturb popover sizing or dismiss monitors.

## Risks / Trade-offs

- Menu bar user loses direct access to the full control panel from the menu bar -> Mitigation: desk pet click and desk pet menu shortcut remain the full-panel entry points.
- A future change could reintroduce `MenuBarContentView` into `MalDazeApp` -> Mitigation: add source-level regression tests that assert the menu bar scene uses the compact menu and does not instantiate the shared control panel.
- Settings window presentation could duplicate an already-open settings window -> Mitigation: reuse the existing presenter, which owns the singleton window behavior.
