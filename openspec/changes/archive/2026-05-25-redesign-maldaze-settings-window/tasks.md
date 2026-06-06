## 1. Tests and Source Assertions

- [x] 1.1 Add failing assertions that `MalDazeSettingsView` uses a category-and-detail settings shell instead of only one raw grouped `Form`.
- [x] 1.2 Add failing assertions that API key rows expose visible labels, saved/empty state text, local-only helper copy, and show/hide controls.
- [x] 1.3 Add failing assertions that shortcut settings use reusable rows with keycap-style display, record actions, restore-default actions, and preserved recorder busy-state disabling.
- [x] 1.4 Add failing assertions that existing `@AppStorage` keys, model catalog calls, `MalDazeSettingsView` reuse, and Esc/shortcut recorder hooks remain present.

## 2. Settings Window Redesign

- [x] 2.1 Refactor `MalDazeSettingsView` into a polished settings shell with sidebar categories and a right detail pane.
- [x] 2.2 Implement reusable local settings helpers for category buttons, setting groups, API key rows, and shortcut rows.
- [x] 2.3 Redesign the retired-feature settings category with provider/model selection, selected-provider API key row, backend startup toggle, and concise helper/status copy.
- [x] 2.4 Redesign the Smart Input settings category with Gemini API key row, model picker, and shortcut row while preserving natural-language reminder behavior.
- [x] 2.5 Redesign the shortcuts category for the desk pet menu, desk pet reset, and independent countdown shortcuts with consistent keycap, record, restore, and disabled states.
- [x] 2.6 Update `MalDazeSettingsWindowPresenter` sizing to fit the new category-and-detail layout while still centering through `MalDazePresentationAnchor`.

## 3. Behavior Preservation

- [x] 3.1 Preserve backend provider changes resetting `backendModel` through `BackendLLMCatalog.defaultModel(for:)`.
- [x] 3.2 Preserve Smart Input Gemini model fallback on appear.
- [x] 3.3 Preserve all shortcut recording, Esc cancellation, modifier validation, and restore-default behavior.
- [x] 3.4 Preserve settings window close-hide reuse and menu bar/Dashboard settings entry behavior.

## 4. Verification

- [x] 4.1 Run the relevant Swift/Xcode tests for control-panel presentation and settings source assertions.
- [x] 4.2 Run a broader app test/build check if the focused tests pass.
- [x] 4.3 Manually open settings from the Dashboard right-column gear and verify category navigation, API key show/hide, helper copy wrapping, shortcut recording, Esc behavior, and reopening.
- [x] 4.4 Manually open settings from the menu bar settings action and verify it reuses the same redesigned window.
