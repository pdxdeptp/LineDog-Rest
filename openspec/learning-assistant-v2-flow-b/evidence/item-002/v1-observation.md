# ITEM-002 V1 Observation: Study Views

## Scope

- Item: ITEM-002 `study-views`
- Sources: US-6, US-7, US-12, US-13, US-14
- Observation date: 2026-05-23T18:18:56Z heartbeat
- Checkout strategy: current checkout only; worktrees forbidden.

## Git / Safety

- Starting `git status --short` showed only automation-owned changes from ITEM-001 and this heartbeat's state updates.
- No unrelated user edits were detected.
- ITEM-002 exploration did not modify implementation code.

## Design Source

The v2 design requires:

- US-6: default daily entry is "今日视图", showing today's tasks across projects.
- US-7: checking off a task updates progress.
- US-12: project overview shows each project's progress and deadline.
- US-13: calendar view shows the next several weeks of task distribution and load.
- US-14: when all project tasks are completed, the project auto-archives while preserving history.

## OpenSpec Context

- `openspec list --specs` does not yet include v2 specs because `introduce-study-plan-foundation` is complete but not archived into `openspec/specs/`.
- Active relevant change:
  - `introduce-study-plan-foundation`: complete, `20/20`, defines `study-plan` and provides active study projects, tasks, deadlines, target minutes, and confirmation semantics.
- Existing v1 learning specs remain historical context and should not be modified for this item:
  - `assistant-panel-ui`
  - `learning-data-layer`
  - `material-ingestion`
  - `progress-feedback`
  - `daily-morning-agent`
  - `conversational-planner`

## Code Observation

### Backend

- Existing daily endpoint is `/api/today-briefing` in `assistant_backend/src/routers/morning.py`.
  - It returns a cached or generated morning briefing and can call `run_morning_agent()`.
  - This is v1 agent-shaped, not a deterministic v2 study calendar fact endpoint.
- Existing `/api/resources` returns active resources only.
  - It supports the current `资料进度` list but not completed/archive history.
- Existing completion endpoint is `/api/tasks/{task_id}/complete`.
  - `complete_task` updates `completed_at`, optional actual minutes, unit status, resource completed unit count, and marks the resource `completed` if `completed_units >= total_units`.
  - It does not expose a deterministic v2 today/project/calendar aggregate response after mutation.
- Existing data model can support ITEM-002 basics:
  - `resources`: status, title, total/completed units, deadline, url.
  - `units`: order, status, estimated/actual minutes.
  - `tasks`: resource, title, target minutes, scheduled date, completed state.

### Swift

- `AssistantPanelView` currently has bottom tabs: home, add resource, resource progress, adjust plan, settings.
- Home view already has a today-like summary and today's tasks.
- `资料进度` shows active resource progress cards with progress bars, deadline, status, and management actions.
- There is no first-class calendar view.
- Project overview is resource-card oriented and active-only; it does not show completed/archive history.
- Today's home currently depends on `TodayBriefing`, which is still coupled to `/api/today-briefing` and v1 morning-agent/cached summary semantics.

## App Observation

Using Computer Use against `/Users/cpt/Public/MalDaze/DerivedData/Build/Products/Debug/MalDaze.app`:

- Home showed:
  - `今日摘要`
  - 1 task, 12 minutes, 4 resources
  - today's task list with one task and completion control.
- `资料进度` showed:
  - active project/resource cards for the three existing algorithm resources and the ITEM-001-created `Course V2`.
  - progress bars at `0 / n 单元`, invested minutes, deadline, and status badge.
- The current UI did not expose a calendar view for upcoming weeks.
- The current UI did not expose completed/archived project history.
- The current "调整计划" tab is a v1 chat surface and should not be the source of truth for ITEM-002 factual views.

## API / DB Observation

- `GET /api/today-briefing` returned only today's scheduled task plus agent-style highlights.
- `GET /api/resources` returned active resources only, including active `study_project` resource `id=6`, title `Course V2`.
- SQLite task aggregation over `2026-05-23` through `2026-06-23` already has enough facts to drive a calendar load view:
  - `2026-05-23`: 1 task, 12 minutes
  - `2026-05-24`: 2 tasks, 59 minutes
  - `2026-06-08`: 2 tasks, 57 minutes
- SQLite resources include archived historical resources (`id=3`, `id=4`) that current `/api/resources` omits.

## Conclusion

ITEM-002 should introduce a new `study-views` capability and deterministic view APIs rather than extending `/api/today-briefing`. It should reuse the ITEM-001 active project/task tables and current Swift patterns, while replacing v1 agent/cached summary semantics for the v2 daily, project, and calendar views.
