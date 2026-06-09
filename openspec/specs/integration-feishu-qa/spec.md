# integration-feishu-qa Specification

## Purpose

Automated Feishu-dialogue proxy QA: CLI chains Hermes skills invoke after NL parsing, plus MalDaze countdown bell title verification.
## Requirements
### Requirement: Feishu-proxy day reminder roundtrip

The integration QA script SHALL simulate a Feishu day-reminder create flow by invoking `day_reminders.py create` with a unique marker title and due date, then verify the item appears in `list-today` (or `complete --query` pool) and can be completed.

#### Scenario: Create then complete via CLI proxy
- **WHEN** the QA script runs the day-reminder proxy chain
- **THEN** `create` returns `ok: true`
- **AND** `complete --query` succeeds for the marker
- **AND** the report marks `day_reminder_feishu_proxy.ok: true`

### Requirement: Feishu-proxy learning complete by index

The integration QA script SHALL simulate「完成 1」by reading `schedule.py today` pending list in an isolated data directory, completing `pending[0]` by `task_id`, and verifying JSON completion only (no external calendar projection).

#### Scenario: Complete first pending task
- **WHEN** isolated fixtures include one pending task
- **AND** the script runs `complete --task-id` for index 1
- **THEN** task status becomes `completed` in JSON
- **AND** the complete response does not include `calendar.action` or `calendar_errors`

### Requirement: Countdown bell uses contract title

MalDaze SHALL present the intervention contract `title` as the center bell message when a Hermes countdown finishes, not the generic「X 分钟计时结束」template.

#### Scenario: 30-minute countdown completion message
- **WHEN** `InterventionRequestController` starts a countdown with `minutes: 30` and `title: "红薯煮好了"`
- **THEN** `SevenMinuteReminderController` receives `completionMessage` equal to the title
- **AND** when the countdown finishes, the bell message equals the title

#### Scenario: Smoke accepts 30-minute contract
- **WHEN** Hermes writes a `countdown` intervention with `minutes: 30`
- **AND** MalDaze is running
- **THEN** the pending file is consumed within the smoke wait window

