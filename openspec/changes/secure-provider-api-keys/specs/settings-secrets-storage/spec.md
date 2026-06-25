## ADDED Requirements

### Requirement: Provider API keys use secure storage

MalDaze SHALL store LLM provider API keys in the system keychain or equivalent secure storage. MalDaze SHALL NOT persist API keys as plaintext values in standard user preferences after migration.

#### Scenario: Save key from settings

- **WHEN** the user saves a provider API key in MalDaze settings
- **THEN** MalDaze stores the value in secure storage
- **AND** MalDaze does not write the plaintext key to `UserDefaults`

#### Scenario: Migrate legacy plaintext key

- **WHEN** MalDaze finds a provider API key only in legacy preferences
- **THEN** MalDaze copies it to secure storage
- **AND** removes the plaintext preference entry

#### Scenario: Logs do not print secrets

- **WHEN** MalDaze logs settings or diagnostic output
- **THEN** API key material is redacted or omitted
