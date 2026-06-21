## Context

`extract-transient-overlay-presenter` 已把喝水提醒和中心铃铛的 panel 壳迁入 `MalDazeTransientOverlayPresenter`，但智能提醒仍是分裂所有权：`WindowManager` 调用 `SmartReminderUIPanels` 创建并持有 `NSPanel`，展示器只定位和 order。当前展示器的屏幕 observer 只枚举被动浮层；输入框的延迟聚焦又强引用 panel，关闭或替换后仍可能重新 `makeKeyAndOrderFront`。

本 change 是原提取的依赖性收尾，不改变产品交互。现有约束包括：

- `WindowManager` 继续作为智能提醒草稿、提交、取消监听和 Toast 自动关闭编排者，但不得拥有 AppKit panel 生命周期。
- `MalDazeTransientOverlayPresenter` 是四类临时浮层 shell 的唯一 owner。
- 智能提醒内容仍由 SwiftUI 构建，输入必须 become key；被动浮层不得激活应用。
- Dashboard demote 契约、Hermes 契约、草稿 SSOT 与现有文案保持不变。
- `MalDaze.xcodeproj/project.pbxproj` 和 `ControlPanelPresentationTests.swift` 同时被其他未完成 change 修改，apply 必须顺序执行并保护现有改动。

## Goals / Non-Goals

**Goals:**

- 让展示器创建、持有、定位、显示、关闭和释放智能输入/Toast panel。
- 让同一个屏幕 observer 重定位所有可见 transient overlays。
- 保证异步聚焦只作用于当前仍可见的输入 panel。
- 保留 `WindowManager` 的草稿、提交、Esc/外部点击和自动关闭编排，但移除其 panel 引用。
- 清理倒计时结束后的旧 screen observer。
- 用行为测试验证状态转移与竞态；源码测试只保留为边界守卫。

**Non-Goals:**

- 不迁移独立倒计时条、休息霸屏、五分钟猫伴或设置窗口。
- 不改变智能提醒 UI、锚点算法、草稿清空规则、Toast 时长或 undo 行为。
- 不改变 Dashboard focus/demote 策略。
- 不修改 Hermes JSON、命令或持久化契约。
- 不顺手修复当前工作树里与 TodayTodo/defaults 有关的测试失败。

## Decisions

### D1: 展示器拥有 panel；调用方只提供内容与编排回调

将 `SmartReminderUIPanels` 瘦身为内容 builder：返回承载 SwiftUI 内容的 `NSView`/hosting controller 与期望尺寸，不再创建 `NSPanel`。展示器的语义 API 接收内容描述、anchor 和回调，并在内部创建与保存交互型 panel state。

展示器对外提供窄查询/命令以支持现有编排：

```swift
var isSmartReminderInputVisible: Bool { get }
func smartReminderInputContains(screenPoint: NSPoint) -> Bool
func presentSmartReminderInput(content: TransientOverlayContent, anchor: NSRect)
func dismissSmartReminderInput()
func presentSmartReminderToast(content: TransientOverlayContent, anchor: NSRect)
func dismissSmartReminderToast()
```

`WindowManager` 可继续安装 Esc/点击外部 monitor 和 Toast timer，但仅通过这些 API 查询或关闭；它不得保存 `smartInputPanel` / `smartToastPanel`。

**理由**: 既落实 AppKit 生命周期 SSOT，又避免把草稿和业务编排塞进展示器。  
**拒绝的备选**: 继续把 `NSPanel` 传给展示器——这只能抽取 order/position helper，无法满足 sole owner 契约。

### D2: 用统一 overlay state 管理被动与交互型实例

展示器保存按 kind 区分的 state：panel、presentation policy、content size、anchor（交互型）和 generation。安装 observer 的条件改为“任一 overlay 可见”，移除条件改为“所有 overlay 均已关闭”。

屏幕变化时：

- 被动型按菜单栏屏 `visibleFrame` 重新居中。
- 交互型用保存的 anchor/size 重新执行 `frameTopCenter` clamp；anchor 所在屏消失时沿用现有 fallback 规则。

**理由**: 初始定位与重定位共享同一算法和状态来源，避免另建 shadow position。  
**拒绝的备选**: 让 `WindowManager` 监听屏幕变化——会重新形成双 owner。

### D3: 延迟聚焦使用 generation + 当前实例校验

每次展示或关闭交互型 panel 都推进 generation。延迟聚焦闭包弱引用 panel，并在执行前确认：

1. 对应 kind 仍有 state；
2. state generation 与闭包捕获值一致；
3. state panel 与捕获 panel 是同一实例。

任一条件不满足时不 activate、不 order、不改 first responder。关闭命令幂等，重复关闭不重复触发用户回调。

**理由**: 弱引用解决释放问题，generation 解决旧 panel 被新 panel 替换后的 ABA/延迟任务问题。  
**拒绝的备选**: 只改回 `[weak panel]`——能缓解释放竞态，但不能证明旧任务不会作用于已被替换的实例。

### D4: 倒计时 observer 在倒计时 UI 结束时立即释放

`SevenMinuteReminderController` 的 screen observer 只服务倒计时条。`onCountdownFinished` 在 tear down 倒计时 UI 后立即移除 observer，再把铃铛交给展示器；铃铛自己的屏幕 observer 完全由展示器维护。

**理由**: 迁移后不存在共享 observer 的必要，生命周期应随其唯一消费者结束。

### D5: 行为测试优先，源码测试只守架构边界

为展示器增加可注入的窄 runtime seam（例如 main-queue scheduler、app-active snapshot、panel ordering/factory 或等价 abstraction），以验证：

- inactive/active snapshot 传给 Dashboard demote policy 的真实值；
- present → dismiss → 执行旧 focus work 不会重新显示；
- present A → present B → 执行 A 的 focus work 不影响 B；
- screen notification 会重定位 passive 与 interactive state；
- 关闭一种 overlay 不会移除其他可见 overlay 所需的 observer。

源码断言只用于确认 `WindowManager` 不再声明 panel 属性、`SmartReminderUIPanels` 不再创建 panel，以及 target 文件注册；不得把字符串存在性当作行为证明。

## Risks / Trade-offs

- [Risk] Presenter API 暴露过多智能提醒细节，变成新上帝对象。→ 只接受通用 content/anchor，草稿、提交和 timer 留在 `WindowManager`。
- [Risk] 点击外部 monitor 失去 panel 引用后难以命中判断。→ 提供只读 `contains(screenPoint:)` 查询，不泄漏 panel。
- [Risk] generation 与异步闭包增加状态复杂度。→ 每个 kind 单一 state、关闭统一推进 generation，并覆盖替换竞态测试。
- [Risk] 多个 active change 共享 project/test 文件，容易覆盖用户改动。→ 当前 checkout 顺序实施，逐 hunks 审查，不使用重置/覆盖；必要时先建立仅含已授权内容的 checkpoint。
- [Risk] 原 change 尚未归档，follow-up 的 MODIFIED spec 依赖其 delta。→ 实现与验证完成后先归档原 change，再归档本 change；在此之前两者保持 active。

## Migration Plan

1. 先以失败测试固定 ownership、重定位和 delayed-focus 竞态。
2. 提取智能提醒 content builder，展示器接管 panel factory/state/dismiss。
3. 将 `WindowManager` 改为只通过 presenter 查询和命令编排 monitor/timer。
4. 统一 screen observer 与 generation guard；清理 SevenMinute observer。
5. 运行聚焦与全量相关测试，并执行 passive/interactive 手动 QA。
6. `openspec validate --strict` 两个 change；先归档 `extract-transient-overlay-presenter`，再归档本 change。

Rollback 不涉及数据迁移：恢复 `WindowManager` 的旧 panel ownership，并回退展示器交互型 state/API 即可。

## Open Questions

无。所有产品语义沿用原 change，本提案只完成已承诺的生命周期边界与验证。
