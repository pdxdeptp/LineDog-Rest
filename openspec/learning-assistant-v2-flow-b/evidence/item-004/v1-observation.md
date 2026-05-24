# ITEM-004 V1 / Current-State Observation

## Scope

- Item: ITEM-004 `study-smart-mode`
- Source: US-17, US-18, US-19, D14-D19, D28
- Target spec id: `study-smart-mode`
- Observation time: 2026-05-24T14:05:15Z

## Git / Safety

- Start status contained only automation-owned state markers in `openspec/learning-assistant-v2-flow-controller/state.json` and `openspec/learning-assistant-v2-flow-b/state.json`.
- Work stayed in the current checkout. No worktree was created or used.
- This observation did not write implementation code.

## Design Boundary

- The v2 design defines smart mode as opt-in default mode plus a proposal engine.
- Default mode remains silent: the assistant does not proactively brief, reschedule, remind, or mutate the plan.
- Smart mode may summarize existing facts and offer multiple candidate proposals, but every mutation must be user-applied.
- Trigger point 1 is the smart-mode morning briefing when existing facts show lag, expected-late, or over-capacity.
- Trigger point 2 is after a manual adjustment creates red state. A non-red adjustment must stay silent.
- "Lag" is the maximum accumulated auto-roll days in a project and is only a morning-briefing trigger, not an after-adjustment trigger.

## Existing Backend Behavior

- `assistant_backend/src/routers/morning.py` exposes old v1 endpoints:
  - `POST /api/morning-briefing` always calls `run_morning_agent()`.
  - `GET /api/today-briefing` returns cached `briefing_YYYY-MM-DD` or calls `run_morning_agent()`.
- `assistant_backend/src/agents/morning_agent.py` is v1 autonomous behavior, not v2 smart mode:
  - it may run a weekly review before briefing;
  - it reschedules yesterday's incomplete tasks by calling `reschedule_task`;
  - it calibrates `resources.speed_factor`;
  - it uses an LLM to generate a short highlight and caches it in `system_state`.
- `assistant_backend/src/routers/study_views.py` already provides v2 factual views:
  - Today view runs idempotent rollover and returns persisted active study tasks;
  - Project Overview exposes active project facts including expected-late state;
  - Calendar exposes rest-day and over-capacity facts.
- `assistant_backend/tests/test_study_views_today.py` already guards that `/api/study-views/today` does not invoke the v1 morning agent.
- `assistant_backend/src/routers/study_plan_adjustment.py` provides v2 adjustment primitives:
  - rollover;
  - manual task move cascade;
  - deadline edit;
  - add/delete task;
  - rest-day settings;
  - bounded dialogue preview/apply.
- `assistant_backend/src/db/queries.py` has `preview_active_study_project_shift` and `apply_active_study_project_shift`, which provide route-A preview/apply mechanics for one supported project-shift command. They are useful building blocks but do not generate multiple smart-mode proposals.
- There is no `study-smart-mode` router, persisted smart-mode setting, smart briefing endpoint, smart proposal endpoint, proposal option model, dismiss/ignore state, or apply-by-proposal-id contract.

## Existing Swift / UI Behavior

- `LearningAssistantViewModel.fetchDashboard()` uses the v2 factual endpoints (`fetchStudyTodayView`, `fetchStudyProjectOverview`, `fetchResources`) and does not call the old briefing endpoint.
- `LearningAssistantViewModel.fetchTodayBriefing()` and `AssistantAPIClient.fetchTodayBriefing()` still exist and call `/api/today-briefing`, which can trigger the v1 Morning Agent if used.
- Tests verify the default dashboard ignores stale generated briefing data and derives `todayHighlights` from v2 facts instead.
- `AssistantPanelView` shows factual red states through `defaultModeSilentRedStateFact`, preserving ITEM-003's default-mode silence.
- `StudyPlanAdjustmentView` supports one bounded preview/apply dialogue adjustment and shows red-state impact as fact.
- There is no visible smart-mode setting, no morning briefing surface, no smart proposal cards, no side-by-side candidate options, no per-option Apply button, and no after-adjustment smart proposal surface.
- Legacy `chatMessages`, `currentProposal`, `/api/chat`, and `/api/chat/confirm` still exist for older behavior, but ITEM-003 tests assert the default v2 adjustment path does not invoke them.

## Existing OpenSpec Context

- `openspec list --specs` has no v2 spec ids yet because completed v2 changes are still active and unarchived.
- Completed but unarchived v2 changes provide the dependency base:
  - `introduce-study-plan-foundation` / `study-plan`;
  - `introduce-study-views` / `study-views`;
  - `introduce-study-plan-adjustment` / `study-plan-adjustment`.
- Old v1 specs remain active for historical behavior:
  - `daily-morning-agent` explicitly specifies autonomous rescheduling, speed calibration, and weekly-review catch-up;
  - `conversational-planner` specifies broad LLM proposal/confirm behavior.
- ITEM-004 must add a new `study-smart-mode` spec delta and avoid modifying old v1 specs in this slice.

## Summary

The current checkout has enough v2 factual substrate to build smart mode safely, but the existing "morning" and "chat" paths are still v1-shaped. ITEM-004 should not reuse the v1 Morning Agent as-is. It needs an opt-in setting, fact-only smart briefing, deterministic proposal generation from v2 facts, side-by-side proposal options, explicit user apply, and strict guards that default mode remains silent.
