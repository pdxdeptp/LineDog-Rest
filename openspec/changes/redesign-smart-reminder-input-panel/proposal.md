## Why

The desk-pet right-click smart reminder input is currently a narrow, single-line strip. Longer natural-language plans disappear horizontally while typing, which makes the primary capture flow feel fragile exactly when the user needs to express richer scheduling intent.

## Affected Specs

- `desk-pet-controls`

## What Changes

- Redesign the smart reminder input panel as a compact multi-line capture surface instead of a fixed-width horizontal strip.
- Keep the desk-pet right-click and global shortcut entry points, draft preservation, submit, cancel, and success-clear behavior.
- Make long input visible while typing by allowing vertical growth and scrolling within bounded panel dimensions.
- Add clear visual hierarchy around the natural-language input, including concise placeholder text and explicit cancel/add actions.
- Preserve keyboard ergonomics: focus on open, Esc cancels, and Return submits in a predictable way for the redesigned control.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `desk-pet-controls`: Smart reminder input panel layout and text-entry behavior changes from a fixed single-line strip to a bounded multi-line capture panel that supports long natural-language input.

## Impact

- `MalDaze/SmartReminder/SmartReminderUIPanels.swift`: redesign the SwiftUI input content and panel sizing.
- `MalDaze/WindowManager/WindowManager.swift`: continue positioning and lifecycle management for the redesigned panel; adjust sizing assumptions only if needed.
- `MalDazeTests`: add source or behavior assertions covering multi-line input affordance, bounded panel size, and preserved entry/submit/cancel behavior.
- Manual QA: verify right-click entry, global shortcut entry, long Chinese text typing, Esc/cancel, Return submit, outside-click draft preservation, and success clear.
