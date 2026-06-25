## Why

M1–M2 修复依赖正确实现与 lifecycle 纪律；若无 **自动化门禁**，后续功能很容易 reintroduce unconditional live tick、hide 不 quiesce、sub-second engine poll——重蹈 diag 覆辙。项目已有 `EnergyWakeupSourceTests` 模式（`reduce-idle-energy`）；本 change 把 energy invariants **固化为 spec + 源码测试**，不要求 Instruments CI。

## What Changes

- 新增 capability `energy-regression-guardrails`：documented invariants + source tests。
- 扩展 `EnergyWakeupSourceTests`：
  - Focus timeline：无 unconditional live tick on visible
  - Dashboard hide：quiescence / pause 路径
  - Manual engine：无 sub-second repeating（若 Change 3 已做）
- 可选：`docs/performance/energy-invariants.md` 简短列表。
- **不** 引入 runtime Energy Log API / signpost（可 follow-up）。

## Capabilities

### New Capabilities

- `energy-regression-guardrails`: Source-level and documented invariants preventing high-frequency idle wakeups in desk pet, dashboard, and timer engines.

### Modified Capabilities

- None at product behavior level—tests encode existing M1/M2 requirements.

## Depends On

- Changes 1–2 required for core assertions.
- Change 3 for manual engine assertion.
- Can land incrementally as M2 tail.

## Impact

- `MalDazeTests/EnergyWakeupSourceTests.swift`
- `docs/performance/energy-invariants.md`（optional）
