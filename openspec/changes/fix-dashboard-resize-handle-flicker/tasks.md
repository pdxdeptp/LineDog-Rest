## 1. Regression Test

- [x] 1.1 Add a failing Dashboard presentation regression test proving resize handles derive drag coordinates from `NSEvent.locationInWindow` rather than handle-local conversion.

## 2. Resize Handle Fix

- [x] 2.1 Update the shared Dashboard resize handle to compute axis deltas from stable window coordinates for both column and row separators.
- [x] 2.2 Run the focused Dashboard presentation tests and `openspec validate fix-dashboard-resize-handle-flicker --strict`.
- [x] 2.3 Manually verify Dashboard left/right column separators and the plan/nutrition separator drag smoothly with resize cursors and no flicker.
