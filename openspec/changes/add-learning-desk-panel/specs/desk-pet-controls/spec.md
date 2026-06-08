## ADDED Requirements

### Requirement: Dashboard middle column hosts learning desk panel

The desk pet Dashboard middle adaptive content area SHALL host the learning desk panel (`LearningDeskPanelView`) between the fixed-width reminder sidebar and the fixed-width desk-pet controls column.

#### Scenario: Three-column layout on open
- **WHEN** the user opens the desk pet Dashboard panel on a screen wide enough for the minimum three-column width
- **THEN** the left column shows the reminder plan sidebar
- **AND** the middle column shows the learning desk panel
- **AND** the right column shows desk-pet controls
- **AND** the middle column receives remaining horizontal space above its minimum readable width

#### Scenario: Middle column minimum width
- **WHEN** Dashboard layout computes three-column sizing
- **THEN** the learning panel middle column maintains at least 360 points readable width before horizontal clipping
- **AND** left and right columns keep their existing fixed widths

#### Scenario: Learning panel does not replace side columns
- **WHEN** the learning desk panel is visible
- **THEN** the reminder sidebar and desk-pet controls column remain present and functional
- **AND** opening or interacting with the learning panel does not dismiss the Dashboard panel by itself
