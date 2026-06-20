## 1. Spec and regression guards

- [x] 1.1 Add failing presentation tests asserting absence of `line.3.horizontal`, `TodayTodoReorderDropDelegate`, and row-level `onDrop` reorder path
- [x] 1.2 Add failing presentation tests for `TodayTodoReorderController`, `TodayTodoAnimatedReorderList`, and `TodayTodoRowFramePreferenceKey`
- [x] 1.3 Keep/extend `TodayTodoStoreTests` for `moveIncomplete` persistence (no regression)

## 2. Reorder infrastructure

- [x] 2.1 Implement `TodayTodoRowFramePreferenceKey` and row frame aggregation in list coordinate space
- [x] 2.2 Implement `TodayTodoReorderController` state machine (long-press pending, dragging, insertionIndex, commit, cancel)
- [x] 2.3 Implement `TodayTodoAnimatedReorderList` with dragged overlay, 2pt gap insertion indicator, and spring `(response: 0.32, damping: 0.86)` neighbor offsets
- [x] 2.4 Use placeholder slot for dragged row so list height measurement for pinned layout does not jitter during drag

## 3. Gesture integration

- [x] 3.1 Add long-press + 4pt drag threshold to `InlineNotesTextView` / `InlineNotesTextContainer`; defer `onBeginEditing` until click confirmed
- [x] 3.2 Wire text-body long-press to `TodayTodoReorderController`; disable reorder when `isEditing` or incomplete count ≤ 1
- [x] 3.3 Remove ≡ handle, `reorderDragProvider`, `showsReorderHandle`, and `TodayTodoSection` `onDrop`/`draggingEntryId` drop path
- [x] 3.4 Delete `TodayTodoReorderDropDelegate.swift` and remove from Xcode target

## 4. Pinned and layout coexistence

- [x] 4.1 Implement pinned viewport edge auto-scroll (~8pt margin, ~120pt/s) during active drag only
- [x] 4.2 Verify reorder start/end does not increment `draftFocusRequestToken` or trigger compact/pinned mode animations
- [x] 4.3 Verify `TodayTodoMeasuredGeometryKey` and row-frame preferences do not create Preference multi-update warnings

## 5. Verification and docs

- [x] 5.1 Run TodayTodo store, layout policy, content layout, and new presentation tests with zero failures
- [x] 5.2 Build MalDaze scheme successfully
- [ ] 5.3 Manual QA: long-press vs click edit, spring reorder, Esc cancel, pinned edge scroll, persist after relaunch
- [x] 5.4 Update `docs/integrations/features/learning-desk-panel.md` §4.4 reorder wording (long-press text, no handle)
- [x] 5.5 Run `openspec validate redesign-today-todo-drag-reorder --strict`
