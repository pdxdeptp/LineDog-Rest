## ADDED Requirements

### Requirement: Settings category boundaries
The MalDaze settings window SHALL keep credentials, shortcut recorders, and runtime startup controls in semantically correct settings surfaces without cross-category leakage or visual overlap.

#### Scenario: Model credentials page excludes unrelated controls
- **WHEN** the user opens the "模型与密钥" settings category
- **THEN** the detail pane SHALL show Learning Assistant and Smart Input LLM provider/model/API-key configuration
- **AND** the detail pane SHALL NOT show shortcut recorder controls such as "录制", "恢复默认", or Smart Input "添加提醒"
- **AND** the detail pane SHALL NOT show the learning-assistant lazy backend startup toggle

#### Scenario: Provider selection uses compact dropdown controls
- **WHEN** the user opens the "模型与密钥" settings category
- **THEN** each LLM feature surface SHALL render the service-provider selector as a dropdown or popup menu control
- **AND** the provider selector SHALL visually align with the model dropdown control
- **AND** the provider selector SHALL NOT render as a segmented control

#### Scenario: Shortcut page contains every global shortcut recorder
- **WHEN** the user opens the "快捷键" settings category
- **THEN** the detail pane SHALL show all global shortcut recorder rows
- **AND** the Smart Input "添加提醒" shortcut row SHALL appear with the other shortcut rows
- **AND** each shortcut row SHALL keep its current record, restore-default, default-copy, and storage behavior

#### Scenario: Learning Assistant category owns lazy backend startup
- **WHEN** the user needs to configure learning-assistant lazy backend startup
- **THEN** the settings window SHALL provide a "学习助手" category or equivalently named learning-assistant runtime category
- **AND** the category SHALL describe startup/runtime behavior rather than LLM credentials
- **AND** the lazy backend startup setting SHALL be reachable from that category
- **AND** toggling it SHALL preserve the existing lazy-backend storage key and startup semantics

#### Scenario: Category helper copy matches selected category
- **WHEN** the user opens any settings category
- **THEN** persistent helper copy in the settings shell SHALL match the selected category's purpose
- **AND** API-key-specific helper copy SHALL NOT remain visible while the selected category is "学习助手" or "快捷键"

#### Scenario: Category content does not visually bleed or overlap
- **WHEN** the user switches between settings categories, scrolls the detail pane, or uses the default settings window size
- **THEN** controls SHALL remain inside their owning category content
- **AND** controls SHALL NOT overlap card boundaries, section separators, or adjacent rows
- **AND** no row from another category SHALL be partially visible as if it belongs to the selected category
