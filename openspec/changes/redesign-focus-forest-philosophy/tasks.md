## 1. Model and persistence

- [x] 1.1 Pause (`stopTimers`) does not append focus sessions; resume keeps the same `workSegmentStartedAt`
- [x] 1.2 Abandon on mode switch or new manual focus writes `stoppedEarly`
- [x] 1.3 Summary `X` uses `todayCompletedMinutes` (completed only)

## 2. Timeline grid

- [x] 2.1 Success fill only for `completed` + in-progress segments
- [x] 2.2 `stoppedEarly` renders muted failed marker at `startedAt`, not proportional accent fill
- [x] 2.3 Off-hours failed markers expand visible window like success intervals

## 3. Popover UX

- [x] 3.1 Completed segments: edit + delete
- [x] 3.2 Failed markers: read-only detail + delete only
- [x] 3.3 In-progress segments: read-only until completion

## 4. Tests and validation

- [x] 4.1 Update `FocusDayTimelineCellGridModelTests` for Forest semantics
- [x] 4.2 Add `todayCompletedMinutes` store test
- [x] 4.3 Run focused test suite and manual QA (pause/resume, abandon marker, completed fill)
