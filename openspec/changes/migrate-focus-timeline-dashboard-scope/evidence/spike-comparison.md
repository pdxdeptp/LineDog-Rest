# Spike: AppViewModel presenter vs Dashboard-scoped host

**Date:** 2026-06-22  
**Status:** Archive as not needed (M1 path sufficient)

## Question

Should `FocusTimelinePresenter` move from `AppViewModel` to a Dashboard-scoped host?

## After M1 (Changes 1 + 2)

| Concern | M1 mitigation |
|---------|----------------|
| 4 Hz live tick while hidden | Presenter `live` gating; no periodic publish unless manual work |
| `orderOut` ≠ SwiftUI disappear | `DashboardQuiescenceCoordinator` + `deskPetDashboardDidClose` |
| Learning panel observes full VM | Change 5 narrows to `LearningDeskPanelEnvironment` + presenter |

## Comparison

| Approach | Pros | Cons |
|----------|------|------|
| **Keep on AppViewModel** (current) | Single registration point; Hermes/focus session writes already centralized | Presenter lifetime tied to app, not dashboard window |
| **Dashboard host scope** | Theoretical lower coupling; presenter dies with window | Hide/show snapshot restore; duplicate registration; cross-tab state on reopen |

## Decision

**Do not implement migration (tasks 2.x)** until M2 manual QA shows residual idle CPU or layout churn attributable to presenter living on `AppViewModel`.

Recommended follow-up if needed: measure hide/reopen latency + 10 min idle CPU after Changes 1–6 before expanding scope.
