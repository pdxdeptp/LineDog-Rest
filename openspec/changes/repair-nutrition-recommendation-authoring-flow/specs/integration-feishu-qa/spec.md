## ADDED Requirements

### Requirement: Feishu nutrition advice writes recommendation snapshot

The Feishu/Hermes nutrition QA flow SHALL verify that any Hermes nutrition reply containing next-step food advice writes the same advice to `~/.hermes/data/nutrition/recommendation.json`.

The QA SHALL use isolated nutrition data fixtures and MUST NOT mutate the user's live nutrition files.

#### Scenario: Feishu log then advice writes snapshot
- **WHEN** the QA simulates a Feishu nutrition update that records food
- **AND** the simulated Hermes authoring reply includes what to eat next
- **THEN** `recommendation.json.state` is `available`
- **AND** `source.kind` identifies the Feishu nutrition flow
- **AND** `basedOn.dailyLogPanelUpdatedAt` matches the post-log facts

#### Scenario: Feishu update without advice does not fake freshness
- **WHEN** the QA simulates a Feishu nutrition update that records food
- **AND** the simulated Hermes authoring reply does not include next-step food advice
- **THEN** no fresh available recommendation snapshot is written

### Requirement: Feishu QA checks day classification entrypoint

The Feishu/Hermes QA flow SHALL verify that production nutrition refresh instructions use `day_classification.py` rather than `recommend.py auto`.

#### Scenario: Skill uses standalone classifier
- **WHEN** QA inspects the nutrition skill workflow text
- **THEN** the production Morning Briefing refresh path references `python3 day_classification.py`
- **AND** it does not instruct Hermes to use `python3 recommend.py auto` for production Morning Briefing refresh
