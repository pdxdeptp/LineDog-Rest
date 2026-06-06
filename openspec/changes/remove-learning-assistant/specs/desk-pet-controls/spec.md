## MODIFIED Requirements

### Requirement: 宽屏桌宠 Dashboard Panel
桌宠 Dashboard Panel SHALL use a focused retained layout for reminders and desktop pet controls without allocating a Learning Assistant column.

#### Scenario: 宽屏布局
- **WHEN** 当前屏幕可见宽度足以展示 Dashboard Panel
- **THEN** panel 使用横向布局展示提醒计划区域和桌宠控制区域
- **AND** panel 不展示学习助手中栏

#### Scenario: Panel position
- **WHEN** Dashboard Panel 从桌宠入口打开
- **THEN** 系统优先将 panel 放置在桌宠附近
- **AND** 若桌宠位置会导致 panel 超出可见区域，系统将 panel 移入当前屏幕可见区域

### Requirement: Settings category boundaries
The MalDaze settings window SHALL keep retained Smart Reminder credentials, shortcut recorders, and non-learning runtime controls in semantically correct settings surfaces without cross-category leakage or visual overlap.

#### Scenario: Model credentials page excludes unrelated controls
- **WHEN** the user opens the model and API-key settings category
- **THEN** the detail pane SHALL show retained Smart Reminder provider/model/API-key configuration
- **AND** the detail pane SHALL NOT show shortcut recorder controls such as "录制", "恢复默认", or Smart Input "添加提醒"
- **AND** the detail pane SHALL NOT show learning-assistant backend startup controls

#### Scenario: Provider selection uses compact dropdown controls
- **WHEN** the user opens the model and API-key settings category
- **THEN** each retained LLM feature surface SHALL render the service-provider selector as a dropdown or popup menu control
- **AND** the provider selector SHALL visually align with the model dropdown control
- **AND** the provider selector SHALL NOT render as a segmented control

#### Scenario: Shortcut page contains every global shortcut recorder
- **WHEN** the user opens the "快捷键" settings category
- **THEN** the detail pane SHALL show all global shortcut recorder rows
- **AND** the Smart Input "添加提醒" shortcut row SHALL appear with the other shortcut rows
- **AND** each shortcut row SHALL keep its current record, restore-default, default-copy, and storage behavior

#### Scenario: Category helper copy matches selected category
- **WHEN** the user opens any settings category
- **THEN** persistent helper copy in the settings shell SHALL match the selected category's purpose
- **AND** API-key-specific helper copy SHALL NOT remain visible while the selected category is "快捷键"

#### Scenario: Category content does not visually bleed or overlap
- **WHEN** the user switches between settings categories, scrolls the detail pane, or uses the default settings window size
- **THEN** controls SHALL remain inside their owning category content
- **AND** controls SHALL NOT overlap card boundaries, section separators, or adjacent rows
- **AND** no row from another category SHALL be partially visible as if it belongs to the selected category

### Requirement: MalDaze settings window hierarchy
The system SHALL present the MalDaze settings window opened from the Dashboard settings gear or menu bar settings action as a structured settings surface for retained app controls.

#### Scenario: Settings window opens with categories
- **WHEN** the user activates the Dashboard right-column settings gear
- **THEN** the system opens the existing MalDaze settings window
- **AND** the window presents distinct settings categories for retained Smart Reminder, shortcuts, and other non-learning settings
- **AND** the selected category's details are visually separated from the category navigation

#### Scenario: Existing settings remain reachable
- **WHEN** the redesigned settings window renders
- **THEN** controls remain available for Smart Reminder provider/model/API key and all existing shortcut recorders
- **AND** the redesign does not change retained Smart Reminder persistence keys, provider model IDs, or shortcut default values

#### Scenario: Window sizing supports the retained layout
- **WHEN** the independent settings presenter creates the settings window
- **THEN** the content size supports the retained category-and-detail layout without forcing primary API key controls into a cramped single-column form

### Requirement: API key entry experience
The system SHALL provide polished, provider-aware API key entry controls for retained Smart Reminder configuration.

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

#### Scenario: Smart Reminder provider context is preserved
- **WHEN** the user changes the Smart Reminder provider
- **THEN** the model picker updates using the existing provider catalog behavior
- **AND** the visible API key entry corresponds to the selected Smart Reminder provider

### Requirement: Dashboard Panel internal click stability
Dashboard Panel dismissal logic SHALL preserve the panel when the user clicks inside retained Dashboard Panel content.

#### Scenario: Internal click during focus transition
- **WHEN** the Dashboard Panel is visible and the app processes a focus or activation transition
- **AND** the original mouse event location is inside the Dashboard Panel frame
- **THEN** click-away or app-deactivation dismissal does not hide the panel for that internal click

#### Scenario: Outside click still dismisses
- **WHEN** the Dashboard Panel is visible
- **AND** the user clicks outside both the Dashboard Panel and the desk-pet window
- **THEN** the panel closes or hides using the existing Dashboard Panel dismissal behavior

## REMOVED Requirements

### Requirement: Unified LLM provider settings module
**Reason**: The only consumer that required shared Learning Assistant and Smart Input credential surfaces has been retired.
**Migration**: Keep retained Smart Reminder provider/model/API-key settings through the existing Smart Input provider-selection requirements.

#### Scenario: Learning Assistant credential surface removed
- **WHEN** the settings window renders
- **THEN** it does not render a Learning Assistant credential surface
