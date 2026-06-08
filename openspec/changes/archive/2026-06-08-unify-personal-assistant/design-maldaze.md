## Context

MalDaze 是 macOS 桌宠：计时休息、铃铛、Dashboard、EventKit 侧栏（已有）、SmartReminder（legacy）。本 change **仅**新增域 B 消费者，并调整 SmartReminder 产品定位。

已有可参考模块：`SleepReminder/`（FSEvents、fail-loud、Timer 链）。

## Goals / Non-Goals

**Goals:**

- 读 `~/.hermes/data/maldaze/intervention_request.json` 并执行强提醒。
- 复用 `SevenMinuteReminderController`（动态分钟 + 中央铃铛）。
- 消费后 ack，幂等。

**Non-Goals:**

- 接收 Hermes 的日待办写入请求。
- 飞书日历展示或完成回写。
- 删除或隐藏 `SmartReminder/`（scope-decision D3：保持现状）。
- 删除 Dashboard EventKit 侧栏。
- 检测本机「Hermes 是否运行」（门禁在 Hermes 写端 D7）。

## Decisions

### M1: 模块布局

```
MalDaze/InterventionRequest/
├── InterventionRequestContract.swift   # 解析 + 校验
├── InterventionRequestConsumer.swift   # 执行 + ack
├── InterventionRequestFileWatcher.swift
└── (tests in MalDazeTests/)
```

由 `AppViewModel` 持有 `InterventionRequestConsumer`，与 `SleepReminderController` 并列启动。

### M2: 契约消费流程

```
FSEvents / 启动 / 唤醒 / 前台
    → 读 intervention_request.json
    → 校验 schemaVersion, kind, id, requestedAt
    → 若 consumed 或 过期 expiresAt → 忽略
    → 若 `requestedAt + minutes` 已过（迟到启动）→ 仅 `presentCenterBellReminder(title)`，不 retroactive 倒计时
    → switch kind:
         countdown → SevenMinuteReminderController.start(minutes:title:)
         bell      → presentCenterBellReminder(message:)
         cancel    → SevenMinuteReminderController.cancel()
    → ack：rename 或 写 consumed 侧车文件
```

### M3: SevenMinuteReminderController 扩展

新增 API（示意）：

```swift
func start(minutes: Int, completionMessage: String)
func startCountdownOnly(minutes: Int) // 若需与默认 7min 设置分离
```

- Hermes 发起的倒计时**必须**使用契约中的 `minutes`，忽略 UserDefaults 默认 7。
- 用户手动 ⌘⇧M 倒计时行为不变。

### M4: fail-loud

- JSON 缺字段 / 非法 `kind`：打日志 + `AppViewModel` 状态消息（可选控制面板一行），**不**执行部分动作。
- MalDaze 未授权提醒事项**不影响**域 B（域 B 不碰 EventKit）。

### M5: 新 Hermes countdown 覆盖进行中倒计时（D2）

消费新 `kind: countdown` 时，若**任意**倒计时（含用户 ⌘⇧M）正在进行，先 `cancel()` 再按契约 `start(minutes:completionMessage:)`。飞书侧无需额外确认。

### M6: Dashboard 计划侧栏

**不修改** EventKit 读逻辑；在 `docs/integrations/features/day-reminders.md` 标明：侧栏为 Mac 前快操，创建请用 Hermes。

## Risks / Trade-offs

- **[Risk] 倒计时与睡眠铃铛同时** → 域 B 倒计时进行中，睡眠铃铛仍可叠（接受）；或 Consumer 在睡眠霸屏时仍允许倒计时条（独立窗口层级）。
- **[Risk] ack 前崩溃重复弹** → 启动时读未 ack 文件；同 `id` 已记录在 UserDefaults 则跳过。

## Open Questions

- ack 文件策略：`intervention_request.consumed.json` vs 原子 rename（倾向 rename 至 `consumed/{id}.json`）。
