## 1. Scheduler Core

- [x] 1.1 Implement scheduler input gate that schedules only compiler `draft_review` packages and passes compiler `needs_input`/`compile_failed` through unchanged.
- [x] 1.2 Implement `ScheduledDraftReview`, `ScheduledDay`, scheduled item, `ScheduleRiskReport`, infeasibility option, and scheduler trace output shapes.
- [x] 1.3 Implement scheduler preflight defaults and `needs_input` for missing deadline, invalid date parsing, or empty schedulable task set.
- [x] 1.4 Implement inclusive local date-window construction from start date through deadline, including deadline-before-start infeasible review.
- [x] 1.5 Implement usable capacity from daily capacity, existing active load, rest days, and unavailable dates, with 60-minute fallback capacity.
- [x] 1.6 Implement default planning budget cap at 80% of usable capacity unless crunch/overload is accepted.
- [x] 1.7 Implement deterministic buffer reservation: zero days for fewer than three usable days, latest one usable day for three to six usable days, and latest ceil(20%) usable days clamped to one through five days for longer windows.
- [x] 1.8 Implement buffer erosion reporting and status blocking until buffer risk is explicitly accepted or constraints change.
- [x] 1.9 Implement balanced, front-loaded, and light-start load shapes as distribution-only choices with deterministic tie-breakers.
- [x] 1.10 Implement essential-before-optional placement and dependency preservation.
- [x] 1.11 Implement review-status derivation for scheduler `needs_input`, `draft_review`, and `infeasible_review`.

## 2. Splitting And Risk

- [x] 2.1 Implement continuation-session splitting at approved split points or explicit multi-session boundaries.
- [x] 2.2 Preserve parent task id, classification, dependency context, sequence order, session estimate, and visible sub-output for split sessions.
- [x] 2.3 Return expected-late, overload, or capacity-gap facts for unsplittable over-budget tasks.
- [x] 2.4 Implement essential capacity gap, optional/stretch unscheduled minutes, overloaded dates, expected-late tasks, buffer erosion, rough estimate confidence, and existing-load conflicts in `ScheduleRiskReport`.
- [x] 2.5 Implement fallback-mode review metadata with fallback minutes, fallback output, and risk effect without counting fallback as full task completion.
- [x] 2.6 Ensure scheduler never invents tasks, lowers depth, extends deadline, moves existing active tasks, writes active tasks, or creates Today actions.

## 3. Infeasibility Options

- [x] 3.1 Implement fact-to-option mapping for capacity gap, buffer erosion, overload, expected late, and low calibration.
- [x] 3.2 Implement deterministic option effects for deadline, capacity, crunch, buffer risk, rebalance, overload, estimate edits, rough draft, late finish, and storage as review recomputation or storage results, not activation.
- [x] 3.3 Implement `accept_crunch` as raising selected dates to at most 100% usable capacity and `accept_overload` as explicit over-usable-capacity placement with overloaded dates still visible.
- [x] 3.4 Implement reduce-scope availability, eligible optional/stretch removal, and before/after fit math while preserving essential depth evidence.
- [x] 3.5 Implement lower-depth recomputation handoff with requested depth, current fit facts, removed-evidence preview, and before/after fit math placeholder.
- [x] 3.6 Implement answer-one-question recomputation handoff for low-calibration scheduler options.
- [x] 3.7 Ensure hard deadlines never expose `accept_late_finish`.

## 4. Tests

- [x] 4.1 Add scheduler input-gate and output-shape tests proving non-draft compiler statuses are not scheduled and scheduler returns review packages only.
- [x] 4.2 Add scheduler preflight tests for missing deadline `needs_input`, invalid dates, empty task sets, default start date, assumed deadline type, empty existing-load default, empty rest/unavailable defaults, standard buffer default, and visible assumptions.
- [x] 4.3 Add scheduler tests for inclusive local windows, deadline-before-start infeasible review, usable capacity, existing active load, rest days, unavailable dates, and 60-minute fallback capacity.
- [x] 4.4 Add load-shape tests for balanced, front-loaded, and light-start placement tie-breakers without scope/dependency changes.
- [x] 4.5 Add buffer reservation, no-buffer, erosion, and accept-buffer-risk tests.
- [x] 4.6 Add continuation-session and unsplittable-task tests proving parent identity and dependency context are preserved.
- [x] 4.7 Add fallback-mode tests proving fallback metadata does not count as normal task completion.
- [x] 4.8 Add risk-report tests for essential capacity gap, optional unscheduled minutes, overload, expected late, buffer erosion, rough estimates, and existing-load conflicts.
- [x] 4.9 Add infeasibility option mapping and option-effect tests proving effects return new review/storage/recompute states rather than activation.
- [x] 4.10 Add crunch-versus-overload tests proving crunch stays within usable capacity and overload remains visible.
- [x] 4.11 Add hard-deadline tests excluding `accept_late_finish`.
- [ ] 4.12 Add end-to-end dry-run tests for feasible resume packaging and infeasible easyagent rebuild.
