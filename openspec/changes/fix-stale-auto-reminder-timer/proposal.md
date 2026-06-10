## Why

自动整点 / 半点休息依赖一次性 `Timer` 等待下一个锚点。电脑睡眠或早上唤醒后，macOS 可能补触发已经过期的 timer，导致桌宠在 10:19 这类非整点 / 半点时间进入休息。

## What Changes

- 让自动休息 timer 触发时校验本次等待的锚点仍然有效，过期很久的触发不得进入休息。
- 在系统唤醒或应用重新活跃后主动重新对齐自动休息锚点，刷新“下次休息”状态。
- 保留低唤醒策略：等待阶段继续使用一次性 timer，不恢复亚秒级轮询。
- 增加回归测试覆盖睡眠 / 唤醒后迟到 timer 的行为。

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `break-interruption`: 自动整点 / 半点休息调度需要区分准时锚点触发与睡眠后过期 timer 补触发，并在唤醒后重新对齐。

## Impact

- Affected code: `MalDaze/TimerEngine/AutoTimerEngine.swift`, `MalDaze/AppViewModel.swift`
- Affected tests: `MalDazeTests/MalDazeInteractionTests.swift` or a focused timer-engine test file
- No persistence key, Hermes contract, reminder JSON, or UI layout changes are intended.
