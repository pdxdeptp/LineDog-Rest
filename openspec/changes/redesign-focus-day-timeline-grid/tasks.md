## 1. Proportional cell grid model and view

- [x] 1.1 Add `FocusDayTimelineCellGridModel` (default window 08:00–24:00; expand `visibleStart` into 00:00–08:00 when off-hours overlap; 30min cells; 16 columns; per-cell merged overlap fractions; min fill 2pt)
- [x] 1.2 Add `FocusDayTimelineCellGridView` (variable rows × 16 cols, empty cell chrome, accent proportional sub-rect fills, dynamic tick labels)
- [x] 1.3 Unit tests: partial cell fill 14:10–14:25; 3min in cell → 10% width; cross-cell session; stoppedEarly paints; in-progress to now; off-hours session expands start (e.g. 06:00–06:30); default window when no off-hours activity; midnight-spanning session splits correctly

## 2. Learning panel header integration

- [x] 2.1 Pass `AppViewModel` focus projection into `LearningDeskPanelView` / `todayHeader`
- [x] 2.2 Inline Hermes `完成 done/total` on budget lines; remove progress bar rows
- [x] 2.3 Insert focus cell grid row below budget lines
- [x] 2.4 Remove per-session list UI from learning panel if present

## 3. Dashboard right column cleanup

- [x] 3.1 Remove `todayFocusSection` from `DashboardRootView.mainControlsColumn`
- [x] 3.2 Retire Dashboard usage of `FocusSessionTodaySection`
- [x] 3.3 Update presentation tests for right-column removal

## 4. Verification

- [x] 4.1 Run focused tests (cell grid model, presentation, `FocusSessionStoreTests`)
- [x] 4.2 MANUAL_QA: partial accent fill (incl. short 3min sliver); cross-cell continuity; early stop visible; in-progress grows; default 8–24 only; off-hours session expands grid left; no right-column list
