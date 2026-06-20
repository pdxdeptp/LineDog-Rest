## MODIFIED Requirements

### Requirement: Today tab section supports quick add and complete

The learning desk panel today tab SHALL render a **今日 todo** section below the Hermes task list with checkbox completion, inline edit, and delete without confirmation dialog. The section SHALL keep one stable draft input while adapting the list viewport within the todo content area:

- **Measuring mode** — before a complete valid list-and-draft measurement exists, or while measured list width differs from current width by more than 0.5pt, the list viewport SHALL use the safe remaining capacity, scrolling SHALL be disabled, and the draft SHALL keep its single stable position.
- **Compact mode** — when actual list height is no greater than `capacity - 0.5pt`, the list viewport SHALL equal actual list height, the draft SHALL appear immediately below the list, and remaining space SHALL follow the draft.
- **Pinned mode** — when actual list height is greater than `capacity - 0.5pt`, the list viewport SHALL equal capacity, scrolling SHALL be enabled when capacity and list height are positive, and the draft SHALL remain at the content-area bottom.

Here `capacity = max(contentAreaHeight - safeDraftHeight - spacing, 0)`, where `safeDraftHeight` is the maximum of the measured draft row, the synchronously reported draft editor height, and the 28pt initial fallback. Layout SHALL use actual rendered list and draft-row measurements, including wrapped titles, rollover hints, inline-edit wrapping, completed-group expansion, and the draft's 24–120pt growth range. A content change MAY use the previous complete snapshot for one internal measurement cycle, but SHALL apply the next complete snapshot without requiring another user action. Compact/pinned changes SHALL preserve the draft's structural identity and focus according to the scenarios below.

Scroll anchoring SHALL depend only on the resolved target mode, not on whether the transition was caused by submission, editing, completion-group changes, divider drag, or window resize. Every transition into pinned SHALL move to the bottom anchor without animation; every transition into compact SHALL move to the top anchor without animation. Viewport changes that keep the same mode SHALL preserve the current system scroll offset.

#### Scenario: Add with Enter
- **WHEN** the user types a non-empty trimmed title and submits the input with Return
- **THEN** a new incomplete entry appears in the today todo section
- **AND** the input clears
- **AND** the draft retains keyboard focus when the window remains key

#### Scenario: Empty or failed submission preserves draft
- **WHEN** submission is rejected because the trimmed draft is empty or persistence does not succeed
- **THEN** MalDaze does not restore or invent layout state
- **AND** preserves the current draft text and focus behavior

#### Scenario: Initial measurement is safe
- **WHEN** the today todo content first appears without a complete valid measurement snapshot
- **THEN** the list uses measuring mode with a non-negative viewport
- **AND** the draft remains at its single stable position
- **AND** compact or pinned mode is applied after the first complete snapshot

#### Scenario: Compact input follows list
- **WHEN** actual list height is no greater than capacity minus 0.5pt
- **THEN** the draft renders directly below the list
- **AND** the todo list does not scroll independently
- **AND** remaining vertical space appears below the draft

#### Scenario: First completed overflow measurement pins input
- **WHEN** adding, editing, expanding, or reflowing content produces a complete measurement whose list height is greater than capacity minus 0.5pt
- **THEN** MalDaze enables pinned layout from that snapshot
- **AND** places the draft at the todo content-area bottom
- **AND** scrolls the permanent list to its bottom anchor without animation
- **AND** does not wait for another todo entry, additional divider movement, a timer, or a fixed estimated row height

#### Scenario: All pinned transition sources share one anchor rule
- **WHEN** any content change, divider drag, or window resize changes resolved mode from measuring or compact to pinned
- **THEN** MalDaze scrolls to the same bottom anchor without animation
- **AND** does not branch on the source of the transition

#### Scenario: Resize inside pinned preserves current offset
- **WHEN** divider or window resize changes pinned viewport size without changing resolved mode
- **THEN** MalDaze preserves the current system scroll offset
- **AND** does not issue another forced top or bottom scroll

#### Scenario: Variable-height entry participates in overflow
- **WHEN** a todo title or inline edit wraps to additional lines or displays a rollover hint
- **THEN** compact versus pinned layout uses the entry's actual rendered height at the current width
- **AND** the draft remains at its single structural position

#### Scenario: Draft grows and reaches its outer height cap
- **WHEN** Shift+Return increases the draft input row height up to 120pt
- **THEN** the synchronously reported editor height immediately lowers list capacity when it exceeds the previous measured row height
- **AND** the next complete draft-row measurement supplies the final capacity
- **AND** additional draft content beyond the cap scrolls inside the draft control rather than further shrinking the list viewport

#### Scenario: Remove content returns to compact at top offset
- **WHEN** deleting, completing, collapsing, or shortening content produces a list height no greater than capacity minus 0.5pt
- **THEN** MalDaze returns to compact mode
- **AND** resets the permanent ScrollView to its top anchor without animation
- **AND** the draft follows the list without being recreated

#### Scenario: Resize preserves active draft
- **WHEN** divider drag or dashboard resize crosses the compact/pinned boundary while the draft has keyboard focus
- **THEN** the same draft AppKit view remains first responder while the window remains key
- **AND** the current draft text remains unchanged
- **AND** layout does not issue a new focus request or mode-change animation

#### Scenario: Successful add preserves post-submit state
- **WHEN** successful Return submission crosses the compact/pinned boundary
- **THEN** the draft remains focused with its normal post-submit empty value
- **AND** MalDaze does not restore the submitted text as part of focus preservation

#### Scenario: Content area cannot contain draft
- **WHEN** content-area height is less than actual draft-row height plus spacing
- **THEN** list viewport height is zero and list scrolling is disabled
- **AND** MalDaze keeps the draft as the prioritized sibling even if the outer pane must clip physical overflow
- **AND** normal measuring, compact, or pinned behavior resumes when sufficient space returns

#### Scenario: Complete retains strikethrough
- **WHEN** the user marks an entry complete
- **THEN** the entry remains in the today todo section under a collapsed completed group
- **AND** renders with strikethrough styling
- **AND** records `completedAt`

#### Scenario: Uncomplete restores incomplete list
- **WHEN** the user unchecks a completed entry
- **THEN** the entry returns to the incomplete list for today
- **AND** clears or nulls `completedAt` as appropriate

#### Scenario: Delete entry
- **WHEN** the user deletes an entry from the row menu
- **THEN** MalDaze removes it from JSON without a confirmation dialog
