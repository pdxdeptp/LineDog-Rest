## Context

The Dashboard left "计划" sidebar renders `ReminderDisplayItem` values produced from EventKit reminders. The current display item intentionally preserves title, due date, explicit-time state, and whether notes contain the `#日常` marker, but it does not preserve the remaining notes text. `DeskReminderEditSheet` can still load and edit notes via `ReminderEditDetail`, so the loss is limited to the sidebar display projection.

## Goals / Non-Goals

**Goals:**

- Carry plain reminder notes through the EventKit-to-sidebar display mapping.
- Show non-empty notes below the reminder title using secondary, compact text that fits the fixed-width left column.
- Keep standalone `#日常` marker lines hidden from note text while preserving the existing routine badge.
- Cover the data mapping and UI contract with focused tests.

**Non-Goals:**

- Changing EventKit storage, reminder edit behavior, list selection, fetch windows, or reminder mutation flows.
- Adding rich text, Markdown rendering, disclosure expansion, or full reminder-detail editing in the list row.
- Displaying internal routine marker lines as visible note content.

## Decisions

- Store a `notesPlain` string on `ReminderDisplayItem`.
  - Rationale: the sidebar already uses this projection as its single render source; adding the plain-note field keeps UI rendering synchronous and avoids per-row EventKit detail fetches.
  - Alternative considered: load `ReminderEditDetail` for each visible row. That would add asynchronous row state, extra EventKit calls, and more failure modes for a read-only display.

- Reuse the existing routine-marker stripping behavior for display notes.
  - Rationale: `ReminderEditDetail` already defines plain notes as reminder notes without standalone `#日常`; the sidebar should display the same human-facing text.
  - Alternative considered: display raw notes and rely on the badge to make the marker understandable. That would expose implementation tags as content and duplicate routine information.

- Render notes directly under the title with a small line limit.
  - Rationale: the left column is fixed width, so compact secondary text restores context without making rows unbounded.
  - Alternative considered: require click-to-expand details. That would hide the context by default and add interaction state outside the reported regression.

## Risks / Trade-offs

- Longer notes can increase row height -> cap the visible note text with a line limit and secondary styling.
- Tests may rely on source-level checks for SwiftUI presentation -> combine targeted model/mapping tests with a small source assertion for the row rendering contract.
