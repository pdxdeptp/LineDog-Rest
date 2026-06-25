## Context

- `LearningDeskPanelView`: `@ObservedObject appViewModel`.
- `LearningDeskFocusTimelineRow`: `@ObservedObject presenter`（已窄）。
- Parent body re-eval on any `AppViewModel.objectWillChange` → siblings may layout.
- `statusLine` updates each second in manual mode from menu bar countdown path.

## Goals / Non-Goals

**Goals:**

- Timeline `@Published` 不导致 Today Todo 无关 layout（理想：Instruments 栈隔离）。
- Learning actions（edit session, delete, refresh）仍可用。

**Non-Goals:**

- 移除 AppViewModel 作为 app 中枢。
- Change 7 presenter 生命周期迁移。

## Decisions

### D1: LearningDeskPanelEnvironment

Introduce struct holding:
- Commands: `updateFocusSession`, `deleteFocusSession`, `refresh` hooks
- Read-only snapshots: focus timeline day update, not whole VM

Panel observes `@StateObject viewModel` + `@ObservedObject focusTimelinePresenter` injected from outside.

**Alternative rejected:** `@Observable` migration whole app—too large.

### D2: DashboardRootView passes presenter + narrow env

`LearningDeskPanelView(appViewModel:)` → `LearningDeskPanelView(environment:presenter:)` gradual migration with deprecated shim.

### D3: Verification via Instruments optional scenario

Manual + visible dashboard: publish overlay; confirm Today Todo stack reduced—not necessarily zero in v1.

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Missed action wiring | presentation tests + QA learning panel |
| Partial decouple insufficient | document remaining coupling; Change 7 escape hatch |

## Migration Plan

1. Inventory `appViewModel` usages in learning panel files.
2. Introduce environment; migrate read paths first, then actions.
3. Tests + QA full learning panel.

## Open Questions

- Single PR vs split read/action migration—倾向 **单 PR 原子 decouple**。
