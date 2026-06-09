## MODIFIED Requirements

### Requirement: Learning panel empty state directs conversational project creation

When no learning projects exist, the learning desk panel SHALL direct the user to create projects through Feishu or Hermes conversation (URL or "帮我安排学习"), and SHALL NOT offer in-panel project creation controls.

#### Scenario: Empty project tab
- **WHEN** `status` returns no projects
- **THEN** the project tab shows guidance to send a learning URL or intake phrase to Hermes conversation
- **AND** does not show a create-project button

#### Scenario: Insert sheet without active projects
- **WHEN** the user opens insert-task sheet with no active projects
- **THEN** the sheet explains that new projects must be created via Hermes conversation first
