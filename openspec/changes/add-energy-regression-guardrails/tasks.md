## 1. Documentation

- [x] 1.1 添加 `docs/performance/energy-invariants.md`（invariant 列表 + 如何跑测试）

## 2. EnergyWakeupSourceTests

- [x] 2.1 Focus timeline：禁止 visible 无条件 startLiveTick
- [x] 2.2 Dashboard：`hideDashboardWindow` 含 quiescence / enterHidden
- [x] 2.3 Manual engine：禁止 0.25 repeating（依赖 Change 3）
- [x] 2.4 Intervention：禁止 3.0 repeating poll（依赖 Change 4）

## 3. Validation

- [x] 3.1 `swift MalDazeTests/EnergyWakeupSourceTests.swift` 通过
- [x] 3.2 `openspec validate add-energy-regression-guardrails`
- [ ] 3.3 `docs/agent-workflow.md` 可选链接 energy invariants（若团队同意）
