## ADDED Requirements

### Requirement: Add Initiate Progress Events
The progress stream SHALL support Add / Initiate intake and plan-draft compilation stages without assuming the legacy URL-only ingestion sequence.

#### Scenario: Add Initiate session starts asynchronously
- **WHEN** the user submits an Add / Initiate item such as a text goal, URL, GitHub repo, note snippet, existing project item, interview prep item, or resume/project note
- **THEN** the backend starts an asynchronous intake session and returns a session identifier immediately
- **AND** no active tasks are created by starting the session

#### Scenario: Add Initiate progress stages are emitted
- **WHEN** the client subscribes to progress for an Add / Initiate session
- **THEN** the stream can emit stage events such as `analyzing_input`, `routing_item`, `previewing_source`, `generating_phases`, `generating_tasks`, `validating_tasks`, `scheduling`, and `preparing_review`
- **AND** the stream can emit terminal or review states such as `role_review`, `needs_input`, `compile_failed`, `infeasible_review`, `draft_ready`, `stored_non_plan`, or `error`

#### Scenario: Legacy URL ingestion sequence remains compatibility path
- **WHEN** the existing URL ingestion endpoint is used directly
- **THEN** it may continue to emit the legacy `fetch_structure`, `estimate_time`, `check_capacity`, and `draft_ready` stages
- **AND** Add / Initiate UI does not rely on that legacy phase sequence for non-URL or non-material inputs

#### Scenario: Add Initiate stream preserves draft safety
- **WHEN** the stream emits `draft_ready`, `infeasible_review`, `needs_input`, or `compile_failed`
- **THEN** the event payload identifies whether the item is reviewable, blocked, or awaiting user input
- **AND** unconfirmed draft tasks remain excluded from Today and active Calendar facts
