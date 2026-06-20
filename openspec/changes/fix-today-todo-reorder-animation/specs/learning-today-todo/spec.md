## MODIFIED Requirements

### Requirement: Incomplete entries support animated drag reorder on text body

MalDaze SHALL allow reordering today's incomplete todo entries by dragging the entry's text body (title and visible rollover hint region) with continuous, perceptible animation across pick-up, drag, and drop. The row SHALL NOT show a separate reorder handle or grip icon. Reorder SHALL persist each entry's relative order through existing `sortIndex` values in `today-todo.json` only after drop settling animation completes.

Pointer position and row layout measurements used for insertion SHALL share one list coordinate space with a top-left origin. During drag, MalDaze SHALL derive order from an in-memory preview sequence and SHALL NOT write JSON until settling finishes. Reorder interaction SHALL coexist with inline edit, checkbox completion, delete, and compact/pinned layout without changing draft focus tokens or layout mode animation rules.

#### Scenario: Long-press text begins animated reorder

- **WHEN** two or more incomplete entries are visible and the user presses and holds the text body of one entry for at least 350ms then moves the pointer at least 4pt
- **THEN** MalDaze enters reorder mode for that entry
- **AND** animates pick-up with subtle scale and shadow
- **AND** shows a floating copy that follows the pointer continuously without spring lag
- **AND** animates neighboring rows with spring motion to open a 2pt insertion gap at the target position
- **AND** does not begin inline editing for that press

#### Scenario: Quick click still edits

- **WHEN** the user clicks the text body without satisfying the long-press reorder threshold
- **THEN** MalDaze begins inline editing as today
- **AND** does not enter reorder mode

#### Scenario: Editing blocks reorder

- **WHEN** an entry is currently in inline edit mode
- **THEN** MalDaze does not start reorder from that entry's text body until editing ends

#### Scenario: Drop commits order after settling animation

- **WHEN** the user releases the pointer after moving an entry to a new insertion index
- **THEN** MalDaze first animates the row into place with spring motion
- **AND** persists updated `sortIndex` values only after that settling animation completes
- **AND** renders the list in the new order without an instantaneous jump

#### Scenario: Cancel restores original order with animation

- **WHEN** the user presses Esc or ends the drag outside the valid reorder region before commit
- **THEN** MalDaze animates the row back to its original position with spring motion
- **AND** does not write a new order to JSON

#### Scenario: Dragging follows pointer in list coordinates

- **WHEN** the user moves the pointer while dragging an entry
- **THEN** MalDaze updates insertion using pointer and row positions in the same list coordinate space
- **AND** the floating row tracks the pointer without relying on a zero-size coordinate anchor

#### Scenario: Single incomplete entry has no reorder affordance

- **WHEN** only one incomplete entry exists for today
- **THEN** MalDaze does not offer drag reorder on the text body

#### Scenario: Checkbox and delete remain independent

- **WHEN** the user clicks the completion checkbox or delete control
- **THEN** MalDaze performs completion or delete
- **AND** does not enter reorder mode

#### Scenario: Reorder does not disturb pinned layout focus

- **WHEN** reorder starts or ends while the todo section is in pinned or compact layout
- **THEN** MalDaze does not increment draft focus request tokens
- **AND** does not animate layout mode or viewport changes as part of reorder
- **AND** MAY continuously auto-scroll the pinned list when the pointer nears the viewport edge during drag

#### Scenario: No separate reorder handle is shown

- **WHEN** the today todo incomplete list renders
- **THEN** rows use the standard checkbox, text, and delete layout
- **AND** do not render a dedicated reorder grip icon or extra leading control column
