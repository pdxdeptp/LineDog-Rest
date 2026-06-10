## ADDED Requirements

### Requirement: Menu Turn semantic classification

The nutrition-menu skill SHALL define a **Menu Turn** as any Hermes agent turn in which the agent will provide—or has been asked to provide—user-visible advice about what to eat next from **today's remaining nutrition quota**.

Menu Turn classification SHALL be performed by the loaded Hermes agent using semantic understanding of user intent and the turn plan. Keyword lists, regex routing patterns, or ingress channel names MUST NOT be the sole authority for Menu Turn detection.

#### Scenario: Menu Turn yes for remaining-food planning

- **WHEN** the user asks—in any phrasing—that Hermes plan or recommend what they should eat next given today's remaining calories/macros
- **THEN** the agent classifies the turn as a Menu Turn
- **AND** the agent follows the Menu Turn publish workflow before treating the turn as complete

#### Scenario: Menu Turn yes after logging with replan intent

- **WHEN** the user records food and also asks what to eat next for the rest of today
- **THEN** the agent classifies the turn as a Menu Turn
- **AND** facts mutations complete before plan/author/publish

#### Scenario: Menu Turn no for logging only

- **WHEN** the user only records or undoes food without asking for next-step menu advice
- **THEN** the agent classifies the turn as not a Menu Turn
- **AND** the agent MUST NOT publish a fresh available recommendation solely because `plan_engine` ran

#### Scenario: Menu Turn no for status-only query

- **WHEN** the user only asks for today's intake progress or remaining macros without requesting menu advice
- **THEN** the agent classifies the turn as not a Menu Turn
- **AND** no publish/status gate applies

### Requirement: Menu Turn publish completion gate

When a turn is classified as a Menu Turn, Hermes SHALL NOT treat the turn as complete until `nutrition_authoring_publish.py status` returns `ok: true` with `state: available`, or until Hermes explicitly writes `state: unavailable` with a user-visible reason.

For Menu Turn YES, Hermes MUST execute this order:

1. Complete facts mutations first (`log`, `undo`, `day_classification`, `refresh-panel` as needed).
2. Run `plan_engine.py` for candidate context and author the final menu.
3. Run `nutrition_authoring_publish.py publish --stdin` with the same summary/suggestions shown to the user.
4. Run `nutrition_authoring_publish.py status` and verify fresh alignment.

Hermes MUST NOT tell the user that menu advice is synced to MalDaze before step 4 succeeds.

Hermes MUST NOT run facts-mutating nutrition commands after a successful publish in the same Menu Turn.

#### Scenario: Successful Menu Turn closes with fresh snapshot

- **WHEN** the agent completes a Menu Turn with authored menu advice
- **THEN** `recommendation.json.state` is `available`
- **AND** `basedOn.dailyLogPanelUpdatedAt` matches `daily_log.panel.updatedAt`
- **AND** `basedOn.recordsCount` matches `len(daily_log.records)`
- **AND** MalDaze can render loggable items without stale gating

#### Scenario: Menu Turn blocked on stale status

- **WHEN** the agent has replied with menu text but `nutrition_authoring_publish.py status` reports `stale` or not `ok`
- **THEN** the agent MUST run publish (or write unavailable) before ending the turn
- **AND** the agent MUST NOT claim the desk pet is updated

#### Scenario: Menu Turn unavailable path

- **WHEN** the agent cannot author a reliable remaining-food recommendation during a Menu Turn
- **THEN** Hermes writes `nutrition_authoring_publish.py unavailable --reason "..."`
- **AND** does not leave a stale available snapshot pretending to be fresh

### Requirement: Ingress-agnostic Menu Turn

Menu Turn rules SHALL apply to all Hermes nutrition ingress channels (Feishu DM, CLI, TUI, and future gateways) without separate publish procedures per channel.

#### Scenario: CLI nutrition conversation

- **WHEN** the user conducts a nutrition Menu Turn through Hermes CLI/TUI
- **THEN** the same publish/status completion gate applies
- **AND** `source.kind` identifies the Hermes nutrition flow, not a channel-specific Feishu owner
