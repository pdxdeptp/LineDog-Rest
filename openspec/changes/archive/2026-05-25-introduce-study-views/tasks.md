## 1. Proposal Readiness

- [x] 1.1 Confirm the `study-views` proposal, design, spec, and tasks pass `openspec validate introduce-study-views --strict`.
- [x] 1.2 Record ITEM-002 v1 observation and gap-analysis evidence under Flow B.

## 2. Backend View APIs

- [x] 2.1 Write failing backend tests for deterministic Today view: active study tasks for the current day, project title, target minutes, learning link, and no morning-agent/LLM invocation.
- [x] 2.2 Implement the Today view query and route with persisted task/project facts.
- [x] 2.3 Write failing backend tests for task completion idempotency, progress update, unit completion, and view refresh facts.
- [x] 2.4 Implement the completion update path needed by v2 views without double-counting duplicate completions.
- [x] 2.5 Write failing backend tests for Project Overview active summaries and completed history.
- [x] 2.6 Implement project overview queries/routes using current task/unit/resource facts.
- [x] 2.7 Write failing backend tests for Calendar load aggregation over a date window and over-capacity marking.
- [x] 2.8 Implement read-only calendar load query/route.
- [x] 2.9 Write failing backend tests for automatic completed project archive/history when the last unfinished task completes.
- [x] 2.10 Implement completed-project transition and event persistence without hard-deleting history.

## 3. Swift API And View Model

- [x] 3.1 Write failing Swift model/client tests for Today, Project Overview, Calendar Load, and task completion refresh payloads.
- [x] 3.2 Implement Swift API models and client methods for study views.
- [x] 3.3 Write failing ViewModel tests for default Today view loading, task completion refresh, project overview active/history sections, and read-only calendar load state.
- [x] 3.4 Implement ViewModel state transitions for the study views without relying on `TodayBriefing.highlights` as the v2 source of truth.

## 4. Swift UI

- [x] 4.1 Write failing presentation tests that expose first-class Today, Project Overview, and Calendar views.
- [x] 4.2 Implement the minimal v2 UI for Today, Project Overview, completed history, and read-only Calendar load.
- [x] 4.3 Verify the Calendar view is inspection-only in this slice and does not expose drag/reschedule/add/delete controls.

## 5. Review And Verification

- [x] 5.1 Run relevant backend and Swift tests and record RED/GREEN/REFACTOR evidence.
- [x] 5.2 Run `openspec validate introduce-study-views --strict`.
- [x] 5.3 Use Computer Use/App Use on the current checkout app path to verify Today, completion progress refresh, Project Overview active/history, and Calendar load behavior; save evidence under Flow B.
