## 1. RED regression tests

- [x] 1.1 Replace existing policy tests with failing resolution-table tests using spacing 2, draft 28, available 200: nil list → measuring/170/disabled; 169.5 → compact/169.5/disabled; 169.51 → pinned/170/enabled; 220 → pinned/170/enabled; available 20 → pinned/0/disabled
- [x] 1.2 Add failing policy tests for negative and non-finite inputs, missing draft measurement, measured/live width difference at and above 0.5pt, draft minimum above/below measured row height, draft height 120pt, and vertical capacity changes
- [x] 1.3 Add failing tests for `TodayTodoMeasuredGeometry` reduction in list-first and draft-first order, rejection of incomplete/invalid snapshots, and preservation of the last complete snapshot
- [x] 1.4 Add a failing macOS 13-compatible `NSHostingView` test proving a real ScrollView content probe reports full 100pt and 220pt list heights even when viewport height is capped
- [x] 1.5 Replace the token-only presentation test with failing guards for one draft mount, one `todoEntries` tree, exact `.frame(height:)`, permanent top and bottom anchors, source-agnostic mode anchoring, and absence of old mode state, estimated row height, hidden measurer, conditional draft placement, drag freeze, and mode animation

## 2. Pure policy and measurement model

- [x] 2.1 Implement `TodayTodoLayoutMode` and `TodayTodoLayoutResolution` in `TodayTodoLayoutPolicy.swift` with fixed 0.5pt tolerance, 28pt draft fallback, synchronous draft minimum, finite-value sanitization, and the exact D3 decision table
- [x] 2.2 Remove `compactStackHeight`, `shouldPinDraft`, `currentlyPinned`, hysteresis, and `estimatedRowHeight` after the new RED policy tests exist
- [x] 2.3 Implement `TodayTodoMeasuredGeometry` and a single aggregating PreferenceKey whose reduce merges optional list size and draft height independent of emitter order
- [x] 2.4 Commit measurement state only when both fields are complete and valid; ignore invalid/incomplete updates instead of overwriting the last complete snapshot

## 3. Stable content layout shell

- [x] 3.1 Create `MalDaze/LearningDeskPanel/TodayTodoContentLayout.swift`, add it to the MalDaze target, and define the fixed GeometryReader → ScrollViewReader → VStack → ScrollView/draft/Spacer structure from D2
- [x] 3.2 Give the ScrollView an exact resolved height, hidden indicators, top-leading alignment, and derived `scrollDisabled`; give the single draft sibling higher vertical layout priority and add no implicit mode animation
- [x] 3.3 Measure the actual width-constrained `todoEntries` and actual draft row in place using the aggregate PreferenceKey; delete the overlay/hidden duplicate list
- [x] 3.4 Implement measuring behavior for missing/invalid metrics and list-width mismatch, including capacity viewport, disabled list scrolling, and automatic resolution on the next complete snapshot
- [x] 3.5 Add permanent top and bottom anchors; without animation scroll top whenever mode becomes compact and scroll bottom whenever mode becomes pinned, regardless of whether the transition came from add, edit, group state, divider, or window resize
- [x] 3.6 Preserve current system scroll offset when viewport changes but resolved mode remains unchanged; mode observation must not write layout mode or inspect trigger source
- [x] 3.7 Implement undersized behavior: viewport zero and scrolling disabled when capacity is zero, with draft priority and no negative frames

## 4. TodayTodoSection integration

- [x] 4.1 Replace `TodayTodoSection.todoContentArea` with `TodayTodoContentLayout`, supplying the existing `todoEntries`, the one existing `draftFieldRow`, and synchronous `draftFieldHeight` as the safe draft-height lower bound
- [x] 4.2 Delete `isDraftPinned`, stored `contentAreaHeight`, separate list/draft Preference callbacks, `reevaluatePinMode`, entry-count/section-height/draft-height re-evaluation callbacks, conditional draft placement, stable-id workaround, and optimistic submit estimation
- [x] 4.3 Keep `sectionHeight` only as the outer section constraint; confirm `LearningDeskPanelView` adds no split-drag state parameter or absolute lower-height change
- [x] 4.4 Preserve add, failed/empty submit, inline edit, completed-group, delete, history, rollover hint, multi-line draft, and dashboard-open focus behavior
- [x] 4.5 Ensure mode/viewport changes neither increment `draftFocusRequestToken` nor run focus retries; successful submit retains the empty post-submit value and existing first responder

## 5. Reviews and automated verification

- [x] 5.1 Run the policy, measured-geometry, hosting-layout, todo store, and affected presentation tests with zero failures
- [x] 5.2 Run spec-compliance review against measuring/compact/pinned formulas, one-snapshot convergence, horizontal/vertical resize, offset reset, focus, and undersized scenarios; resolve all critical findings
- [x] 5.3 Run code-quality review for duplicate trees, multiple layout writers, Preference feedback loops, non-finite/negative frames, AppKit identity, macOS 13 availability, and newly introduced concurrency warnings; resolve all critical findings
- [x] 5.4 Build the MalDaze scheme successfully and record pre-existing warnings separately; confirm no new “Preference tried to update multiple times per frame” warning

## 6. Manual QA and documentation

- [ ] 6.1 At default window size, add short, wrapped, and rollover-hint todos through the first overflow; verify correct layout arrives after the next measurement without another user action
- [ ] 6.2 Enter pinned separately through successful add, divider shrink, horizontal reflow, and completed-group expansion; verify every source uses the same no-animation bottom anchor
- [ ] 6.3 While remaining pinned, drag the divider both directions and resize the dashboard vertically and horizontally; verify current offset is preserved, width remeasurement is safe, and text/first responder remain stable
- [ ] 6.4 Scroll in pinned mode, then delete/complete/collapse until compact; verify the list returns to its top anchor without animation and the draft follows the list
- [ ] 6.5 Verify multi-line draft growth through 120pt, internal draft scrolling beyond 120pt, completed-group expansion, inline-edit wrapping, uncompletion, empty submit, and persistence failure behavior
- [ ] 6.6 Verify default/minimum/maximum split ratios at default and 480×360 window sizes, including viewport-zero undersized recovery without negative frames
- [x] 6.7 Update learning desk documentation with the final measuring/compact/pinned, unified anchoring, tolerance, focus, and undersized semantics; run `openspec validate fix-today-todo-scroll-pin-threshold --strict`
