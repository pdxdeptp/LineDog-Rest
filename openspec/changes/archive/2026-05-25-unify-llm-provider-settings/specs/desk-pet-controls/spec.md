## ADDED Requirements

### Requirement: Unified LLM provider settings module
The system SHALL present learning assistant and Smart Input LLM credentials through a shared provider/model/API-key settings module.

#### Scenario: Dedicated LLM settings category
- **WHEN** the redesigned MalDaze settings window renders
- **THEN** the system presents a dedicated settings category for model and API key configuration
- **AND** the category contains separate configuration surfaces for learning assistant and Smart Input
- **AND** both surfaces use the same provider picker, model picker, selected-provider API key row, saved/empty state, show/hide affordance, and local-only storage copy

#### Scenario: Shared module with feature-specific copy
- **WHEN** the learning assistant and Smart Input LLM settings surfaces render
- **THEN** both surfaces are built from the same reusable LLM settings module or helper
- **AND** each surface still communicates its feature-specific purpose
- **AND** visual styling, spacing, button treatment, and pale-blue active accents are consistent between the two surfaces

#### Scenario: Independent feature configuration
- **WHEN** the user changes provider, model, or API key for one feature
- **THEN** the system persists that feature's value independently
- **AND** the other feature's provider, model, and API key values are not changed

### Requirement: Smart Input provider selection
The system SHALL allow Smart Input reminder parsing to use Google Gemini, OpenAI, or DeepSeek.

#### Scenario: Smart Input supports the shared provider set
- **WHEN** the user configures Smart Input LLM settings
- **THEN** the provider picker offers Google Gemini, OpenAI, and DeepSeek
- **AND** the model picker shows the models for the selected Smart Input provider
- **AND** switching providers resets the Smart Input model to that provider's default model

#### Scenario: Smart Input selected-provider key
- **WHEN** the user selects a Smart Input provider
- **THEN** the API key row displays the selected provider's name and key label
- **AND** the key field reads and writes the selected provider's Smart Input API key storage
- **AND** the key remains hidden by default until the user explicitly shows it

#### Scenario: Existing Gemini Smart Input values remain usable
- **WHEN** the user has existing Smart Input Gemini settings from the previous Gemini-only implementation
- **THEN** Smart Input continues to resolve the existing Gemini API key and model for Gemini requests
- **AND** opening or using the new settings does not require the user to re-enter the existing Gemini key

### Requirement: Smart Input provider-aware runtime dispatch
The system SHALL dispatch Smart Input reminder parsing requests through the selected Smart Input provider and model.

#### Scenario: Smart Input request uses selected provider
- **WHEN** the user submits Smart Input text
- **THEN** the system resolves the Smart Input provider, model, and selected-provider API key at request time
- **AND** the reminder parsing request is sent through the selected provider client
- **AND** the provider response is normalized into the existing reminder JSON decoding flow

#### Scenario: Missing selected-provider key
- **WHEN** the selected Smart Input provider has no saved API key
- **THEN** the system does not create a reminder
- **AND** the user-facing error identifies the selected provider's API key as missing

#### Scenario: Smart Input provider changes take effect without restart
- **WHEN** the user changes Smart Input provider, model, or selected-provider API key in settings
- **THEN** the next Smart Input request uses the updated Smart Input configuration
- **AND** the app does not require restart for the Smart Input provider change
