## Context

MalDaze settings currently stores each global shortcut as three existing UserDefaults values: keyCode, modifiers, and keyLabel. The recorder can capture a valid key with modifiers or cancel recording, but it cannot persist an intentionally empty shortcut. Display code then treats empty labels as a fallback key label, and Carbon registration attempts to install whatever model is loaded.

## Goals / Non-Goals

**Goals:**
- Represent empty shortcut input as a disabled shortcut using the existing storage keys.
- Make the disabled state visible in every shortcut row.
- Ensure disabled shortcuts are not registered as global Carbon hot keys.
- Keep default shortcut restoration unchanged.

**Non-Goals:**
- No new shortcut editor component or text-field shortcut parser.
- No migration to a new persistence schema.
- No changes to shortcut defaults or shortcut-triggered business logic.

## Decisions

- Use `modifiers == []` as the disabled sentinel. Recorded shortcuts already require at least one command/option/control/shift modifier, so a no-modifier stored value cannot represent a valid setting from the UI.
- Keep missing UserDefaults as “use built-in default.” First launch behavior remains unchanged; only an explicitly stored empty/no-modifier shortcut is disabled.
- Let Esc during recording commit the empty-input path for that row, and add an explicit row button to close the shortcut without entering a key. This gives both keyboard and visible mouse interactions.
- Make Carbon registration guard `isEnabled` before calling `RegisterEventHotKey`, unregistering any previously installed hot key for that action.

## Risks / Trade-offs

- Existing corrupted no-modifier shortcut settings will now display as disabled instead of attempting registration. This is safer because the UI never allowed valid no-modifier shortcuts.
- Source-level tests protect the current settings structure but are somewhat brittle. They are consistent with the existing test style in `ControlPanelPresentationTests`.
