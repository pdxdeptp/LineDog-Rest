## Context

`SevenMinuteReminderController` owns the shared center bell reminder UI used by the independent countdown, sleep reminders, and intervention bell contracts. `HydrationReminderController` owns a separate two-button hydration reminder overlay. These transient overlays should sit above the desktop while they are handled, but they should not activate MalDaze as an app. If the desk-pet Dashboard is already visible behind other apps, app activation can bring it to the front after the reminder is dismissed or clicked.

## Goals / Non-Goals

**Goals:**
- Keep the center bell visible above the desktop and clickable.
- Keep the hydration reminder visible above the desktop and clickable.
- Prevent reminder dismissal/actions from activating MalDaze or foregrounding Dashboard.
- Preserve all existing reminder text, sizing, placement, actions, and screen-change behavior.

**Non-Goals:**
- Do not change Dashboard explicit focus/open behavior from Dock, desk pet, or shortcut.
- Do not change sleep reminder scheduling, hydration reminder timing, countdown timing, or Hermes contracts.
- Do not introduce cross-component callbacks from the bell controller into `WindowManager`.

## Decisions

- Convert the center bell reminder window to a non-activating panel style. This addresses the source of the activation instead of adding Dashboard-specific demotion after dismissal.
- Convert the hydration reminder window to the same non-activating panel pattern and remove explicit `NSApp.activate`.
- Keep the countdown mini-window unchanged because it ignores mouse events and is not the clicked dismissal surface.
- Add focused source-level regression coverage matching the project’s existing window-behavior tests.

## Risks / Trade-offs

- Non-activating panels must still receive mouse-down events for dismissal. The existing overlay view handles mouse events directly, so this remains compatible.
- Source-level tests protect the chosen AppKit style but do not exercise a live window-server z-order stack. Manual QA is still required for the exact desktop interaction.
