## Context

MalDaze 已有两类独立提醒控制器先例：`SevenMinuteReminderController`（倒计时 + 铃铛浮层，点击关闭）和 `FiveMinuteCatCompanionController`（小猫浮窗，渐隐消失）。两者均为 `@MainActor final class`，通过 `AppViewModel` 持有，不经过 `WindowManager`，通过回调向 ViewModel 汇报状态。

参考来源为 PawPal（https://github.com/zebangeth/PawPal），其喝水提醒运行于 Electron/Node.js 主进程中：用 `setTimeout` 调度，弹 React 气泡含「Done / Snooze」按钮，响应用户操作后重新调度。逻辑与 MalDaze 的 AppKit 架构直接同构：Node `setTimeout` → Swift `Timer`，electron-store → `UserDefaults`，IPC → 直接方法调用，React speech bubble → `NSWindow` 浮层。

## Goals / Non-Goals

**Goals:**
- 将 PawPal 喝水提醒的核心逻辑（周期调度 → 浮层 → Done/Snooze → 重新调度）搬进 MalDaze Swift 代码
- 遵循 `SevenMinuteReminderController` 的结构：独立 `NSWindow`，`@MainActor`，回调汇报，不经 `WindowManager`
- 浮层 UI 包含水滴图标 + 文案 + 两个按钮（`NSButton`），与 SevenMinuteReminder 的铃铛浮层同风格
- 所有设置持久化到 `UserDefaults`（键集中在 `MalDazeDefaults`）
- 菜单栏面板中插入新区块（Toggle 开关 + Stepper 间隔）

**Non-Goals:**
- 每日喝水次数统计展示（PawPal 有 `watersLogged` 统计，本次不实现 UI 展示，仅可选地在 UserDefaults 计数以备将来）
- PawPal 的 `blockingMode` 互斥（MalDaze 无并发提醒场景，SevenMinuteReminder 与喝水提醒可同时显示）
- 全局快捷键（喝水提醒由菜单面板开关控制，不需要热键）
- Snooze 间隔可配置（照抄 PawPal 硬编码 15 分钟）

## Decisions

### D1：HydrationReminderController 完全仿照 SevenMinuteReminderController

SevenMinuteReminderController 已被 AppViewModel 证明为可靠的独立控制器模式（独立 NSWindow、`@MainActor`、`onRunningChanged` 回调）。喝水提醒采用相同骨架：
- `start()` 启动周期 Timer，`cancel()` 停止并关闭浮层
- `onStateChanged: ((Bool) -> Void)?` 向 ViewModel 汇报「是否已调度」
- 浮层窗口 `NSWindow.level = .screenSaver`、`.canJoinAllSpaces`，与 SevenMinuteReminder 铃铛窗同级

**备选**：在 SevenMinuteReminderController 内部扩展一个「周期模式」。拒绝——两者职责不同（倒计时 vs 周期提醒），合并会导致单一类承担两种定时语义，难以独立开关。

### D2：浮层用 NSWindow + 纯 AppKit（仿铃铛浮层），不用 SwiftUI

SevenMinuteReminderController 的铃铛浮层是纯 AppKit NSWindow，代码量约 80 行，可直接 copy-adapt。喝水浮层在此基础上把「点击任意处关闭」替换为两个 `NSButton`（「已喝水 💧」主按钮 + 「稍后提醒」次按钮），保持相同的圆角卡片视觉。

**备选**：SwiftUI `NSHostingController` 嵌入 NSWindow。拒绝——引入 SwiftUI 状态层对于两个按钮属于过度工程，与 SevenMinuteReminder 风格不一致。

### D3：Timer 生命周期

PawPal 每次 `triggerHydrationReminder` 完成（Done / Snooze）之后都显式重新调度，不使用 repeating timer——这样 Snooze 才能用不同的延迟。MalDaze 照搬此策略：`Timer.scheduledTimer(withTimeInterval:repeats: false)`，Done 后按完整间隔重调度，Snooze 后按 15×60 秒重调度。

**备选**：`repeating: true` Timer。拒绝——Snooze 需要不同延迟，repeating Timer 无法在不重建的情况下改变间隔。

### D4：AppViewModel 中 `isHydrationReminderEnabled` 为 `@Published`

与 `isSevenMinuteReminderRunning` / `isFiveMinuteCatCompanionActive` 对称——MenuBarContentView 用 `viewModel.isHydrationReminderEnabled` 驱动 Toggle 状态与按钮 disabled 逻辑，无需额外 @AppStorage 绑定在 ViewModel 内部。

### D5：设置键放在 MalDazeDefaults，默认值为关闭 + 90 分钟

PawPal 默认喝水提醒开启（`hydrationReminderEnabled: true`）、间隔 90 分钟。MalDaze 新功能默认**关闭**——避免第一次启动就弹窗令用户困惑，与现有功能（SevenMinuteReminder 也是手动开启）一致。间隔默认 90 分钟同 PawPal。

## Risks / Trade-offs

- **多浮层同时显示**：SevenMinuteReminder 铃铛与喝水浮层可能同时出现（时间巧合）。两个独立 NSWindow 不会崩溃，视觉上稍显拥挤。→ 暂时接受，未来可考虑排队逻辑。
- **应用退出时 Timer 残留**：`AppViewModel.deinit` 中需调用 `hydrationReminder.cancel()` 保证 Timer 被 invalidate。→ 与 `sevenMinuteReminder` 处理一致，在 `deinit` 中加清理。
- **UserDefaults 跨版本兼容**：若将来键名变更，旧用户设置静默丢失（重置为默认值）。→ 可接受，与现有所有 MalDazeDefaults 键处理方式一致。

## Migration Plan

纯增量变更，无数据迁移：
1. 新增 Swift 文件 + Xcode 工程引用
2. 修改 3 个现有文件（Defaults、ViewModel、MenuBarContentView）
3. 无需数据库迁移、无网络请求、无沙箱权限变更

回滚：删除新文件，还原 3 个修改文件，删除 UserDefaults 两个键（无副作用）。

## Open Questions

- 是否展示「今日已喝 N 杯」统计？→ 本次暂不实现 UI，仅在 UserDefaults 中维护计数（`hydrationReminderTodayCount` + `hydrationReminderLastResetDate`）以备将来。
- 浮层文案是否支持多语言？→ 本次仅中文，与 MalDaze 现有界面一致（无 Localizable.strings）。
