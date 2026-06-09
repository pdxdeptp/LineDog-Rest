## ADDED Requirements

### Requirement: Create-project CLI for conversational intake

Hermes `schedule.py` SHALL provide a `create-project` subcommand that creates an active learning project entry in `projects.json` with `id`, `name`, `deadline`, optional `source_url`, and empty `tasks[]`, without requiring manual JSON editing.

#### Scenario: Create new active project
- **WHEN** Hermes invokes `create-project --id <id> --name <name> --deadline <YYYY-MM-DD>`
- **THEN** `projects.json` contains a new project with `status: active` and `tasks: []`
- **AND** stdout JSON includes `project_id` and `deadline`

#### Scenario: Duplicate project id rejected
- **WHEN** `create-project` is invoked with an `id` that already exists
- **THEN** Hermes exits with an error
- **AND** does not modify existing project tasks

### Requirement: Plan after single conversational confirmation

For new project intake, Hermes SHALL treat the user's confirmation of the task list as the only required confirmation before invoking `create-project` followed by `plan`. Hermes SHALL NOT require `plan --dry-run` for new project creation.

#### Scenario: Confirmed task list then plan
- **WHEN** the user confirms the decomposed task list in conversation
- **THEN** Hermes runs `create-project` then `plan --project-id <id> --tasks-file <file>`
- **AND** reports `scheduled` and `overflow` counts from plan output in the conversational reply
