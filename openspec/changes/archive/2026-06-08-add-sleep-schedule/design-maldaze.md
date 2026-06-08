## Context

MalDaze 是 macOS 桌宠应用，已有：

- `SevenMinuteReminderController.presentCenterBellReminder` — 中央铃铛浮层，点击消失。
- `WindowManager.presentRest` / `dismissRestImmediately` — 全屏霸屏休息（`break-interruption` spec）。
- `HydrationReminderController` — 独立 Controller + 单次 Timer + `AppViewModel` 持有，可作为睡眠提醒架构参考。

睡眠功能**不**接入 `ManualTimerEngine` / `AutoTimerEngine`；语义与护眼番茄钟分离。

**运行时耦合总览**：[docs/integrations/hermes.md](../../../docs/integrations/hermes.md)

## Goals / Non-Goals

**Goals:**

- 只读消费 `~/.hermes/data/sleep/sleep_schedule.json`。
- 调度 T-90 / T-60 / T-30 / deadline 铃铛 / lockBedtime 霸屏。
- 合盖取消霸屏与睡眠铃铛。
- 设置开关与契约校验 fail-loud。
- 复用现有 UI，不新写浮层。

**Non-Goals:**

- pmset 解析、目标算法、晨报。
- 写入 `sleep_schedule.json`。
- 读取 `~/.hermes/data/nutrition/daily_log.json`（`dayType` 由契约提供）。
- breakRun 风格睡眠霸屏。

## Decisions

### Decision 1: `SleepReminderController` 独立模块

新建 `MalDaze/SleepReminder/SleepReminderController.swift`，由 `AppViewModel` 持有，模式仿 `HydrationReminderController`：

- `start()` / `cancel()` 由总开关驱动。
- 内部维护单次 `Timer` 链（非 repeating poll）。
- 注入 `SevenMinuteReminderController` 与 `WindowManaging`（或 `AppViewModel` 回调）以触发铃铛/霸屏。

### Decision 2: 提醒链时刻表

以 JSON 的 `targetBedtime`、`lockBedtime`（当日日历日 + HH:mm）为锚点：

| 偏移 | 条件 | 动作 |
|------|------|------|
| target − 90min | `dayType == "training"` 且洗澡开关开 | `presentCenterBellReminder("该洗澡了，睡前 1.5h 洗才不会热得睡不着")` |
| target − 60min | 提醒链开 | `presentCenterBellReminder("今天差不多了，别开新活了，准备收尾")` |
| target − 30min | 提醒链开 | `presentCenterBellReminder("该去洗漱了，真的要睡了")` |
| target（deadline） | 提醒链开 | `presentCenterBellReminder("要睡觉了")`（文案可微调，须可点击消失） |
| lockBedtime | 霸屏开关开 | `windowManager.presentRest(duration: …)` **fullscreen only** |

霸屏 `duration`：建议固定较长值（如 30min）或直到合盖/手动结束；不与番茄休息时长绑定。`onDismissed` 回调不驱动计时器引擎。

### Decision 3: 契约加载与重调度

触发重读 JSON 并重算 Timer 链：

1. `SleepReminderController.start()`。
2. `NSWorkspace.didWakeNotification`。
3. 可选 `FSEvents` 监听 `sleep_schedule.json`（`updatedAt` 变化时重调度）。
4. 设置项变更导致 `start()` 重入。

解析失败或必填字段缺失 → 记录错误、`cancel()` 停止链、向 UI 暴露 `sleepScheduleError` 状态（控制面板一行红字或 status 即可）。

**不**对 `dayType` 做默认兜底。

### Decision 4: 合盖取消

监听 `NSWorkspace.willSleepNotification`：

- `windowManager.dismissRestImmediately(bringIdlePetWindowToFront: false)`（若睡眠霸屏进行中）。
- 若 `SevenMinuteReminderController` 的睡眠铃铛浮层可见，调用其 `cancel()` 或专用 `dismissReminderIfShowing()`（若需与 7 分钟倒计时区分，优先只关 reminder window 而不停独立倒计时）。

仅处理**睡眠链触发的**霸屏：在 `presentRest` 时打标 `sleepLockActive`，合盖只在该标为 true 时 dismiss，避免误杀番茄测试休息。

### Decision 5: 与番茄钟 / breakRun 优先级

当睡眠霸屏需触发且计时器正在休息展示：

- 睡眠霸屏优先展示（或先 `dismissRestImmediately` 再 `presentRest` 睡眠专用回调）。
- 睡眠 `onDismissed` 不调用 `ManualTimerEngine` / `AutoTimerEngine` 的 skip-rest。

在 `break-interruption` delta spec 中写明。

### Decision 6: `SevenMinuteReminderController` 共用

睡眠链**只**调用 `presentCenterBellReminder`，**不**调用 `start()` 倒计时。

若智能提醒铃铛与睡眠铃铛同时存在，后触发者覆盖前浮层（现有行为）；无需新 UI。

### Decision 7: 设置开关（UserDefaults）

| Key | 默认 | 说明 |
|-----|------|------|
| `MalDaze.sleepSchedule.enabled` | `false` | 总开关 |
| `MalDaze.sleepSchedule.remindersEnabled` | `true` | T-90/60/30/deadline 铃铛 |
| `MalDaze.sleepSchedule.lockScreenEnabled` | `true` | lockBedtime 霸屏 |
| `MalDaze.sleepSchedule.dismissOnClamshell` | `true` | 合盖取消挡屏 |
| `MalDaze.sleepSchedule.showerReminderEnabled` | `true` | T-90 洗澡（仍须 `dayType==training`） |

子开关仅在总开关 on 时生效。

## Risks / Trade-offs

- **[Risk] JSON 在 Hermes cron 前未更新** → 沿用上次 `updatedAt` 的 target；日志提示。
- **[Risk] 跨日 anchor 计算错误** → 单元测试 `SleepScheduleAnchorBuilder`（从 HH:mm 构造当日 `Date`）。
- **[Risk] 误 dismiss 番茄霸屏** → `sleepLockActive` 标记。

## Migration Plan

1. 实现 Controller + 契约读取 + 测试。
2. 默认总开关 off；Hermes JSON 就绪后用户手动开启。
3. 控制面板增加开关区，Settings 可镜像（与 hydration 一致）。
