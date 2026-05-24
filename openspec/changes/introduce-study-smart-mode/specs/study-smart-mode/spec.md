## ADDED Requirements

### Requirement: Smart Mode Setting
The system SHALL provide an off-by-default smart-mode setting for the learning assistant.

#### Scenario: Default mode is the initial state
- **WHEN** no smart-mode preference has been stored
- **THEN** the system treats smart mode as disabled
- **AND** default-mode dashboard and adjustment flows do not request smart briefings or smart proposals

#### Scenario: User toggles smart mode
- **WHEN** the user enables or disables smart mode in Settings
- **THEN** the preference is persisted
- **AND** subsequent learning-assistant refreshes use the persisted value

#### Scenario: Disabled smart mode suppresses proposal generation
- **WHEN** smart mode is disabled
- **AND** lag, expected-late, or over-capacity facts exist
- **THEN** the system displays those facts normally
- **AND** it does not generate smart-mode proposal options

### Requirement: Fact-Only Smart Morning Briefing
The system SHALL generate a smart-mode morning briefing from existing v2 study-plan facts without invoking v1 autonomous agent behavior.

#### Scenario: Morning briefing summarizes existing facts
- **WHEN** smart mode is enabled
- **AND** the user opens or refreshes the learning assistant for the local day
- **THEN** the smart briefing summarizes Today tasks, rolled-task lag, expected-late projects, and over-capacity days from persisted v2 facts
- **AND** it does not create new plan data beyond already-defined v2 rollover facts

#### Scenario: Morning briefing does not run v1 Morning Agent
- **WHEN** the smart-mode morning briefing is requested
- **THEN** the system does not call the v1 `run_morning_agent` flow
- **AND** it does not run weekly review catch-up, speed-factor calibration, or autonomous task rescheduling

#### Scenario: No issues yields a quiet briefing
- **WHEN** smart mode is enabled
- **AND** Today, lag, expected-late, and over-capacity facts show no issue
- **THEN** the briefing may summarize the current day
- **AND** it returns no smart proposal options

### Requirement: Morning Proposal Trigger
The system SHALL offer smart proposal options in the morning only when v2 facts show lag, expected-late, or over-capacity.

#### Scenario: Rolled task threshold triggers morning proposals
- **WHEN** a task has accumulated at least three auto-roll days
- **AND** smart mode is enabled
- **THEN** the morning smart briefing identifies the lag
- **AND** returns one or more proposal options for user review

#### Scenario: Expected-late project triggers morning proposals
- **WHEN** an active study project is expected late
- **AND** smart mode is enabled
- **THEN** the morning smart briefing identifies the expected-late project
- **AND** returns one or more proposal options for user review

#### Scenario: Over-capacity day triggers morning proposals
- **WHEN** a calendar day is over capacity
- **AND** smart mode is enabled
- **THEN** the morning smart briefing identifies the overload
- **AND** returns one or more proposal options for user review

### Requirement: After-Adjustment Proposal Trigger
The system SHALL offer smart proposal options after a manual adjustment only when that adjustment creates expected-late or over-capacity red state.

#### Scenario: Red-state-producing adjustment triggers proposals
- **WHEN** smart mode is enabled
- **AND** a user-initiated adjustment completes
- **AND** the refreshed v2 facts show newly created expected-late or over-capacity state
- **THEN** the system requests smart proposal options for that adjustment context

#### Scenario: Non-red adjustment remains quiet
- **WHEN** smart mode is enabled
- **AND** a user-initiated adjustment completes without creating expected-late or over-capacity state
- **THEN** the system does not request or display smart proposal options

#### Scenario: Lag does not trigger after-adjustment proposals
- **WHEN** a plan has rolled-task lag
- **AND** the latest manual adjustment did not create expected-late or over-capacity state
- **THEN** the system does not treat lag as an after-adjustment trigger

### Requirement: Proposal Options Are User-Applied Previews
The system SHALL present smart proposal options as structured previews with independent Apply actions.

#### Scenario: Multiple options are shown side by side
- **WHEN** smart proposal generation returns more than one option
- **THEN** the UI displays the options in parallel rather than as a hidden single recommendation
- **AND** each option includes its own Apply control

#### Scenario: Proposal option shows impact preview
- **WHEN** a smart proposal option is displayed
- **THEN** it shows the reason, affected project or tasks, proposed date or deadline changes, and red-state impact
- **AND** no task or project data is changed by displaying the preview

#### Scenario: User ignores proposals
- **WHEN** the user dismisses or ignores smart proposal options
- **THEN** the system performs no mutation
- **AND** the underlying plan facts remain unchanged

### Requirement: Proposal Application Is Revalidated
The system SHALL apply a smart proposal only after verifying that the submitted preview still matches current persisted facts.

#### Scenario: User applies current proposal
- **WHEN** the user presses Apply on a smart proposal option
- **AND** the submitted proposal signature matches a freshly recomputed preview
- **THEN** the system applies exactly the previewed changes
- **AND** records an event identifying smart mode as the source
- **AND** refreshes Today, Project Overview, and Calendar facts

#### Scenario: Stale proposal is rejected
- **WHEN** the user presses Apply on a smart proposal option
- **AND** current plan facts no longer match the submitted proposal signature
- **THEN** the system rejects the apply as stale
- **AND** no task or project data is changed

#### Scenario: Disabled smart mode rejects apply
- **WHEN** smart mode is disabled
- **AND** a smart proposal apply request is submitted
- **THEN** the system rejects or no-ops the request
- **AND** no task or project data is changed

### Requirement: Mechanical Adjustment Semantics Remain Unchanged
The system SHALL keep ITEM-003 mechanical adjustment behavior unchanged when smart mode is enabled.

#### Scenario: Manual move still cascades mechanically first
- **WHEN** smart mode is enabled
- **AND** the user moves an unfinished active study task
- **THEN** the selected task and later same-project unfinished tasks shift by the same delta as defined by ITEM-003
- **AND** any smart proposal appears only after that mechanical result is persisted and refreshed

#### Scenario: Add and delete remain literal
- **WHEN** smart mode is enabled
- **AND** the user adds or deletes an active study task
- **THEN** the add or delete follows ITEM-003 literal semantics
- **AND** smart mode does not silently move other tasks during the action

#### Scenario: Rest-day cascade remains deterministic
- **WHEN** smart mode is enabled
- **AND** the user adds a rest day
- **THEN** D27's deterministic cascade runs as defined by ITEM-003
- **AND** smart mode only evaluates proposals after the cascade result is known

### Requirement: V1 Agent Isolation
The system SHALL keep v2 smart mode isolated from v1 autonomous learning agents and broad chat proposal flows.

#### Scenario: Smart mode does not use old chat proposal state
- **WHEN** smart-mode proposals are generated or applied
- **THEN** the system does not use `/api/chat` or `/api/chat/confirm`
- **AND** Swift smart-mode UI does not set legacy `chatMessages` or `currentProposal`

#### Scenario: Default dashboard still avoids v1 briefing
- **WHEN** the dashboard refreshes in default mode
- **THEN** it uses v2 study views
- **AND** it does not call `/api/today-briefing`

#### Scenario: Existing v1 routes remain historical
- **WHEN** ITEM-004 is complete
- **THEN** existing v1 routes and specs remain available unless a later retirement change modifies them
- **AND** the v2 app path does not depend on their autonomous behavior
