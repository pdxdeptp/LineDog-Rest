## Why

学习面板「今日专注」时间轴在 `View.body` 里每帧调用 `FocusDayTimelineCellGridModel.make()`，且被整个 `AppViewModel` 的计时 tick（约 1Hz）拖着刷新。这导致 **O(格子×session) 的重复布局**、与菜单栏倒计时无关的 invalidation、以及在 `startedAt > now`（如提前跳过休息）时 **`DateInterval` trap 崩溃**。补丁式 guard 不能解决架构问题；需要从 **时间语义 + 增量呈现 + 窄观察面** 根本重构。

## What Changes

- **新增** `FocusTimelinePresenter`（或等价模块）：分离 **静态日网格骨架**（finalize / 编辑 / 删除 / 跨日时重建）与 **进行中 live overlay**（仅更新当前 phase 的 fraction 与文案）。
- **移除** `LearningDeskPanelView` body 内同步 `FocusDayTimelineCellGridModel.make()`；时间轴改为订阅 presenter 的缓存模型。
- **收窄 invalidation**：学习面板可见时才驱动 live overlay 更新；**不再**因 `statusLine` 等无关 `@Published` 字段重建整网格。
- **统一工作段起点语义**：用户提前结束休息进入下一工作段时，工作 phase 的 `startedAt` SHALL 为 **当前 wall-clock**（与 `tick()` 自然过渡一致），消除「未来开始的工作段」。
- **保留** 现有视觉规格（30 分钟格、accent 比例填色、枯树 marker、popover 规则、`focus-sessions.json` SSOT）；**不变** Hermes 契约。
- **测试**：presenter 增量更新、不可见时不 tick、skip-rest 后 `startedAt ≤ now`、无 `DateInterval` trap 的网格构建路径。

## Capabilities

### New Capabilities

- `focus-timeline-presenter`: 专注时间轴的静态骨架缓存、live overlay、可见性门控与窄 observation 契约。

### Modified Capabilities

- `learning-desk-panel`: Today header 时间轴的数据来源与刷新规则（presenter 驱动，非 body 内全量 `make()`）。

## Impact

- **新增**: `FocusTimelinePresenter.swift`（及可选 live overlay 类型）。
- **修改**: `FocusDayTimelineCellGridModel`（拆分为 skeleton 构建 vs live 合并，或等价 API）、`FocusDayTimelineCellGridView`、`LearningDeskPanelView`、`AppViewModel`（ decouple timeline refresh from global timer broadcast）。
- **修改**: `ManualTimerEngine.skipRestPhaseToWork()` 工作段起点语义。
- **测试**: 新 presenter 单测、更新 `FocusDayTimelineCellGridModelTests` / presentation tests；回归 skip-rest + 面板可见场景。
