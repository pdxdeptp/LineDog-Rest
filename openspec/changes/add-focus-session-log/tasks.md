## 1. Focus session model and store

- [x] 1.1 Add `FocusSession` model, file envelope (`schemaVersion`, `sessions`), and `FocusSessionSource` (`completed`, `stoppedEarly`)
- [x] 1.2 Implement `FocusSessionStore` with default path `Application Support/MalDaze/focus-sessions.json`, append-on-finalize, and `todaySessions(calendar:)` filtering by session `date`
- [x] 1.3 RED: store tests for append, early-stop duration, today filter, empty file bootstrap, and no auto-purge of old dates

## 2. Timer lifecycle integration

- [x] 2.1 Track `workSegmentStartedAt` in `AppViewModel` when manual work begins (start focus, resume into work, rest skip into next work)
- [x] 2.2 Finalize session on manual work→rest transition with `source: completed`
- [x] 2.3 Finalize session on stop-while-working with `source: stoppedEarly` and actual elapsed minutes; skip finalize when stopping during rest
- [x] 2.4 Expose read-only today summary + in-progress projection for Dashboard (`todayFocusSessionCount`, `todayFocusMinutesTotal`, `inProgressFocusSegment`)

## 3. Dashboard visualization

- [x] 3.1 Add `todayFocusSection` in `DashboardRootView` between status chip and quick actions
- [x] 3.2 Render summary `N 个番茄 · 共 X 分钟`, finalized rows `HH:mm–HH:mm · M 分钟`, early-stop badge, and top in-progress row
- [x] 3.3 Empty state copy「今天还没有番茄」; wire live minute updates while working
- [x] 3.4 Presentation/source tests for section placement and summary copy rules

## 4. Verification

- [x] 4.1 Run focused tests (`FocusSessionStoreTests`, any new presentation tests)
- [x] 4.2 MANUAL_QA: manual mode — complete 25m segment, early stop, verify list/summary/live row; confirm auto mode creates no sessions; restart app and confirm persistence
