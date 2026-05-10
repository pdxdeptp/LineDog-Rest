## Context

The current control panel uses a fixed three-column width: reminders at 300pt, learning assistant at 280pt, and main controls at 300pt. The learning assistant middle column is implemented by `AssistantPanelView` as a header plus four equally weighted tabs. That structure technically exposes existing features, but it does not create a complete daily learning loop: users must decide where to look first, the middle column is too narrow, task rows do not quickly open learning material, and the navigation competes with the content.

The design direction has been validated with `mockups/home-dashboard-wide-popover.html`: the desk-pet popover becomes wide, left/right columns stay fixed, the learning assistant column becomes adaptive, the homepage emphasizes today's summary, task rows can be reordered and expanded, and the tool navigation is fixed at the bottom.

## Goals / Non-Goals

**Goals:**

- Make the desk-pet popover nearly full-width so the learning assistant has enough horizontal space.
- Make the first loaded learning assistant screen answer: what is today's overall state, what needs attention, and where can I go next?
- Prioritize today's summary over recommending a specific next task; the user chooses task order manually.
- Keep the bottom navigation visible independently from the scrollable information flow.
- Let task rows support three distinct actions: drag to reorder display, click to expand light details, and click an explicit link button to open learning material.
- Keep the offline model simple: if the assistant service is unavailable, the entire learning assistant middle column becomes an offline state.
- Reuse existing APIs where possible, but extend today's briefing task payload with learning links.

**Non-Goals:**

- No productized ingestion draft detail, resource roadmap detail, structured chat proposal diff, or actual-minute task completion input in this loop.
- No dashboard summary endpoint by default.
- No Morning Agent schedule, reschedule, priority, or capacity behavior change.
- No database migration for task display ordering.
- No heavy task detail page.
- No cached-content or partial-failure offline experience.
- No replacement of `NSPopover` with a custom window unless implementation proves `NSPopover` cannot support the required width and spec is updated first.

## Decisions

### D1: Wide popover shell with adaptive middle column

`MenuBarContentView.controlPanelPreferredContentSize` should move from the current fixed narrow total width to a screen-aware width near the visible screen width. The layout keeps the reminders column and right controls column fixed, while the learning assistant column receives the remaining width.

Recommended sizing model:

- Left reminders column: fixed, around current 300pt.
- Right controls column: fixed, around current 300pt.
- Inner separators and padding: fixed.
- Learning assistant middle column: `availableWidth - left - right - chrome`, with a minimum readable width.
- Overall popover width: near the current screen visible width with a safe margin, clamped to a reasonable maximum for very wide displays.

Alternative considered: only increase `assistantColumnWidth` inside the existing fixed-size popover. Rejected because it would still fight the right and left columns and would not scale with screen width.

### D2: Summary-first dashboard, not next-task-first

The homepage should lead with today's summary: total minutes, task count, load language, highlights, and deadline risk. It must not choose a single task as the dominant "next task" because the desired behavior is user-selected ordering.

Alternative considered: primary CTA to start the first unfinished task. Rejected because it makes the system feel prescriptive and conflicts with manual task ordering.

### D3: Bottom fixed navigation

The learning assistant uses a bottom fixed navigation bar for:

- Home
- Add Material
- Resource Progress
- Adjust Plan

The nav is outside the scrollable content area and remains visible while the homepage information flow scrolls. In offline state, the nav is hidden because the only meaningful state is service unavailable.

Alternative considered: top toolbar or inline cards. Rejected because top controls compete with the summary and disappear less naturally from the user's attention while reading the task flow.

### D4: Task row interaction model

Each task row has separate hit targets:

- Drag handle: adjusts the visible order of today's task list.
- Row body click: expands/collapses light details.
- Completion control: marks the task complete.
- Link button: opens the learning material.

The manual order is a front-end presentation preference for today's list. It should survive view refresh if feasible through local state keyed by date and task ids, but it must not mutate task `priority`, `scheduled_date`, or Morning Agent ordering.

The details area should stay light: resource title, why it matters today if available, target minutes, and the link action. It is not a separate detail page.

### D5: Learning link contract

The existing backend stores `resources.url`; units do not currently store URLs. Therefore this loop should require today's briefing task payload to include:

- `resource_url`: resource-level URL when available.
- `unit_url`: optional, only when backend can provide a unit-level URL.

The frontend should prefer `unit_url` when present, fall back to `resource_url`, and render a disabled or absent link action when neither exists.

Alternative considered: implement unit-level URL extraction for GitHub/Bilibili/PDF. Rejected as scope creep for the homepage loop.

### D6: Whole-column offline state

If the assistant request path determines the backend service is unavailable, the entire learning assistant column shows an offline state with retry. The homepage does not preserve stale content, show partial loaded sections, or render scoped errors in this loop.

Rationale: the user expectation is that frontend and backend are always online together. Offline should be rare and should mean "service unavailable", not a complex degraded mode.

## State Matrix

| State | Expected user experience |
| --- | --- |
| Backend starting | Middle column shows startup state and spinner; no offline copy |
| Service unavailable | Entire learning assistant column shows offline/retry; bottom nav hidden |
| Empty database | Homepage summary area leads to adding the first material |
| Tasks today | Homepage shows today summary and reorderable task list |
| Task expanded | Row reveals light details and explicit learning link action |
| No task link | Row detail shows link unavailable without inventing a URL |
| All tasks completed | Homepage shows completion status and leaves tools available in bottom nav |
| Resources but no tasks | Homepage explains no scheduled tasks today and points to resources/adjust plan |
| Deadline risk | Homepage summary includes risk prompt with route to resource progress |
| Scrolling content | Bottom nav remains fixed while summary/task flow scrolls |

## API Contract

`GET /api/today-briefing` continues returning the existing top-level fields. Each task object must keep existing fields and add learning link fields:

```json
{
  "id": 1,
  "title": "01 相向双指针",
  "target_minutes": 25,
  "completed_at": null,
  "resource_title": "基础算法精讲",
  "priority": 1,
  "resource_url": "https://example.com/course",
  "unit_url": null
}
```

No task ordering API is required in this loop. If apply discovers that local presentation ordering is not enough for the intended UX, update the spec before adding persistence.

## UI Information Hierarchy

1. Popover shell: left reminders, adaptive learning assistant, right controls.
2. Learning assistant header: title, short status, refresh.
3. Scrollable homepage flow: today summary, risk, task list, empty/resource states.
4. Task rows: drag handle, title/meta, completion, expandable details with link.
5. Fixed bottom navigation: Home, Add Material, Resource Progress, Adjust Plan.

## Error Recovery

- Startup: wait and show progress.
- Service unavailable: full-column offline state with retry.
- Missing learning link: keep task usable but show link unavailable in details.
- Link open failure: surface a small task-scoped error if the OS/browser cannot open the URL.

## Risks / Trade-offs

- Risk: `NSPopover` may not behave well at near-screen width. → Mitigation: first attempt screen-aware `contentSize`; only switch windowing approach after updating `desk-pet-controls` spec.
- Risk: local task display order can diverge from backend priority ordering. → Mitigation: label it as display order only and do not write backend priority.
- Risk: resource-level links may be less precise than unit-level links. → Mitigation: require `resource_url` now and keep unit-level deep links out of scope.
- Risk: bottom nav consumes vertical space. → Mitigation: keep it compact and fixed; prioritize the now-wider middle column.

## Migration Plan

1. Update tests first for wide layout assumptions, briefing link decoding, whole-column offline, bottom nav, task expansion, and display ordering.
2. Extend backend briefing payload with `resource_url` and optional `unit_url`.
3. Update Swift API models and ViewModel-derived dashboard state.
4. Rebuild `AssistantPanelView` around summary-first dashboard, reorderable task list, task detail expansion, and bottom nav.
5. Update `MenuBarContentView` popover sizing and column layout.
6. Run backend, Swift, visual, and spec compliance verification.

Rollback: revert popover sizing and dashboard UI to the old tab-first layout, and keep backend link fields backward-compatible so older clients ignore them.
