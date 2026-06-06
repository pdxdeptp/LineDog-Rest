## ADDED Requirements

### Requirement: MalDaze settings window hierarchy
The system SHALL present the MalDaze settings window opened from the Dashboard settings gear or menu bar settings action as a structured settings surface rather than a single undifferentiated raw form.

#### Scenario: Settings window opens with categories
- **WHEN** the user activates the Dashboard right-column settings gear
- **THEN** the system opens the existing MalDaze settings window
- **AND** the window presents distinct settings categories for retired middle-column feature, smart input, and shortcuts
- **AND** the selected category's details are visually separated from the category navigation

#### Scenario: Existing settings remain reachable
- **WHEN** the redesigned settings window renders
- **THEN** controls remain available for backend LLM provider, backend LLM model, selected backend provider API key, backend lazy startup, Smart Input Gemini API key, Smart Input Gemini model, and all existing shortcut recorders
- **AND** the redesign does not change existing persistence keys, provider model IDs, or shortcut default values

#### Scenario: Window sizing supports the redesigned layout
- **WHEN** the independent settings presenter creates the settings window
- **THEN** the content size supports the redesigned category-and-detail layout without forcing the primary API key controls into a cramped single-column form

### Requirement: API key entry experience
The system SHALL provide polished, provider-aware API key entry controls that make secret entry understandable, accessible, and locally scoped.

#### Scenario: API key row has clear labels and state
- **WHEN** an API key setting is displayed
- **THEN** it includes a visible label that identifies the provider or feature
- **AND** it communicates whether the key is empty or saved locally
- **AND** it includes helper text that the key is stored only on this Mac through the current local settings storage

#### Scenario: API key visibility can be toggled
- **WHEN** an API key setting is displayed
- **THEN** the key is hidden by default
- **AND** the user can explicitly show or hide the key from the same row
- **AND** the show/hide control has an accessible name

#### Scenario: Provider context is preserved
- **WHEN** the user changes the retired-feature backend provider
- **THEN** the model picker updates using the existing provider catalog behavior
- **AND** the visible API key entry corresponds to the selected backend provider
- **AND** Smart Input Gemini key entry remains separate from the retired-feature backend provider key
- **AND** Smart Input Gemini key entry uses the same Google Gemini provider identity and visual API key row treatment as the retired-feature Gemini entry

### Requirement: Shortcut recorder presentation
The system SHALL present global shortcut settings as consistent, readable rows while preserving the existing recorder behavior.

#### Scenario: Shortcut rows show current key and actions
- **WHEN** the shortcuts category renders
- **THEN** each shortcut row displays its current shortcut in a monospaced or keycap-like treatment
- **AND** each row provides an action to record a new shortcut
- **AND** each row provides an action to restore the default shortcut

#### Scenario: Recording state remains safe
- **WHEN** one shortcut recorder is waiting for a key press
- **THEN** other shortcut record actions are disabled
- **AND** pressing Esc cancels recording using the existing cancellation behavior
- **AND** modifier-key requirements remain unchanged

### Requirement: Settings accessibility and polish
The system SHALL keep settings controls accessible and visually polished across the redesigned settings window.

#### Scenario: Controls have accessible names
- **WHEN** the redesigned settings window renders icon-only or compact controls
- **THEN** each such control has an accessible name or visible text label
- **AND** keyboard focus order follows the visible category and detail layout

#### Scenario: Text hierarchy is readable
- **WHEN** the redesigned settings window renders helper copy, row labels, section titles, and status text
- **THEN** text uses a readable hierarchy with sufficient contrast
- **AND** helper text wraps instead of clipping inside its parent row

#### Scenario: Native behavior is preserved
- **WHEN** the user interacts with pickers, toggles, text fields, shortcut recording, Esc close, or window reopening
- **THEN** the existing business behavior remains unchanged
- **AND** the settings window still reuses `MalDazeSettingsView`
