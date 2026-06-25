## Why

`FocusTimelinePresenter` 挂在 `AppViewModel` 全 App 生命周期，与 Dashboard **hide 保留 host** 模型存在张力：hidden 后 presenter 仍存活，依赖 quiescence 纪律。长期治本选项是将 presenter（及同类 Dashboard-scoped state）生命周期绑定到 `deskMenuHostingController`，hide 时 **pause + snapshot** 或 destroy/recreate。

**Tier 3 / 可选**：仅当 M1–M2 + Change 5 仍不能满足能耗或复杂度过高时启动。

## What Changes

- 设计评估：presenter 随 Dashboard host vs AppViewModel。
- 若实施：迁移 presenter 所有权；hide/show snapshot 策略；快速 reopen 回归。
- **默认状态**：design-only + spike tasks；apply 需显式批准。

## Capabilities

### New Capabilities

- None initially.

### Modified Capabilities

- `focus-timeline-presenter`: Lifecycle ownership MAY move to Dashboard host scope (if implemented).
- `dashboard-presentation-quiescence`: Coordinator MAY shrink if consumers die with host (if implemented).

## Depends On

- M1 + M2 complete and stable (Changes 1–5).

## Impact

- Large refactor: `AppViewModel`, `WindowManager`, `DashboardRootView`, tests.
