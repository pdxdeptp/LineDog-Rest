## ADDED Requirements

### Requirement: Learning Assistant surface is retired
The system SHALL NOT expose the retired Learning Assistant as an in-app dashboard, settings category, local backend, launch agent, API client, or bundled service.

#### Scenario: Dashboard has no learning assistant column
- **WHEN** the user opens the desk pet Dashboard Panel
- **THEN** the panel does not render `AssistantPanelView` or any equivalent Learning Assistant column
- **AND** the retained reminder and desktop pet controls remain reachable

#### Scenario: Settings have no learning assistant category
- **WHEN** the user opens MalDaze settings
- **THEN** the settings window does not show a Learning Assistant category
- **AND** it does not show learning-assistant backend provider, model, API-key, or lazy-startup controls

#### Scenario: Backend service is absent
- **WHEN** the app launches or the dashboard opens
- **THEN** the app does not start or depend on `assistant_backend`
- **AND** no Learning Assistant launch-agent plist or bundled backend resource is required for app startup

#### Scenario: Study and ingestion APIs are absent
- **WHEN** the codebase is searched for active app calls to study, ingestion, chat, morning, review, or resource-management Learning Assistant APIs
- **THEN** no retained Swift app code calls those APIs

### Requirement: Retained MalDaze features remain available
The system SHALL preserve non-learning MalDaze functionality after Learning Assistant removal.

#### Scenario: Retained controls remain in dashboard
- **WHEN** the user opens the desk pet Dashboard Panel
- **THEN** timer, break/rest, pet visual, Smart Reminder, hydration, seven-minute reminder, and system Reminders controls that existed outside the Learning Assistant remain available

#### Scenario: Smart Reminder remains configured
- **WHEN** the user opens model/API-key settings for retained Smart Reminder behavior
- **THEN** Smart Reminder provider, model, selected-provider API-key, and shortcut configuration remain reachable

