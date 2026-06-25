## MODIFIED Requirements

### Requirement: Focus timeline observation is decoupled from desk status line

Updates to the desk-pet **status line countdown string alone** SHALL NOT invalidate the focus timeline presenter skeleton or trigger full grid layout. The learning desk panel root SHALL NOT observe the full `AppViewModel` such that unrelated `@Published` fields (including status line text) invalidate the entire learning panel body including Today Todo sections.

#### Scenario: Status line tick without session change

- **WHEN** manual work countdown text changes each second but no focus session is finalized and phase boundaries are unchanged
- **THEN** the focus timeline presenter may update live overlay fields
- **AND** MalDaze does not publish a full new skeleton model solely because the status line string changed
- **AND** MalDaze does not re-layout unrelated learning panel sections solely because the status line string changed
