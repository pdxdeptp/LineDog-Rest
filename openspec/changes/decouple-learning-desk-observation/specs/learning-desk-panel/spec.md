## MODIFIED Requirements

### Requirement: Dashboard middle column hosts learning desk panel

The desk pet Dashboard middle adaptive content area SHALL host the learning desk panel (`LearningDeskPanelView`) between the fixed-width reminder sidebar and the fixed-width desk-pet controls column. The learning desk panel SHALL use a narrowed observation surface for timeline and task UI such that AppViewModel status line updates alone do not invalidate the entire panel body.

#### Scenario: Middle column shows learning panel

- **WHEN** the user opens the desk pet Dashboard panel on a screen wide enough for the minimum three-column width
- **THEN** the middle column renders `LearningDeskPanelView`
- **AND** the learning panel coexists with the reminder sidebar and desk-pet controls column

#### Scenario: Status line does not invalidate whole learning panel

- **WHEN** the desk pet status line countdown updates without learning data changes
- **THEN** MalDaze does not require a full recomputation of the learning panel Today Todo layout solely due to that status line update
