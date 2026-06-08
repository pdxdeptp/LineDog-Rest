## Why

用户当前入睡时间约 00:30–01:00，希望逐步前推到 22:30。Mac 合盖时间可通过 `pmset -g log` 的 Clamshell Sleep 精确获取，适合作为追踪信号；睡前需要分级提醒，并在截止时间后 5 分钟强制霸屏。

MalDaze 负责 UI 干预（铃铛 + 霸屏），Hermes 负责数据与算法（pmset 解析、目标推进、晨报）。两者通过 `~/.hermes/data/sleep/sleep_schedule.json` 强耦合集成，避免桌宠重复实现系统日志与营养数据读取。

## What Changes

### MalDaze（桌宠）

- 新增 `SleepReminderController`：只读 `sleep_schedule.json`，按当晚 `targetBedtime` / `lockBedtime` 调度睡前提醒链。
- 复用 `SevenMinuteReminderController.presentCenterBellReminder` 弹出 T-90/T-60/T-30 与 deadline 铃铛（点击消失，带文案如「要睡觉了」）。
- 在 `lockBedtime`（target + 5 分钟）触发全屏霸屏，复用 `WindowManager.presentRest`（强制 fullscreen，不走 breakRun）。
- 合盖（`NSWorkspace.willSleepNotification`）自动取消霸屏并关闭未-dismiss 的睡眠铃铛浮层。
- 契约字段缺失或非法时**报错并停止调度**（不静默默认）。
- 控制面板 / 设置增加睡眠提醒开关（总开关、提醒链、霸屏、合盖取消、洗澡提醒）。
- 睡眠霸屏与护眼番茄钟冲突时，睡眠霸屏优先。

### Hermes

- 新增 `sleep_tracker.py`：`pmset -g log` 解析昨夜 Clamshell Sleep、达标判定（目标后 ≤10 分钟合盖算达标）、目标推进（达标 -10min/天，未达标不变，下限 22:30，初值 00:00）。
- 扩展 `morning-briefing.py`（现有 08:00 cron）：调用 sleep tracker、写入 `sleep_schedule.json`（含 `dayType`，来自 `recommend.py auto` 之后）、晨报追加 🌙 睡眠段落。
- 新建 `~/.hermes/data/sleep/` 数据目录与可选 `sleep_history.json`（Hermes 自用，桌宠不读）。

### 共享契约

- `sleep_schedule.json` 由 Hermes 独占写入，MalDaze 只读；`schemaVersion`、`targetBedtime`、`lockBedtime`、`dayType`、`updatedAt` 均为必填。

## Capabilities

### New Capabilities

- `sleep-reminder`: MalDaze 睡前提醒链、铃铛/霸屏/合盖取消、设置开关与契约消费。
- `sleep-schedule-contract`: Hermes ↔ MalDaze 共享 JSON 文件路径、字段、所有权与强耦合假设。
- `hermes-sleep-tracker`: Hermes 侧 pmset 追踪、目标算法、晨报段落与 JSON 写入（实现于 `~/.hermes`，在本 change 中文档化）。

### Modified Capabilities

- `break-interruption`: 睡眠霸屏入口、与计时器休息的优先级、合盖取消联动。
- `desk-pet-controls`: 睡眠提醒相关控制面板开关与状态展示。

## Impact

- **MalDaze Swift**：`AppViewModel`、`MalDazeDefaults`、`DashboardRootView`、`Settings`、新建 `MalDaze/SleepReminder/`。
- **Hermes Python**（仓库外，`~/.hermes`）：`scripts/morning-briefing.py`、新建 `scripts/sleep_tracker.py`（或 `data/sleep/` 模块）、`data/sleep/sleep_schedule.json`。
- **复用**：`SevenMinuteReminderController`、`WindowManager.presentRest` / `dismissRestImmediately`。
- **文档**：`design-maldaze.md`、`design-hermes.md`、`tasks-maldaze.md`、`tasks-hermes.md` 分仓说明；`design.md` / `tasks.md` 为索引。

## Affected Specs

- `sleep-reminder`（新建）
- `sleep-schedule-contract`（新建）
- `hermes-sleep-tracker`（新建）
- `break-interruption`（修改）
- `desk-pet-controls`（修改）
