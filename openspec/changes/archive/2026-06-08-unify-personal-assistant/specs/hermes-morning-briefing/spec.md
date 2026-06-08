## ADDED Requirements

### Requirement: Morning briefing includes today day reminders

The Hermes morning briefing SHALL include a section summarizing incomplete Apple Reminders due today or overdue, sourced through the same day-reminders query path used by the day-reminders capability.

#### Scenario: Briefing lists today reminders
- **WHEN** `morning-briefing.py` runs on schedule
- **THEN** the Feishu briefing includes a today day-reminders section
- **AND** each listed item is readable without opening the Reminders app

### Requirement: Morning briefing includes today learning pending tasks

The morning briefing SHALL include a section summarizing pending learning tasks scheduled for today from `projects.json` via the learning assistant today query.

#### Scenario: Briefing lists today learning tasks
- **WHEN** `morning-briefing.py` runs
- **THEN** the briefing includes pending learning tasks for the current local date
- **AND** items include enough identity for the user to complete them in Feishu conversation

### Requirement: Feishu briefing formatting avoids markdown tables

Day-reminder and learning sections in the morning briefing SHALL use Feishu-safe formatting such as line-oriented key-value rows or full-width separators and SHALL NOT use markdown tables.

#### Scenario: No markdown tables in new sections
- **WHEN** the briefing renders today reminder or learning sections
- **THEN** the output contains no markdown table syntax
- **AND** mobile Feishu layout remains readable

### Requirement: Existing briefing segments remain

The morning briefing extension SHALL preserve existing sleep, nutrition, and other established segments unless explicitly changed by another approved change.

#### Scenario: Sleep segment still present
- **WHEN** the extended briefing runs after this change
- **THEN** the existing sleep segment continues to appear
- **AND** new sections are additive rather than replacing sleep output
