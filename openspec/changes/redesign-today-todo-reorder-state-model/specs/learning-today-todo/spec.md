## ADDED Requirements

> **Delta 类型**：ADDED（非 MODIFIED）。animated reorder requirement 由本 change 首次引入；旧 change `redesign-today-todo-drag-reorder` 与 `fix-today-todo-reorder-animation` 未归档且已被本 change 取代。
>
> **归档顺序**：必须先归档 `add-learning-today-todo` 建立 canonical `learning-today-todo` capability，再归档本 change。

### Requirement: Incomplete entries support animated drag reorder on text body

MalDaze SHALL allow reordering today's incomplete todo entries by dragging the entry's text body (title and visible rollover hint region) with continuous, perceptible animation across pick-up, drag, and drop. The row SHALL NOT show a separate reorder handle or grip icon. Reorder SHALL persist each entry's relative order through existing `sortIndex` values in `today-todo.json` only after the drop settling animation actually completes.

During one gesture, MalDaze SHALL keep one immutable snapshot of the source order and row slots, SHALL represent the destination as one final target index, and SHALL NOT physically reorder the backing list or write JSON while dragging. Pointer position and row slots used for insertion SHALL share a content-local top-left coordinate space; viewport-edge scrolling SHALL use a separate viewport-local coordinate. The valid reorder region SHALL be the visible incomplete-list viewport expanded by 12pt in window coordinates. High-frequency pointer movement SHALL update the floating row without forcing unchanged list rows to remeasure or reconfigure their AppKit text views. Reorder interaction SHALL coexist with inline edit, checkbox completion, delete, and compact/pinned layout without changing draft focus tokens or layout mode animation rules.

#### Scenario: Long-press remains continuous through drag activation

- **WHEN** two or more incomplete entries are visible and the user presses and holds the text body for at least 350ms
- **THEN** MalDaze shows subtle pick-up scale and shadow on the same mounted row
- **AND** keeps the active text view able to receive the matching drag and mouse-up events
- **AND** does not replace the row with a placeholder until pointer movement reaches 4pt
- **AND** does not begin inline editing for that press

#### Scenario: Four-point movement activates reorder

- **WHEN** a long press is ready and pointer movement reaches at least 4pt
- **THEN** MalDaze creates a non-interactive floating preview for that entry
- **AND** keeps an invisible source placeholder in layout so measured list height remains stable
- **AND** the floating preview follows pointer movement continuously without spring lag

#### Scenario: Quick click still edits

- **WHEN** the user releases the text body before 350ms without reaching 4pt movement
- **THEN** MalDaze begins inline editing as today
- **AND** does not enter reorder mode

#### Scenario: Long press without drag does not strand pressing state

- **WHEN** the user holds for at least 350ms but releases before moving 4pt
- **THEN** MalDaze clears pick-up feedback and returns to idle
- **AND** does not leave the row hidden or its reorder gesture disabled
- **AND** does not begin inline editing for that long press
- **AND** does not write a new order

#### Scenario: Editing blocks reorder

- **WHEN** an entry is currently in inline edit mode
- **THEN** MalDaze does not start reorder from that entry's text body until editing ends

#### Scenario: Target slot remains stable across continuous and reverse movement

- **WHEN** the floating row crosses one or more neighboring row midpoints and then reverses direction
- **THEN** MalDaze derives each target index from the immutable spatial slot snapshot with the source row excluded
- **AND** changes target exactly as the floating row crosses the corresponding adjacent boundary
- **AND** does not skip, oscillate, or reverse a target because the preview order changed

#### Scenario: Neighbor rows animate to projected positions

- **WHEN** the target index changes during dragging
- **THEN** each affected non-dragged row animates with spring motion from its frozen position to its projected final position
- **AND** unaffected rows remain stationary
- **AND** a 2pt-thick decorative insertion indicator at the target slot remains visible in the overlay layer without changing measured list height (visual gap comes from projected neighbor offsets, not layout-affecting spacing)
- **AND** the backing `ForEach` identity order remains unchanged until commit

#### Scenario: Pointer movement has bounded rendering impact

- **WHEN** the pointer moves within the same target slot
- **THEN** MalDaze updates the floating preview position
- **AND** does not reconfigure unchanged AppKit text rows or invalidate their intrinsic size
- **AND** does not publish a new list-layout state until the phase or target index changes

#### Scenario: Drop commits order after target settling

- **WHEN** the user releases after moving an entry to a different target index
- **THEN** MalDaze springs the floating row to the target position derived from the same projected geometry as neighboring rows
- **AND** persists updated `sortIndex` values exactly once only after that animation reaches its target
- **AND** hands off from projected positions to the committed list without an instantaneous jump
- **AND** does not use the source position as the settling target

#### Scenario: No-op drop returns without persistence

- **WHEN** the user releases with the target index equal to the source index
- **THEN** MalDaze animates the floating row back to the source position
- **AND** restores all row offsets to zero
- **AND** does not write a new order

#### Scenario: Pointer or keyboard cancel restores original order with animation

- **WHEN** the user presses Esc or moves beyond the 12pt valid-region tolerance before commit
- **THEN** MalDaze animates the floating row and neighboring rows back to their frozen source positions
- **AND** clears the active gesture without disabling future reorder gestures
- **AND** does not write a new order to JSON

#### Scenario: Data or view invalidation aborts pending reorder

- **WHEN** the incomplete-entry identity sequence changes before commit or the containing view disappears during any active reorder phase
- **THEN** MalDaze invalidates pending animation completion and scrolling callbacks
- **AND** clears the session without committing the stale order
- **AND** animates back only when the source view remains mounted

#### Scenario: Dragging and edge detection use explicit coordinate spaces

- **WHEN** the user moves the pointer while dragging, including after the pinned list has scrolled
- **THEN** MalDaze computes insertion from content-local pointer and slot positions with a top-left origin
- **AND** computes edge-scroll velocity from viewport-local pointer position
- **AND** never compares content-local pointer Y directly with viewport height

#### Scenario: Pinned edge scroll is incremental

- **WHEN** the pointer remains near the top or bottom edge of a scrollable pinned list during drag
- **THEN** MalDaze scrolls by bounded time-based increments rather than repeatedly jumping to the first or last entry
- **AND** recomputes content-local pointer position and target index after each actual scroll increment
- **AND** stops scrolling when the pointer leaves the edge, reorder ends, or the view disappears

#### Scenario: Single incomplete entry has no reorder affordance

- **WHEN** only one incomplete entry exists for today
- **THEN** MalDaze does not offer drag reorder on the text body

#### Scenario: Checkbox and delete remain independent

- **WHEN** the user clicks the completion checkbox or delete control while no reorder gesture is active
- **THEN** MalDaze performs completion or delete
- **AND** does not enter reorder mode

#### Scenario: Reorder does not disturb pinned layout focus

- **WHEN** reorder starts or ends while the todo section is in pinned or compact layout
- **THEN** MalDaze does not increment draft focus request tokens
- **AND** does not animate layout mode or viewport-size changes as part of reorder

#### Scenario: No separate reorder handle is shown

- **WHEN** the today todo incomplete list renders
- **THEN** rows use the standard checkbox, text, and delete layout
- **AND** do not render a dedicated reorder grip icon or extra leading control column
