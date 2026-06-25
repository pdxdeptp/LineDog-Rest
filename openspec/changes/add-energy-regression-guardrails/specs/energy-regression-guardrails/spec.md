## ADDED Requirements

### Requirement: Energy regression guardrails are enforced in tests

MalDaze SHALL maintain automated source-level guardrails that fail when known high-idle-wakeup patterns reappear in production code paths for the desk pet dashboard, focus timeline presenter, and timer engines.

#### Scenario: Focus timeline live gating guardrail

- **WHEN** a contributor reintroduces unconditional live tick scheduling on timeline consumer visible
- **THEN** the energy regression test suite fails in development or CI

#### Scenario: Dashboard hide quiescence guardrail

- **WHEN** a contributor removes Dashboard hide pause hooks for registered quiescent consumers
- **THEN** the energy regression test suite fails in development or CI

#### Scenario: Documented invariants list

- **WHEN** a contributor adds a new Dashboard-scoped repeating timer or file watcher
- **THEN** project documentation lists the requirement to register with Dashboard quiescence
- **AND** the change is reviewed against the energy invariants document
