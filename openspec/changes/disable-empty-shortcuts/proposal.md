## Why

The shortcut settings UI cannot currently express an intentionally empty shortcut, so users who do not want a global shortcut for a row have no clear way to turn it off. Empty shortcut input should be treated as an explicit disabled state instead of an invalid key combination.

## What Changes

- Allow every shortcut setting row to disable its shortcut when the user leaves recording without entering a key.
- Show disabled shortcut rows as `已关闭` instead of falling back to a fake key label.
- Prevent Carbon global hot key registration for disabled shortcut settings.
- Keep “恢复默认” as the way to restore the built-in shortcut for each row.

## Capabilities

### New Capabilities

### Modified Capabilities
- `desk-pet-controls`: Shortcut settings gain an explicit disabled state for empty input.

## Impact

- Affected code: `MalDaze/Settings/MalDazeSettingsView.swift`, shortcut model structs, and `MalDaze/MalDazeCarbonGlobalHotKeys.swift`.
- Affected tests: focused shortcut settings/model/registration coverage in `MalDazeTests/ControlPanelPresentationTests.swift`.
- No new dependencies or persistence keys; disabled shortcuts use existing keyCode/modifier/keyLabel storage.
