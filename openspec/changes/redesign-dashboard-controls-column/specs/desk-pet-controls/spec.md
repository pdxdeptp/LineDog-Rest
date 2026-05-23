## ADDED Requirements

### Requirement: Dashboard right controls hierarchy
The Dashboard right controls column SHALL present existing desk-pet controls with a clear hierarchy that separates live status, common actions, configuration, utilities, and destructive actions.

#### Scenario: First screen shows status and common actions
- **WHEN** the Dashboard panel opens
- **THEN** the right controls column displays the current status line near the top
- **AND** the column displays the timer mode control near the top
- **AND** the column displays primary everyday actions before lower-frequency settings

#### Scenario: Settings remain available without dominating
- **WHEN** the user scans the right controls column
- **THEN** timer duration, rest behavior, pet appearance, hydration quiet hours, and break style controls remain reachable
- **AND** these lower-frequency controls do not visually compete with the primary everyday actions

#### Scenario: Utility and destructive actions are separated
- **WHEN** the right controls column renders reset, test, quit, or equivalent utility actions
- **THEN** those actions are visually separated from the primary timer, reminder, hydration, and companion actions
- **AND** the quit action is not grouped with everyday timer controls

#### Scenario: Accessible control targets
- **WHEN** the right controls column renders clickable or tappable controls
- **THEN** each primary control provides a clear label or accessibility label
- **AND** icon-only controls have an accessible name
- **AND** controls maintain comfortable spacing to avoid accidental activation

#### Scenario: Existing behavior preserved
- **WHEN** the right controls column is redesigned
- **THEN** existing capabilities for timer modes, manual focus, stop/resume, rest behavior, pet appearance, countdown reminder, hydration reminder, cat companion, settings, and quit remain available
- **AND** the redesign does not change persistence keys or timer/reminder business logic

### Requirement: Dashboard right controls interactions
The Dashboard right controls column SHALL map each visible action to an explicit state-aware interaction while preserving existing view-model behavior.

#### Scenario: Settings action
- **WHEN** the user activates the settings gear
- **THEN** the system opens the existing MalDaze settings window

#### Scenario: Mode action
- **WHEN** the user selects a timer mode
- **THEN** the system calls the existing mode-change behavior
- **AND** current timer, rest, status, and pet-state side effects remain unchanged

#### Scenario: Manual focus action
- **WHEN** the current mode is manual and no timer session is active or suspended
- **THEN** the primary timer action starts a manual focus session

#### Scenario: Stop timer action
- **WHEN** a timer session is active and stoppable
- **THEN** the primary timer action stops timers

#### Scenario: Resume timer action
- **WHEN** a timer session is suspended
- **THEN** the primary timer action resumes timers

#### Scenario: Non-manual idle timer action
- **WHEN** the current mode is not manual and no manual start action is valid
- **THEN** the primary timer action does not start a manual focus session
- **AND** the UI communicates that automatic timing is controlled by the selected mode

#### Scenario: Countdown action
- **WHEN** the countdown reminder is not running
- **THEN** the countdown action starts the reminder using the configured duration
- **AND** when the countdown reminder is running, the same action changes to a cancel action

#### Scenario: Hydration quick action
- **WHEN** hydration reminders are disabled
- **THEN** the hydration quick action enables hydration reminders
- **AND** when hydration reminders are enabled, the same action disables hydration reminders

#### Scenario: Cat companion action
- **WHEN** the cat companion is inactive
- **THEN** the cat action starts the cat companion
- **AND** when the cat companion is active, the same action changes to an early close action

#### Scenario: Disclosure sections
- **WHEN** the user opens or closes a settings disclosure section
- **THEN** the system changes only the local presentation state
- **AND** no timer, reminder, hydration, pet, or quit behavior runs from disclosure header activation

#### Scenario: Footer utility actions
- **WHEN** the user activates reset pet, test rest, test hydration, or quit
- **THEN** each action calls its existing view-model behavior
- **AND** test and quit actions remain visually separated from everyday quick actions
