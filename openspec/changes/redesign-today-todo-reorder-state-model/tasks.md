## 1. Git safety and RED regression guards

- [ ] 1.1 Run `git status --short --branch`, identify overlapping today-todo user changes, and create the approved in-scope checkpoint commit required for non-worktree apply without including unrelated files
- [x] 1.2 Add failing controller tests for source-excluded target calculation across adjacent, multi-row, reverse, hysteresis, and variable-height cases
- [x] 1.3 Add failing pure-geometry tests proving affected neighbor offsets are non-zero, unaffected rows remain at zero, total height stays stable, and settle Y equals the projected target rather than source Y
- [x] 1.4 Add failing gesture-tracker tests with an injectable clock for quick-click editing, 350ms pressing, SwiftUI sync during pressing, 4pt activation, long-press/no-drag release without editing or stranded pressing state, valid-region exit (12pt tolerance), entries identity change abort, and Esc cancellation
- [x] 1.5 Add failing publication-boundary tests proving same-slot pointer movement updates only the pointer model and does not publish list-layout state
- [ ] 1.6 Add failing edge-scroll tests separating content-local and viewport-local Y, applying bounded delta, recomputing target after scroll, and stopping on exit/end/disappear
- [x] 1.7 Add failing settle/commit tests proving no persistence before animation completion, exactly one id/final-index commit after completion, no-op/cancel zero commits, and identity-change/onDisappear/stale-generation callbacks cannot commit

## 2. Fixed-slot reorder session

- [x] 2.1 Implement immutable `baseOrder`, source-excluded `targetIndex`, 2pt hysteresis, and pure `projectedGeometry` from frozen top-left row slots
- [x] 2.2 Replace drag-time `previewOrder` and insertion-boundary mutation with the fixed-slot session; publish phase/target changes only when their values actually change
- [x] 2.3 Add `TodayTodoDragPointerModel` as the separate high-frequency pointer channel and keep it unobserved by the parent list
- [x] 2.4 Add `TodayTodoStore.reorderIncomplete(draggedId:toFinalIndex:)` using existing `sortIndex` persistence semantics and make the new store/controller tests pass
- [x] 2.5 Refactor while tests stay green, then complete spec-compliance and code-quality review for the session/store task group before proceeding

## 3. Continuous AppKit gesture ownership

- [x] 3.1 Extract a testable long-press gesture tracker that snapshots enablement at mouseDown and uses common-run-loop or injectable scheduling
- [x] 3.2 Update `InlineNotesTextView` so the same mouse tracking sequence survives SwiftUI sync, pressing does not disable its event source, quick click enters inline editing, and long-press/no-drag release does not edit
- [x] 3.3 Keep the real row mounted and visible during pressing; create the placeholder and drag preview only after the 4pt activation threshold
- [x] 3.4 Implement the window-coordinate valid region with 12pt tolerance; cancel beyond it, and abort without commit on entries identity change or view disappearance in every non-idle phase
- [x] 3.5 Make all gesture lifecycle tests pass and complete spec-compliance and code-quality review for the gesture task group

## 4. Projected row animation and drop handoff

- [x] 4.1 Render the incomplete `ForEach` in immutable `baseOrder` throughout dragging/settling/cancelling and derive each non-source row offset only from `projectedGeometry`
- [x] 4.2 Replace the duplicate interactive row overlay with a lightweight, non-hit-testable SwiftUI drag preview that contains no `TodayTodoInlineText`, `NSTextView`, or live controls
- [x] 4.3 Animate only target-driven neighbor offsets with the specified spring, keep pointer-follow unsprung, and render the 2pt decorative target-slot indicator in the overlay layer outside measured list height (not an `insertionGap`-style layout shift)
- [x] 4.4 Implement generation-bound animation completion for macOS 13; settle to projected target Y, cancel to source Y, and remove the fixed-delay completion path
- [x] 4.5 Commit store order and reset session together in a no-animation transaction so projected and committed frames hand off without a jump
- [x] 4.6 Make geometry, publication, settle, and presentation tests pass, then complete spec-compliance and code-quality review for the rendering task group

## 5. Incremental pinned edge scroll

- [x] 5.1 Extend the pointer bridge to derive both content-local and viewport-local top-left coordinates from the same window point
- [x] 5.2 Add a lifecycle-safe AppKit scroll bridge that changes `NSClipView` bounds by bounded time-based deltas instead of calling `scrollTo` on first/last ids
- [ ] 5.3 Recompute content pointer Y and target index from `lastWindowPoint` after each scroll delta, while keeping frozen content slot geometry stable
- [x] 5.4 Stop edge scrolling on valid-region exit, drag end/cancel, identity invalidation, invalid bridge, compact non-scroll mode, and view disappearance
- [ ] 5.5 Make edge-scroll tests pass and complete spec-compliance and code-quality review for the scroll task group

## 6. Remove contradictory paths and update documentation

- [x] 6.1 Delete obsolete drag-time `previewOrder`, entry-id/frozen-frame iteration, row-offset double application, source-Y settling, fixed settling delay, and repeated first/last `scrollTo` timer code
- [x] 6.2 Remove unused reorder state/files and Xcode project references without changing unrelated pending work
- [x] 6.3 Replace source-string-only presentation assertions with structural guards for fixed base order, lightweight overlay, absence of fixed delay, and separated pointer/list publication
- [x] 6.4 Update `docs/integrations/features/learning-desk-panel.md` with fixed-slot, target settle, valid-region cancel, and incremental edge-scroll semantics; record the base-capability archive prerequisite and that the two prior unfinished reorder changes must not be archived

## 7. Verification and manual acceptance

- [x] 7.1 Run the focused reorder controller, gesture, store, layout, scroll, and presentation tests with zero failures and record exact commands/results
- [x] 7.2 Build the MalDaze scheme for macOS 13 compatibility and run broader affected LearningDeskPanel tests with zero failures
- [x] 7.3 Run `openspec validate redesign-today-todo-reorder-state-model --strict` and `git diff --check`
- [x] 7.4 Complete final spec-compliance review against every scenario and code-quality review for performance, lifecycle, error handling, and removal of old paths; resolve all critical findings
- [ ] 7.5 Perform and record Manual QA for quick click, long-press/no-drag release, 350ms pick-up, same-slot tracking, adjacent/multi-row/reverse drag, different-height rows, target settle, no-op, Esc, pointer beyond valid-region tolerance, view teardown during settle, compact/pinned, incremental edge scroll, and persistence after relaunch
- [ ] 7.6 Before archive, complete and archive `add-learning-today-todo`; block this change's archive while the canonical capability is absent, and never archive the two superseded reorder changes
- [ ] 7.7 Run fresh completion verification with evidence; do not mark the change complete while Manual QA, archive prerequisites, or either review remains open
