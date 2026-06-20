## 1. Regression guards

- [x] 1.1 Add failing unit tests for list pointer Y flip and `insertionIndex` against frozen top-left frames
- [x] 1.2 Add failing unit tests that preview order changes during drag do not call store until settling completes
- [x] 1.3 Add failing presentation tests: no `TodayTodoListCoordinateAnchor`; require `TodayTodoListPointerReader`, `previewOrder`, and settling phase

## 2. Coordinate and session

- [x] 2.1 Implement `TodayTodoListPointerReader` covering full list area with AppKit→SwiftUI top-left Y conversion
- [x] 2.2 Refactor `TodayTodoReorderController` into phase-based session with `previewOrder`, `frozenRowFrames`, `grabOffsetY`, and settling/cancelling states
- [x] 2.3 Delete `TodayTodoListCoordinateAnchor.swift` and remove from Xcode target
- [x] 2.4 Freeze row frames/heights at drag begin; compute insertion only from frozen snapshots

## 3. Three-phase animation

- [x] 3.1 Implement pressing pick-up spring (scale/shadow) and dragging overlay that follows `listPointerY` without spring lag
- [x] 3.2 Animate neighbor gap offsets with spring when `insertionIndex` changes; drive order from `previewOrder` only
- [x] 3.3 Implement settling spring on drop before `store.reorderIncomplete`; implement cancelling spring on Esc without persist
- [x] 3.4 Keep layout placeholders opaque-to-layout for `TodayTodoMeasuredGeometryKey` during drag

## 4. Pinned scroll and integration

- [x] 4.1 Replace top/bottom `scrollTo` edge timer with continuous neighbor-id nudge during active drag
- [x] 4.2 Wire `InlineNotesTextView` to forward drag events to pointer reader/session (no local Y conversion)
- [x] 4.3 Verify reorder does not increment `draftFocusRequestToken` or animate layout mode

## 5. Verification and docs

- [x] 5.1 Run new unit tests, TodayTodo store/layout tests, and presentation tests with zero failures
- [x] 5.2 Build MalDaze scheme successfully
- [ ] 5.3 Manual QA: pick-up feedback, pointer follow, neighbor spring, drop settle, Esc cancel, pinned edge scroll
- [x] 5.4 Update `docs/integrations/features/learning-desk-panel.md` §4.4 with three-phase animation semantics
- [x] 5.5 Run `openspec validate fix-today-todo-reorder-animation --strict`
