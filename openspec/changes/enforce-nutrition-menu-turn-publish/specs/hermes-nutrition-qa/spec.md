## ADDED Requirements

### Requirement: Hermes nutrition Menu Turn QA fixtures

Hermes SHALL provide isolated nutrition QA coverage for Menu Turn publish discipline using temporary `NUTRITION_DATA_DIR` fixtures. QA MUST NOT mutate the user's live nutrition files.

The QA module SHALL use Hermes-oriented naming (`hermes_nutrition`, `HermesNutrition*`) and MUST NOT require Feishu-specific identifiers in nutrition authoring assertions.

#### Scenario: Menu Turn log then advice writes fresh snapshot

- **WHEN** QA simulates a Menu Turn that records food and authors next-step advice
- **THEN** `recommendation.json.state` is `available`
- **AND** `source.kind` is `hermes_nutrition`
- **AND** `basedOn.dailyLogPanelUpdatedAt` matches post-log `daily_log.panel.updatedAt`
- **AND** `basedOn.recordsCount` matches `len(daily_log.records)`

#### Scenario: Log without Menu Turn does not fake freshness

- **WHEN** QA simulates a facts-only nutrition update without next-step menu advice
- **THEN** no fresh available recommendation snapshot is written

### Requirement: Skill documents Menu Turn semantic rubric

QA SHALL verify the nutrition-menu skill documents:

- Menu Turn semantic YES/NO criteria
- publish → status completion gate for Menu Turn YES
- ingress-agnostic Hermes agent wording (no Feishu-owned recommendation naming)

#### Scenario: Skill contains Menu Turn gate

- **WHEN** QA inspects `nutrition-menu` skill workflow text
- **THEN** it describes Menu Turn semantic classification by the agent
- **AND** it requires `nutrition_authoring_publish.py publish --stdin` followed by `status` before claiming desk pet sync
- **AND** it does not present keyword routing as the Menu Turn authority

#### Scenario: Skill uses hermes_nutrition in publish examples

- **WHEN** QA inspects publish stdin examples in the nutrition-menu skill
- **THEN** `source.kind` is `hermes_nutrition`
- **AND** nutrition production docs do not use `feishu_nutrition` as the canonical kind

### Requirement: Renamed Hermes nutrition integration test module

The nutrition integration QA test file SHALL be named `test_integration_hermes_nutrition_qa.py` (replacing Feishu-specific nutrition test naming).

#### Scenario: Test module rename

- **WHEN** developers run nutrition authoring integration tests
- **THEN** they invoke `test_integration_hermes_nutrition_qa.py`
- **AND** the old `test_integration_feishu_nutrition_qa.py` path is not retained
