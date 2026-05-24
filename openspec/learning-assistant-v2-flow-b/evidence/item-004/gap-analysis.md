# ITEM-004 Gap Analysis

## Target Behavior

`study-smart-mode` must add an opt-in proposal layer on top of the completed v2 plan/calendar system:

> Smart mode is default mode plus a proposal engine. It may summarize existing facts and offer candidate adjustments, but it never mutates the plan unless the user presses Apply.

## Gaps

### US-17 / D14: Smart Mode Setting

- Current: there is no persisted learning-assistant smart-mode setting and no UI toggle for default mode vs smart mode.
- Needed: an explicit off-by-default setting, exposed in Settings, persisted locally/backend-side, and used as the gate for every smart-mode briefing/proposal surface.

### US-18: Fact-Only Morning Briefing

- Current: the old `/api/today-briefing` path can run v1 `run_morning_agent()`, which may reschedule tasks, run weekly review, calibrate speed factors, call an LLM, and cache a generated briefing.
- Current v2 dashboard intentionally avoids this path and derives `todayHighlights` from factual Today view data.
- Needed: a new smart-mode morning endpoint or service that summarizes only v2 facts from Today, Project Overview, Calendar, rollover counts, expected-late, and over-capacity. It must not run weekly review, speed calibration, autonomous reschedule, or any hidden mutation.

### US-19 / D15 / D16: Multiple Proposal Options With Apply

- Current: dialogue adjustment supports one bounded preview/apply project shift, not multiple side-by-side smart proposals.
- Current: v1 conversational planner can produce proposals, but it is broad LLM agent behavior tied to `/api/chat` and can write through old plan tools after confirmation.
- Needed: a structured proposal model with multiple candidate options, each showing scope, affected tasks, date changes, red-state impact, tradeoff summary, and an independent Apply action. Ignore/dismiss must be a no-op.

### D18: Trigger Point 2 Only After Red-State-Producing Manual Adjustments

- Current: manual adjustments refresh v2 facts and default-mode red states remain factual/silent.
- Needed: in smart mode, after a manual move/deadline/add/rest-day/dialogue apply creates expected-late or over-capacity state, the UI should request/display smart proposals. If no red state appears, no proposal should be generated.
- Needed: "lag" from auto-roll days must not trigger after-adjustment proposals; lag only contributes to morning briefing/proposals.

### D19: Smart Proposal Layer Must Not Change Mechanical Rules

- Current: ITEM-003 mechanical cascade and literal add/delete semantics are implemented.
- Needed: smart mode must layer proposals after those mechanics complete; it must not alter the immediate result of move, add, delete, deadline edit, rest-day cascade, or dialogue apply.

### D28: Rolled Task Signal In Morning Briefing

- Current: Today view exposes rolled-task badge facts and UI can show rolled badges in default mode.
- Needed: smart morning briefing must identify tasks/projects with accumulated auto-roll days >= 3 and may offer handling proposals. This must be a briefing/proposal signal only, not an automatic reschedule.

### V1 Retirement / Isolation

- Current: v1 `daily-morning-agent` and `conversational-planner` remain registered and specified.
- Needed for ITEM-004: do not silently repurpose old agents. Either add new v2 smart-mode routes or wrap old endpoints behind hard guards so the v2 app never triggers autonomous behavior.
- Full retirement of old specs remains a later D17 backlog step after all v2 replacement specs are implemented.

## Proposed Scope For `introduce-study-smart-mode`

Include:

- Smart-mode setting and UI toggle.
- Smart factual briefing endpoint/service.
- Proposal generation from v2 facts for morning and after-adjustment triggers.
- Multiple candidate proposal cards with per-option Apply.
- Backend apply path that revalidates the selected proposal before mutation.
- Swift API/ViewModel/UI state for smart briefing, proposals, ignore, and apply.
- Tests that default mode never calls smart endpoints and never invokes v1 morning/chat behavior.

Exclude:

- Full-auto smart mode.
- Automatic application of any proposal.
- Cross-project optimization that lacks a manual equivalent.
- Retiring/deleting v1 specs or endpoints outside the v2 app path.
- New external credentials or account flows.

## Suggested Implementation Order

1. Persist smart-mode setting and expose off-by-default API/client state.
2. Add factual smart snapshot and briefing generator, with tests proving no v1 Morning Agent call or mutation.
3. Add proposal option generation for lag/expected-late/over-capacity using existing v2 adjustment preview primitives where possible.
4. Add apply-by-selected-proposal flow with stale-proposal revalidation.
5. Wire Swift API and ViewModel state.
6. Add Settings toggle, morning briefing surface, proposal cards, and after-adjustment proposal trigger.
7. Verify default-mode silence and current-checkout App behavior.

## Readiness Notes

- This should be a new OpenSpec change `introduce-study-smart-mode` with new spec id `study-smart-mode`.
- The change depends on ITEM-003 and should stay sequential: backend fact/proposal contract first, then Swift client/ViewModel/UI.
- No implementation should begin until `proposal.md`, `design.md`, `tasks.md`, and `specs/study-smart-mode/spec.md` exist and pass `openspec validate --strict`.
