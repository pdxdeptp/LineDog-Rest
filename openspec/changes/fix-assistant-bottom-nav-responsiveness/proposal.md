## Why

The learning assistant bottom navigation feels slow because a tab click can appear to do nothing, close the floating Dashboard Panel, or wait behind tab-entry refresh work. This is especially visible now that the Dashboard Panel is the primary desk-pet entry and the assistant has more tabs with their own loading behavior.

## What Changes

- Make bottom navigation buttons provide immediate, reliable visual selection feedback for every tab.
- Ensure the full visible bottom-navigation item acts as the hit target, not only the icon/text glyphs.
- Keep Dashboard Panel click-away dismissal from closing the panel for clicks that occur inside the panel, including bottom-navigation clicks during app focus transitions.
- Keep tab-entry data loads asynchronous and non-blocking so changing tabs is not perceived as waiting for network refresh.
- Add focused regression coverage for the navigation feedback and panel click-inside behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `assistant-panel-ui`: Bottom navigation SHALL respond immediately and reliably when switching among assistant tabs.
- `desk-pet-controls`: Dashboard Panel dismissal SHALL not treat clicks inside the panel as click-away events, including focus-transition races.

## Impact

- SwiftUI assistant UI: `MalDaze/LearningAssistant/AssistantPanelView.swift`
- Learning assistant state refresh behavior: `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
- Dashboard Panel presentation and dismissal: `MalDaze/WindowManager/WindowManager.swift`
- Regression tests: `MalDazeTests/LearningAssistantTests.swift`, `MalDazeTests/ControlPanelPresentationTests.swift`
- No backend API, database schema, or persistence-key changes are expected.
