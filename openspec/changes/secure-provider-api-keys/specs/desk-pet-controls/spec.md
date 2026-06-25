## MODIFIED Requirements

### Requirement: Dashboard right controls interactions

The Dashboard right controls column SHALL map each visible action to an explicit state-aware interaction while preserving existing view-model behavior. Provider API key entry SHALL persist through secure storage rather than plaintext preferences.

#### Scenario: Provider API key show hide

- **WHEN** the user edits a provider API key in Dashboard or settings surfaces
- **THEN** MalDaze reads and writes the key through secure storage
- **AND** the show/hide affordance behavior remains unchanged for the user
