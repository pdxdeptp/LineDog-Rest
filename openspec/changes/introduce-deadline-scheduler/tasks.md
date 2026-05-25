## 1. Scheduler Core

- [ ] 1.1 Implement date-window construction from start date through deadline.
- [ ] 1.2 Implement usable capacity from daily capacity, existing active load, rest days, and unavailable dates.
- [ ] 1.3 Implement default planning budget cap at 80% of usable capacity unless crunch/overload is accepted.
- [ ] 1.4 Implement buffer reservation and buffer erosion reporting.
- [ ] 1.5 Implement balanced, front-loaded, and light-start load shapes.
- [ ] 1.6 Implement essential-before-optional placement and dependency preservation.

## 2. Splitting And Risk

- [ ] 2.1 Implement continuation-session splitting at approved split points or explicit multi-session boundaries.
- [ ] 2.2 Return expected-late, overload, or capacity-gap facts for unsplittable over-budget tasks.
- [ ] 2.3 Implement `ScheduleRiskReport`.
- [ ] 2.4 Ensure scheduler never invents tasks, lowers depth, extends deadline, moves existing active tasks, or creates Today actions.

## 3. Infeasibility Options

- [ ] 3.1 Implement fact-to-option mapping for capacity gap, buffer erosion, overload, expected late, and low calibration.
- [ ] 3.2 Implement deterministic option effects for deadline, capacity, crunch, buffer risk, rebalance, overload, estimate edits, rough draft, late finish, and storage.
- [ ] 3.3 Implement reduce-scope availability and before/after fit math.
- [ ] 3.4 Implement lower-depth recomputation handoff and before/after fit math.
- [ ] 3.5 Ensure hard deadlines never expose `accept_late_finish`.

## 4. Tests

- [ ] 4.1 Add scheduler tests for usable capacity, existing active load, rest days, unavailable dates, and 60-minute fallback capacity.
- [ ] 4.2 Add load-shape tests for balanced, front-loaded, and light-start placement.
- [ ] 4.3 Add buffer reservation and erosion tests.
- [ ] 4.4 Add continuation-session and unsplittable-task tests.
- [ ] 4.5 Add risk-report tests for capacity gap, overload, expected late, buffer erosion, rough estimates, and existing-load conflicts.
- [ ] 4.6 Add infeasibility option mapping and option-effect tests.
- [ ] 4.7 Add hard-deadline tests excluding `accept_late_finish`.
- [ ] 4.8 Add end-to-end dry-run tests for feasible resume packaging and infeasible easyagent rebuild.
