## Context

当前三类浮层实现分散：

| 功能 | 调度 | 展示 | z-order 政策 |
|------|------|------|--------------|
| 喝水提醒 | `HydrationReminderController` | 内联 `NSPanel` + `orderFrontRegardless` | 无 |
| 中心铃铛 | `SevenMinuteReminderController` + `bellPresenter` 委托 | 内联 `NSPanel` | 无 |
| 智能提醒 | `AppViewModel` / `WindowManager` | `SmartReminderUIPanels` 工厂 + WM 生命周期 | 故意 `activate`（用户唤起） |

`WindowManager` 在休息霸屏已文档化并实现了「`orderFrontRegardless` 抬高 Dashboard → `dashboard.order(.below, relativeTo: 0)`」补救，但未抽象为通用契约。`MalDazePresentationAnchor` 与 `SmartReminderUIPanels.positionPanelTopCenter` 提供了可复用的定位基建。

约束：

- LSUIElement 菜单栏应用；Dashboard 为标准 `NSWindow`，显式打开路径必须保持。
- 睡眠/干预规格要求不得为铃铛写独立 UI，须复用中心铃铛。
- 智能提醒须可 become key 以接收输入；与被动提醒契约不同。
- 单测以源码断言 + 聚焦行为测试为主；z-order 需手动 QA。

## Goals / Non-Goals

**Goals:**

- 单一展示器 SSOT：`MalDazeTransientOverlayPresenter` 拥有临时浮层 AppKit 生命周期。
- 调度与展示分离：喝水/睡眠/干预/独立倒计时只决定「何时、什么内容」；展示器决定「如何显示且不扰动 Dashboard（被动型）」。
- 内化 z-order 不变量：被动浮层展示前后，Dashboard 相对**其他 App** 的位置不变。
- 智能提醒迁入同一展示器，按「交互型」分档保留 activate/key 行为。
- 删除三处重复的 screen observer、居中 frame、`orderFrontRegardless` 样板。
- 测试覆盖展示器契约与各迁移入口的源码/行为回归。

**Non-Goals:**

- 不迁移独立倒计时小窗（`SevenMinuteReminderController` 顶部计时条）— 非本次用户可见 bug 面，可后续 Phase 2。
- 不迁移五分钟猫伴、设置窗、休息霸屏 overlay（已有 WM 专责路径）。
- 不改 Hermes 契约、提醒文案、调度间隔、智能提醒 LLM/EventKit 编排。
- 不改 Dashboard 窗口 level/collectionBehavior 模型。
- 不在本 change 归档 `prevent-reminder-dismiss-surfacing-dashboard`（可在 apply 完成后单独 archive）。

## Decisions

### D1: 引入 `MalDazeTransientOverlayPresenter` 作为展示 SSOT

新建 `@MainActor` 类型（建议路径 `MalDaze/TransientOverlay/MalDazeTransientOverlayPresenter.swift`），对外暴露语义化 API：

```swift
enum TransientOverlayPresentationPolicy {
    case passiveCentered   // 中心铃铛、喝水：nonactivating + screenSaver
    case interactiveAnchored // 智能提醒输入/Toast：可 become key + floating
}

protocol MalDazeTransientOverlayPresenting: AnyObject {
    func presentCenterBell(message: String, onDismiss: @escaping () -> Void)
    func presentHydrationReminder(request: HydrationOverlayRequest, actions: HydrationOverlayActions)
    func presentSmartReminderInput(request: SmartReminderInputRequest)
    func presentSmartReminderToast(request: SmartReminderToastRequest)
    func dismiss(_ id: TransientOverlayID)
    func dismissAll(ofKind: TransientOverlayKind)
}
```

**理由**: 把 R22 落成明确边界，而非继续在控制器间复制 panel 代码。  
**备选**: 仅通知 + demote（拒绝——仍是分布式补丁）。  
**备选**: 全塞进 `WindowManager`（拒绝——WM 已过大；展示器可由其持有并注入 dashboard 访问）。

### D2: 展示器持有 Dashboard demote 窄接口，不反向依赖调度器

展示器构造时注入：

```swift
struct TransientOverlayDashboardPolicy {
    var demoteVisibleDashboardIfNeeded: (_ appWasActiveBeforePresent: Bool) -> Void
    var isDashboardVisible: () -> Bool
}
```

`WindowManager` 实现 demote（复用现有 `dashboard.order(.below, relativeTo: 0)`），在 `bindDeskPetMenu` 时创建展示器。

被动浮层流程：

1. `let wasActive = NSApp.isActive`
2. 创建/更新 panel，`orderFrontRegardless()`
3. `DispatchQueue.main.async { demoteIfNeeded(!wasActive) }`

**理由**: z-order 政策与 `deskMenuWindow` 引用同处 WM；展示器封装「何时 demote」，不泄漏到喝水/铃铛控制器。  
**交互型**智能提醒：**不** demote，保留 `NSApp.activate` + `makeKeyAndOrderFront`（用户显式唤起）。

### D3: 内容构建与壳分离

- **壳**（panel 创建、level、collectionBehavior、order/dismiss、screen observer）→ 展示器。
- **内容**（图标、文案、按钮、SwiftUI host）→ 现有文件迁为 builder：
  - `HydrationReminderCardView` + 按钮布局 → `HydrationOverlayContentBuilder`
  - 中心铃铛 AppKit 视图 → `CenterBellOverlayContentBuilder`
  - `SmartReminderUIPanels` SwiftUI 内容 → `SmartReminderOverlayContent`（保留布局常量）

**理由**: 对齐已验证的 `SmartReminderUIPanels` 工厂模式并推广。  
**备选**: 全部 SwiftUI 化（拒绝——本轮迁移范围过大）。

### D4: 调度器瘦身策略

| 原组件 | 之后 |
|--------|------|
| `HydrationReminderController` | Timer/安静时段 + 调 `presenter.presentHydrationReminder` |
| `SevenMinuteReminderController` | 倒计时条仍自持；`presentCenterBellReminder` 转调展示器 |
| `SleepReminderController` / `InterventionRequestController` | 继续注入 `bellPresenter`（SevenMinute 门面）或改为直接注入 presenter（二选一，见 D5） |
| `WindowManager` | 持有 presenter；`presentSmartReminderInput` / `showSmartReminderToast` 转调展示器；保留 draft、Esc monitor、outside-click 编排 |

### D5: `bellPresenter` 保留为门面，内部转调展示器

`SevenMinuteReminderController.presentCenterBellReminder` 保留公开签名，内部委托 `MalDazeTransientOverlayPresenter`，避免睡眠/干预/AppViewModel 大面积改签名。

**理由**: 最小调用方震荡。  
**备选**: 全局改注入 `MalDazeTransientOverlayPresenting`（更干净但 diff 更大；可作为 follow-up）。

### D6: 屏幕定位策略按 policy 分派

- `passiveCentered`: 菜单栏屏 `visibleFrame` 居中（复用现有 `MenuBarNSScreen` + content size 计算）。
- `interactiveAnchored`: 复用 `SmartReminderUIPanels.frameTopCenter` / `MalDazePresentationAnchor.visibleFrameContainingScreenRect` clamp。

屏幕参数变化：展示器维护 per-overlay observer，统一 `reposition`；调度器不再各自 `observeScreensIfNeeded`。

### D7: 测试策略

1. **新增** `MalDazeTests/TransientOverlayPresenterTests.swift`（或扩展现有）：
   - 被动型使用 `.nonactivatingPanel` + `.screenSaver`
   - 展示前快照 `NSApp.isActive` 并 schedule demote
   - 智能提醒交互型仍 `makeKeyAndOrderFront`
2. **更新** `ControlPanelPresentationTests`：迁移路径不再内联 `orderFrontRegardless` 于喝水/铃铛控制器。
3. **手动 QA** 清单写入 `tasks.md` 验证节。

## Risks / Trade-offs

- [Risk] 展示器成为新的上帝对象。→ Mitigation: 严格分 `PresentationPolicy` + content builder；WM 只持有实例，逻辑在独立文件。
- [Risk] 被动 demote 在「Dashboard 在前、用户点测试触发」时误压面板。→ Mitigation: 仅 `!appWasActiveBeforePresent` 时 demote；文档化不变量。
- [Risk] 迁移期间双轨窗口代码短暂共存。→ Mitigation: 按 tasks 分阶段迁移（先 presenter + 喝水，再铃铛，再智能提醒），每步跑测试。
- [Risk] 源码测试无法验证真实 z-order。→ Mitigation: 手动 QA + 保留 demote 调用断言。
- [Risk] `prevent-reminder-dismiss-surfacing-dashboard` 与 canonical `hydration-reminder` spec 冲突。→ Mitigation: 本 change delta spec 覆盖浮层展示要求；archive 时合并。

## Migration Plan

1. 落地 `MalDazeTransientOverlayPresenter` + dashboard policy 注入 + 聚焦测试（RED）。
2. 迁移喝水提醒 → GREEN；手动 QA 被动 demote。
3. 迁移中心铃铛（SevenMinute 门面）→ 睡眠/干预回归。
4. 迁移智能提醒输入/Toast；WM 删重复 panel 代码。
5. 删除调度器内 dead code（screen observer、内联 panel）。
6. `openspec validate extract-transient-overlay-presenter`；全量相关测试；更新 R22 状态。

**Rollback**: 按控制器 revert 到 presenter 调用前；无数据迁移。

## Open Questions

- 独立倒计时小窗是否在本 change 末尾一并迁入展示器，还是明确留 Phase 2？（建议 **Phase 2**，保持 diff 可控。）
- `MalDazeTransientOverlayPresenter` 放独立 target 文件夹还是 `WindowManager/` 子目录？（建议 **`MalDaze/TransientOverlay/`** 独立目录，避免 WM 继续膨胀。）
