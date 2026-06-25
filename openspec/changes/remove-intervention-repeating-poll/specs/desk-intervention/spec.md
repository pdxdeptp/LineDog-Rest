## MODIFIED Requirements

### Requirement: Intervention request lifecycle watching

MalDaze SHALL watch `intervention_request.json` and reload on application start, FSEvents change, workspace wake, and foreground activation, following the same reliability pattern as sleep schedule watching. MalDaze SHALL NOT rely on a repeating background poll timer as the primary or parallel always-on reload mechanism when FSEvents and lifecycle reconcile are active.

#### Scenario: File change triggers reload

- **WHEN** Hermes updates `intervention_request.json` while MalDaze is running
- **THEN** MalDaze reloads the contract within the file watcher debounce window
- **AND** MalDaze attempts execution if the payload is valid and unconsumed

#### Scenario: Startup processes unconsumed request

- **WHEN** MalDaze launches and a valid unconsumed pending request exists
- **THEN** MalDaze executes the request without requiring user action in MalDaze

#### Scenario: Wake reconciles after missed file event

- **WHEN** the workspace wakes or MalDaze becomes active
- **AND** a valid unconsumed pending request exists
- **THEN** MalDaze reloads and processes the request without requiring a repeating poll timer
