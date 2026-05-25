## ADDED Requirements

### Requirement: Add Initiate Progress Events
The progress stream SHALL support Add / Initiate intake and plan-draft compilation stages without assuming the legacy URL-only ingestion sequence.

#### Scenario: Add Initiate session starts asynchronously
- **WHEN** the user submits an Add / Initiate item such as a text goal, URL, GitHub repo, note snippet, existing project item, interview prep item, or resume/project note
- **THEN** the system starts an Add / Initiate session and returns a session identifier immediately
- **AND** the session exposes the same progress-stage contract whether an individual backend step is streamed or completed synchronously
- **AND** no active tasks are created by starting the session

#### Scenario: Add Initiate session has stable identity
- **WHEN** Add / Initiate emits progress or review events
- **THEN** every event includes a stable session id
- **AND** draft-related events include draft id and draft version when those values exist
- **AND** stale events from a previous session cannot replace the current review state

#### Scenario: Add Initiate progress stages are emitted
- **WHEN** the client subscribes to progress for an Add / Initiate session
- **THEN** the stream can emit stage events such as `analyzing_input`, `routing_item`, `previewing_source`, `anchor_review`, `generating_phases`, `generating_tasks`, `validating_tasks`, `scheduling`, and `preparing_review`
- **AND** the stream can emit terminal or review states such as `role_review`, `needs_input`, `compile_failed`, `infeasible_review`, `draft_review`, `stored_non_plan`, `material_attached`, `activation_failed`, `activated`, `cancelled`, or `error`

#### Scenario: Add Initiate orchestration wraps existing helpers
- **WHEN** the UI advances a session after role confirmation or anchor confirmation
- **THEN** the orchestration adapter calls the completed router, draft, compiler, scheduler, or activation helper for that step
- **AND** it does not add new routing heuristics, generate new task logic, change scheduler math, or bypass draft activation guards

#### Scenario: Legacy URL ingestion sequence remains compatibility path
- **WHEN** the existing URL ingestion endpoint is used directly
- **THEN** it may continue to emit the legacy `fetch_structure`, `estimate_time`, `check_capacity`, and `draft_ready` stages
- **AND** Add / Initiate UI does not rely on that legacy phase sequence for non-URL or non-material inputs

#### Scenario: Add Initiate stream preserves draft safety
- **WHEN** the stream emits `draft_review`, `infeasible_review`, `needs_input`, or `compile_failed`
- **THEN** the event payload identifies whether the item is reviewable, blocked, or awaiting user input
- **AND** unconfirmed draft tasks remain excluded from Today and active Calendar facts
