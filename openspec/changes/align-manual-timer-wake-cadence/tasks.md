## 1. Tests (RED)

- [x] 1.1 更新/新增 replay test：whole-second emit 行为不变
- [x] 1.2 `EnergyWakeupSourceTests`：ManualTimerEngine 无 `0.25, repeats: true`

## 2. Implementation

- [x] 2.1 实现 1 Hz one-shot chain 替换 4 Hz repeating
- [x] 2.2 phase 边界立即 schedule tick
- [x] 2.3 删除多余 `lastEmittedRemainingWholeSeconds` 去重逻辑若 one-shot 已保证（或保留作 defense）

## 3. Validation

- [x] 3.1 `ManualTimerEnginePhaseReplayTests` 全绿
- [ ] 3.2 Manual QA：手动专注、休息、skip rest、放弃专注
- [x] 3.3 `openspec validate align-manual-timer-wake-cadence`
